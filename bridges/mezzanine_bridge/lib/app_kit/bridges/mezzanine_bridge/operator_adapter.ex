defmodule AppKit.Bridges.MezzanineBridge.OperatorAdapter do
  @moduledoc false

  @behaviour AppKit.Core.Backends.OperatorBackend

  import AppKit.Bridges.MezzanineBridge.Common,
    only: [
      coerce_datetime: 1,
      compact_map: 1,
      fetch_value: 2,
      map_each: 2,
      maybe_put: 3,
      normalize_string: 1
    ]

  alias AppKit.Bridges.MezzanineBridge.{
    ActionMapping,
    Errors,
    Services,
    WorkMapping
  }

  alias AppKit.Core.{
    ActorRef,
    ExecutionRef,
    InstallationRef,
    MemoryFragmentListRequest,
    MemoryFragmentProjection,
    MemoryFragmentProvenance,
    MemoryInvalidationRequest,
    MemoryPromotionRequest,
    MemoryProofTokenLookup,
    MemoryShareUpRequest,
    OperatorAction,
    OperatorActionRef,
    OperatorActionRequest,
    ReadLease,
    RequestContext,
    RunRef,
    StreamAttachLease,
    SubjectRef,
    Telemetry,
    TimelineEvent,
    UnifiedTrace,
    UnifiedTraceStep
  }

  alias Mezzanine.Archival.Query, as: ArchivalQuery

  @impl true
  def subject_status(%RequestContext{} = context, %SubjectRef{} = subject_ref, opts)
      when is_list(opts) do
    with :ok <- ensure_subject_not_archived(context, subject_ref),
         {:ok, tenant_id} <- tenant_id(context),
         {:ok, row} <- Services.operator_query(opts).subject_status(tenant_id, subject_ref.id),
         {:ok, projection} <- WorkMapping.operator_projection_from_row(row, context) do
      {:ok, projection}
    else
      {:error, :archived, manifest_ref} -> Errors.normalize({:archived, manifest_ref})
      {:error, reason} -> Errors.normalize(reason)
    end
  end

  @impl true
  def timeline(%RequestContext{} = context, %SubjectRef{} = subject_ref, opts)
      when is_list(opts) do
    with :ok <- ensure_subject_not_archived(context, subject_ref),
         {:ok, tenant_id} <- tenant_id(context),
         {:ok, timeline_result} <-
           Services.operator_query(opts).timeline(tenant_id, subject_ref.id),
         entries <- fetch_value(timeline_result, :entries) || [],
         {:ok, timeline_entries} <- map_each(entries, &timeline_event_from_map/1) do
      {:ok, timeline_entries}
    else
      {:error, :archived, manifest_ref} -> Errors.normalize({:archived, manifest_ref})
      {:error, reason} -> Errors.normalize(reason)
    end
  end

  @impl true
  def get_unified_trace(%RequestContext{} = context, %ExecutionRef{} = execution_ref, opts)
      when is_list(opts) do
    with {:ok, tenant_id} <- tenant_id(context),
         {:ok, lineage} <- execution_trace_lineage(context, execution_ref, opts),
         {:ok, epoch_fields} <- revision_epoch_fields(context, opts),
         trace_attrs <-
           %{
             tenant_id: tenant_id,
             actor_id: context.actor_ref.id,
             installation_id: lineage.installation_id,
             execution_id: execution_ref.id,
             trace_id: lineage.trace_id
           }
           |> Map.merge(epoch_fields),
         {:ok, trace} <- Services.operator_query(opts).get_unified_trace(trace_attrs, opts),
         {:ok, unified_trace} <- unified_trace_from_map(trace, context) do
      Telemetry.unified_trace_assembled(
        %{
          trace_id: unified_trace.trace_id,
          tenant_id: tenant_id,
          installation_id: lineage.installation_id,
          execution_id: execution_ref.id,
          source: :northbound_surface,
          surface: :mezzanine_bridge
        },
        %{
          count: 1,
          step_count: length(unified_trace.steps),
          join_key_count: map_size(unified_trace.join_keys)
        }
      )

      {:ok, unified_trace}
    else
      {:error, reason} -> Errors.normalize(reason)
    end
  end

  @impl true
  def issue_read_lease(%RequestContext{} = context, %ExecutionRef{} = execution_ref, opts)
      when is_list(opts) do
    with {:ok, tenant_id} <- tenant_id(context),
         {:ok, lineage} <- execution_trace_lineage(context, execution_ref, opts),
         {:ok, epoch_fields} <- revision_epoch_fields(context, opts),
         attrs <-
           %{
             tenant_id: tenant_id,
             installation_id: lineage.installation_id,
             execution_id: execution_ref.id,
             trace_id: lineage.trace_id,
             allowed_family: Keyword.get(opts, :allowed_family, "unified_trace"),
             allowed_operations:
               Keyword.get(opts, :allowed_operations, [
                 :fetch_run,
                 :events,
                 :attempts,
                 :run_artifacts
               ]),
             scope: Keyword.get(opts, :scope, %{})
           }
           |> Map.merge(epoch_fields),
         {:ok, lease} <- Services.lease(opts).issue_read_lease(attrs, opts),
         {:ok, read_lease} <- read_lease_from_map(lease) do
      {:ok, read_lease}
    else
      {:error, reason} -> Errors.normalize(reason)
    end
  end

  @impl true
  def issue_stream_attach_lease(
        %RequestContext{} = context,
        %ExecutionRef{} = execution_ref,
        opts
      )
      when is_list(opts) do
    with {:ok, tenant_id} <- tenant_id(context),
         {:ok, lineage} <- execution_trace_lineage(context, execution_ref, opts),
         {:ok, epoch_fields} <- revision_epoch_fields(context, opts),
         attrs <-
           %{
             tenant_id: tenant_id,
             installation_id: lineage.installation_id,
             execution_id: execution_ref.id,
             trace_id: lineage.trace_id,
             allowed_family: Keyword.get(opts, :allowed_family, "runtime_stream"),
             scope: Keyword.get(opts, :scope, %{})
           }
           |> Map.merge(epoch_fields),
         {:ok, lease} <- Services.lease(opts).issue_stream_attach_lease(attrs, opts),
         {:ok, stream_attach_lease} <- stream_attach_lease_from_map(lease) do
      {:ok, stream_attach_lease}
    else
      {:error, reason} -> Errors.normalize(reason)
    end
  end

  @impl true
  def available_actions(%RequestContext{} = context, %SubjectRef{} = subject_ref, opts)
      when is_list(opts) do
    with :ok <- ensure_subject_not_archived(context, subject_ref),
         {:ok, tenant_id} <- tenant_id(context),
         {:ok, rows} <- Services.operator_query(opts).available_actions(tenant_id, subject_ref.id),
         {:ok, actions} <- map_each(rows, &operator_action_from_map/1) do
      {:ok, actions}
    else
      {:error, :archived, manifest_ref} -> Errors.normalize({:archived, manifest_ref})
      {:error, reason} -> Errors.normalize(reason)
    end
  end

  @impl true
  def apply_action(
        %RequestContext{} = context,
        %SubjectRef{} = subject_ref,
        %OperatorActionRequest{} = action_request,
        opts
      )
      when is_list(opts) do
    with {:ok, tenant_id} <- tenant_id(context),
         action_kind <- action_kind(action_request),
         action_params <- operator_action_params(context, subject_ref, action_request),
         actor <- actor_payload(context),
         {:ok, bridge_result} <-
           Services.operator_action(opts).apply_action(
             tenant_id,
             subject_ref.id,
             action_kind,
             action_params,
             actor
           ),
         {:ok, action_result} <- ActionMapping.action_result_from_bridge(bridge_result) do
      {:ok, action_result}
    else
      {:error, reason} -> Errors.normalize(reason)
    end
  end

  @impl true
  def list_memory_fragments(
        %RequestContext{} = context,
        %MemoryFragmentListRequest{} = request,
        opts
      )
      when is_list(opts) do
    with attrs <- memory_request_attrs(context, request),
         {:ok, rows} <- Services.memory_control(opts).list_fragments_by_proof_token(attrs, opts),
         {:ok, fragments} <- map_each(rows, &memory_fragment_projection_from_map/1) do
      {:ok, fragments}
    else
      {:error, reason} -> Errors.normalize(reason)
    end
  end

  @impl true
  def memory_fragment_by_proof_token(
        %RequestContext{} = context,
        %MemoryProofTokenLookup{} = lookup,
        opts
      )
      when is_list(opts) do
    with attrs <- memory_request_attrs(context, lookup),
         {:ok, row} <- Services.memory_control(opts).lookup_fragment_by_proof_token(attrs, opts),
         {:ok, fragment} <- memory_fragment_projection_from_map(row) do
      {:ok, fragment}
    else
      {:error, reason} -> Errors.normalize(reason)
    end
  end

  @impl true
  def memory_fragment_provenance(%RequestContext{} = context, fragment_ref, opts)
      when is_binary(fragment_ref) and is_list(opts) do
    with attrs <- Map.put(memory_context_attrs(context), :fragment_ref, fragment_ref),
         {:ok, row} <- Services.memory_control(opts).fragment_provenance(attrs, opts),
         {:ok, provenance} <- memory_fragment_provenance_from_map(row) do
      {:ok, provenance}
    else
      {:error, reason} -> Errors.normalize(reason)
    end
  end

  @impl true
  def request_memory_share_up(
        %RequestContext{} = context,
        %MemoryShareUpRequest{} = request,
        opts
      )
      when is_list(opts) do
    request_memory_action(context, request, opts, :request_share_up)
  end

  @impl true
  def request_memory_promotion(
        %RequestContext{} = context,
        %MemoryPromotionRequest{} = request,
        opts
      )
      when is_list(opts) do
    request_memory_action(context, request, opts, :request_promotion)
  end

  @impl true
  def request_memory_invalidation(
        %RequestContext{} = context,
        %MemoryInvalidationRequest{} = request,
        opts
      )
      when is_list(opts) do
    request_memory_action(context, request, opts, :request_invalidation)
  end

  @impl true
  def run_status(%RunRef{} = run_ref, attrs, opts) when is_map(attrs) and is_list(opts) do
    case Services.operator_query(opts).run_status(run_ref, attrs, opts) do
      {:ok, result} -> {:ok, result}
      {:error, :archived, manifest_ref} -> Errors.normalize({:archived, manifest_ref})
      {:error, reason} -> Errors.normalize(reason)
    end
  end

  @impl true
  def review_run(%RunRef{} = run_ref, evidence_attrs, opts)
      when is_map(evidence_attrs) and is_list(opts) do
    Services.operator_action(opts).review_run(run_ref, evidence_attrs, opts)
  end

  defp request_memory_action(%RequestContext{} = context, request, opts, function_name) do
    with attrs <- memory_request_attrs(context, request),
         {:ok, bridge_result} <-
           apply(Services.memory_control(opts), function_name, [attrs, opts]),
         {:ok, action_result} <- ActionMapping.action_result_from_bridge(bridge_result) do
      {:ok, action_result}
    else
      {:error, reason} -> Errors.normalize(reason)
    end
  end

  defp execution_trace_lineage(%RequestContext{} = context, %ExecutionRef{} = execution_ref, opts) do
    with {:ok, installation_id} <- installation_or_tenant_id(context),
         {:ok, lineage} <- Services.operator_query(opts).execution_trace_lineage(execution_ref.id),
         true <- lineage.installation_id == installation_id do
      {:ok, lineage}
    else
      false -> {:error, :unauthorized_lower_read}
      {:error, reason} -> {:error, reason}
    end
  end

  defp timeline_event_from_map(row) when is_map(row) do
    TimelineEvent.new(%{
      ref: fetch_value(row, :ref) || fetch_value(row, :id) || fetch_value(row, :event_id),
      event_kind: normalize_string(fetch_value(row, :event_kind) || fetch_value(row, :kind)),
      occurred_at: coerce_datetime(fetch_value(row, :occurred_at)),
      summary: fetch_value(row, :summary),
      actor_ref: actor_ref_from_any(fetch_value(row, :actor_ref)),
      payload:
        fetch_value(row, :payload) ||
          compact_map(
            Map.drop(Map.new(row), [
              :ref,
              :id,
              :event_kind,
              :kind,
              :occurred_at,
              :summary,
              :actor_ref
            ])
          ),
      metadata: fetch_value(row, :metadata) || %{}
    })
  end

  defp timeline_event_from_map(_row), do: {:error, :invalid_timeline_event}

  defp unified_trace_from_map(trace, %RequestContext{} = context) when is_map(trace) do
    steps = fetch_value(trace, :steps) || []

    with {:ok, normalized_steps} <- map_each(steps, &unified_trace_step_from_map/1) do
      UnifiedTrace.new(%{
        trace_id: fetch_value(trace, :trace_id),
        installation_ref: installation_ref_for_trace(trace, context),
        join_keys: fetch_value(trace, :join_keys) || %{},
        steps: normalized_steps,
        metadata: fetch_value(trace, :metadata) || %{}
      })
    end
  end

  defp unified_trace_from_map(_trace, _context), do: {:error, :invalid_unified_trace}

  defp installation_ref_for_trace(trace, %RequestContext{
         installation_ref: %InstallationRef{} = installation_ref
       }) do
    case fetch_value(trace, :installation_id) do
      nil -> installation_ref
      installation_id when installation_id == installation_ref.id -> installation_ref
      _other -> nil
    end
  end

  defp installation_ref_for_trace(_trace, _context), do: nil

  defp unified_trace_step_from_map(step) when is_map(step) do
    UnifiedTraceStep.new(%{
      ref: fetch_value(step, :ref) || fetch_value(step, :id),
      source: normalize_string(fetch_value(step, :source)),
      occurred_at: coerce_datetime(fetch_value(step, :occurred_at)),
      trace_id: fetch_value(step, :trace_id),
      causation_id: fetch_value(step, :causation_id),
      staleness_class: normalize_string(fetch_value(step, :staleness_class)),
      operator_actionable?: fetch_value(step, :operator_actionable?) || false,
      diagnostic?: fetch_value(step, :diagnostic?) || false,
      payload: fetch_value(step, :payload) || %{}
    })
  end

  defp unified_trace_step_from_map(_step), do: {:error, :invalid_unified_trace_step}

  defp read_lease_from_map(raw_read_lease) when is_map(raw_read_lease) do
    ReadLease.new(%{
      lease_ref: read_lease_ref_from_map(fetch_value(raw_read_lease, :lease_ref)),
      trace_id: fetch_value(raw_read_lease, :trace_id),
      expires_at: fetch_value(raw_read_lease, :expires_at),
      lease_token: fetch_value(raw_read_lease, :lease_token),
      allowed_operations: fetch_value(raw_read_lease, :allowed_operations) || [],
      authorization_scope: fetch_value(raw_read_lease, :authorization_scope) || %{},
      scope: fetch_value(raw_read_lease, :scope) || %{},
      lineage_anchor: fetch_value(raw_read_lease, :lineage_anchor) || %{},
      invalidation_cursor: fetch_value(raw_read_lease, :invalidation_cursor) || 0,
      invalidation_channel: fetch_value(raw_read_lease, :invalidation_channel)
    })
  end

  defp read_lease_from_map(_raw_read_lease), do: {:error, :invalid_read_lease}

  defp read_lease_ref_from_map(raw_read_lease_ref) when is_map(raw_read_lease_ref) do
    %{
      id: fetch_value(raw_read_lease_ref, :id),
      allowed_family: fetch_value(raw_read_lease_ref, :allowed_family),
      execution_ref: fetch_value(raw_read_lease_ref, :execution_ref)
    }
  end

  defp read_lease_ref_from_map(_raw_read_lease_ref), do: nil

  defp stream_attach_lease_from_map(raw_stream_attach_lease)
       when is_map(raw_stream_attach_lease) do
    StreamAttachLease.new(%{
      lease_ref:
        stream_attach_lease_ref_from_map(fetch_value(raw_stream_attach_lease, :lease_ref)),
      trace_id: fetch_value(raw_stream_attach_lease, :trace_id),
      expires_at: fetch_value(raw_stream_attach_lease, :expires_at),
      attach_token: fetch_value(raw_stream_attach_lease, :attach_token),
      authorization_scope: fetch_value(raw_stream_attach_lease, :authorization_scope) || %{},
      scope: fetch_value(raw_stream_attach_lease, :scope) || %{},
      lineage_anchor: fetch_value(raw_stream_attach_lease, :lineage_anchor) || %{},
      reconnect_cursor: fetch_value(raw_stream_attach_lease, :reconnect_cursor) || 0,
      invalidation_channel: fetch_value(raw_stream_attach_lease, :invalidation_channel),
      poll_interval_ms: fetch_value(raw_stream_attach_lease, :poll_interval_ms) || 2_000
    })
  end

  defp stream_attach_lease_from_map(_raw_stream_attach_lease),
    do: {:error, :invalid_stream_attach_lease}

  defp stream_attach_lease_ref_from_map(raw_stream_attach_lease_ref)
       when is_map(raw_stream_attach_lease_ref) do
    %{
      id: fetch_value(raw_stream_attach_lease_ref, :id),
      allowed_family: fetch_value(raw_stream_attach_lease_ref, :allowed_family),
      execution_ref: fetch_value(raw_stream_attach_lease_ref, :execution_ref)
    }
  end

  defp stream_attach_lease_ref_from_map(_raw_stream_attach_lease_ref), do: nil

  defp memory_fragment_projection_from_map(row) when is_map(row) do
    row
    |> strip_memory_raw_payload()
    |> MemoryFragmentProjection.new()
  end

  defp memory_fragment_projection_from_map(_row),
    do: {:error, :invalid_memory_fragment_projection}

  defp memory_fragment_provenance_from_map(row) when is_map(row) do
    row
    |> strip_memory_raw_payload()
    |> MemoryFragmentProvenance.new()
  end

  defp memory_fragment_provenance_from_map(_row),
    do: {:error, :invalid_memory_fragment_provenance}

  defp strip_memory_raw_payload(row) when is_map(row) do
    Map.drop(row, [
      :payload,
      "payload",
      :raw_payload,
      "raw_payload",
      :content,
      "content",
      :fragment_payload,
      "fragment_payload",
      :body,
      "body",
      :raw_fragment,
      "raw_fragment",
      :raw_content,
      "raw_content"
    ])
  end

  defp memory_request_attrs(%RequestContext{} = context, request) when is_map(request) do
    request
    |> Map.from_struct()
    |> Map.delete(:__struct__)
    |> Map.merge(memory_context_attrs(context))
    |> compact_map()
  end

  defp memory_context_attrs(%RequestContext{} = context) do
    %{
      tenant_ref: context.tenant_ref && context.tenant_ref.id,
      installation_ref: context.installation_ref && context.installation_ref.id,
      trace_id: context.trace_id,
      actor_ref: memory_actor_ref(context)
    }
    |> compact_map()
  end

  defp memory_actor_ref(%RequestContext{actor_ref: %{id: actor_id}}) when is_binary(actor_id),
    do: actor_id

  defp memory_actor_ref(_context), do: "app_kit"

  defp operator_action_from_map(raw_action) when is_map(raw_action) do
    raw_action_ref = fetch_value(raw_action, :action_ref) || raw_action

    with {:ok, action_ref} <- operator_action_ref_from_map(raw_action_ref) do
      OperatorAction.new(%{
        action_ref: action_ref,
        label: fetch_value(raw_action, :label) || action_label(action_ref.action_kind),
        description: fetch_value(raw_action, :description),
        dangerous?: danger_action?(action_ref.action_kind),
        requires_confirmation?:
          fetch_value(raw_action, :requires_confirmation?) ||
            danger_action?(action_ref.action_kind),
        metadata: fetch_value(raw_action, :metadata) || %{}
      })
    end
  end

  defp operator_action_from_map(_raw_action), do: {:error, :invalid_operator_action}

  defp action_label(action_kind) when is_binary(action_kind) do
    action_kind
    |> String.replace("_", " ")
    |> String.capitalize()
  end

  defp danger_action?(action_kind) when action_kind in ["cancel", "grant_override"], do: true
  defp danger_action?(_action_kind), do: false

  defp operator_action_ref_from_map(nil), do: {:ok, nil}

  defp operator_action_ref_from_map(raw_action_ref) when is_map(raw_action_ref) do
    with {:ok, subject_ref} <- subject_ref_from_action_map(raw_action_ref) do
      OperatorActionRef.new(%{
        id: fetch_value(raw_action_ref, :id),
        action_kind: fetch_value(raw_action_ref, :action_kind),
        subject_ref: subject_ref
      })
    end
  end

  defp operator_action_ref_from_map(_raw_action_ref), do: {:error, :invalid_operator_action_ref}

  defp subject_ref_from_action_map(raw_action_ref) do
    case fetch_value(raw_action_ref, :subject_ref) do
      nil -> {:ok, nil}
      raw_subject_ref when is_map(raw_subject_ref) -> SubjectRef.new(raw_subject_ref)
      _other -> {:error, :invalid_subject_ref}
    end
  end

  defp action_kind(%OperatorActionRequest{
         action_ref: %OperatorActionRef{action_kind: action_kind}
       }),
       do: action_kind

  defp operator_action_params(
         %RequestContext{} = context,
         %SubjectRef{} = subject_ref,
         %OperatorActionRequest{} = action_request
       ) do
    action_request.params
    |> Map.new()
    |> maybe_put("reason", action_request.reason)
    |> maybe_put("subject_kind", subject_ref.subject_kind)
    |> maybe_put("operator_context", operator_command_context(context, subject_ref))
  end

  defp operator_command_context(%RequestContext{} = context, %SubjectRef{} = subject_ref) do
    %{
      "tenant_id" => context.tenant_ref.id,
      "installation_id" => command_installation_id(context, subject_ref),
      "trace_id" => context.trace_id,
      "causation_id" => context.causation_id || context.request_id || context.trace_id,
      "idempotency_key" => context.idempotency_key,
      "actor_ref" => %{
        "kind" => to_string(context.actor_ref.kind),
        "id" => context.actor_ref.id,
        "tenant_id" => context.tenant_ref.id
      }
    }
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end

  defp command_installation_id(
         %RequestContext{installation_ref: %InstallationRef{id: installation_id}},
         _subject_ref
       ),
       do: installation_id

  defp command_installation_id(_context, %SubjectRef{
         installation_ref: %InstallationRef{id: installation_id}
       }),
       do: installation_id

  defp command_installation_id(_context, _subject_ref), do: nil

  defp actor_payload(%RequestContext{actor_ref: %{id: actor_id}}) when is_binary(actor_id),
    do: %{actor_ref: actor_id}

  defp actor_payload(_context), do: %{actor_ref: "app_kit"}

  defp actor_ref_from_any(nil), do: nil
  defp actor_ref_from_any(%ActorRef{} = actor_ref), do: actor_ref
  defp actor_ref_from_any(%{} = actor_ref), do: actor_ref

  defp actor_ref_from_any(actor_ref) when is_atom(actor_ref) do
    %{id: Atom.to_string(actor_ref), kind: :system}
  end

  defp actor_ref_from_any(actor_ref) when is_binary(actor_ref) do
    %{id: actor_ref, kind: :system}
  end

  defp actor_ref_from_any(_actor_ref), do: nil

  defp installation_or_tenant_id(%RequestContext{
         installation_ref: %InstallationRef{id: installation_id}
       })
       when is_binary(installation_id),
       do: {:ok, installation_id}

  defp installation_or_tenant_id(%RequestContext{tenant_ref: %{id: tenant_id}})
       when is_binary(tenant_id),
       do: {:ok, tenant_id}

  defp installation_or_tenant_id(_context), do: {:error, :missing_installation_id}

  defp tenant_id(%RequestContext{tenant_ref: %{id: tenant_id}}) when is_binary(tenant_id),
    do: {:ok, tenant_id}

  defp tenant_id(_context), do: {:error, :missing_tenant_id}

  defp ensure_subject_not_archived(%RequestContext{} = context, %SubjectRef{} = subject_ref) do
    case archival_installation_id(context, subject_ref) do
      {:ok, installation_id} ->
        case ArchivalQuery.archived_subject_manifest(installation_id, subject_ref.id) do
          {:ok, manifest} -> {:error, :archived, manifest.manifest_ref}
          {:error, :not_found} -> :ok
          {:error, _reason} -> :ok
        end

      :error ->
        :ok
    end
  end

  defp archival_installation_id(
         _context,
         %SubjectRef{installation_ref: %InstallationRef{id: installation_id}}
       )
       when is_binary(installation_id),
       do: {:ok, installation_id}

  defp archival_installation_id(
         %RequestContext{installation_ref: %InstallationRef{id: installation_id}},
         _subject_ref
       )
       when is_binary(installation_id),
       do: {:ok, installation_id}

  defp archival_installation_id(_context, _subject_ref), do: :error

  defp context_metadata(%RequestContext{metadata: metadata}, key) do
    Map.get(metadata, key) || Map.get(metadata, Atom.to_string(key))
  end

  defp revision_epoch_fields(%RequestContext{} = context, opts) do
    with {:ok, installation_revision} <-
           revision_epoch_value(context, opts, :installation_revision),
         {:ok, activation_epoch} <- revision_epoch_value(context, opts, :activation_epoch),
         {:ok, lease_epoch} <- revision_epoch_value(context, opts, :lease_epoch) do
      {:ok,
       %{
         installation_revision: installation_revision,
         activation_epoch: activation_epoch,
         lease_epoch: lease_epoch
       }}
    end
  end

  defp revision_epoch_value(%RequestContext{} = context, opts, key) do
    case Keyword.get(opts, key) || context_metadata(context, key) do
      value when is_integer(value) and value >= 0 ->
        {:ok, value}

      value when is_binary(value) ->
        case Integer.parse(value) do
          {parsed, ""} when parsed >= 0 -> {:ok, parsed}
          _other -> {:error, missing_revision_epoch_reason(key)}
        end

      _other ->
        {:error, missing_revision_epoch_reason(key)}
    end
  end

  defp missing_revision_epoch_reason(:installation_revision), do: :missing_installation_revision
  defp missing_revision_epoch_reason(:activation_epoch), do: :missing_activation_epoch
  defp missing_revision_epoch_reason(:lease_epoch), do: :missing_lease_epoch
end
