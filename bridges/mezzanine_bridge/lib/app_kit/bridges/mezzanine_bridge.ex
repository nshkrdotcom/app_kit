defmodule AppKit.Bridges.MezzanineBridge do
  @moduledoc """
  Internal AppKit backend adapter over lower-backed Mezzanine service modules.

  The bridge owns translation from lower service-shaped maps into the stable
  `AppKit.Core.*` contract so product-facing surfaces do not inherit lower
  structs or lower package topology.
  """

  @behaviour AppKit.Core.Backends.InstallationBackend
  @behaviour AppKit.Core.Backends.OperatorBackend
  @behaviour AppKit.Core.Backends.ReviewBackend
  @behaviour AppKit.Core.Backends.WorkBackend
  @behaviour AppKit.Core.Backends.WorkQueryBackend

  @authorization_reasons [:unauthorized_lower_read]
  alias AppKit.Core.{
    ActionResult,
    ActorRef,
    AuthoringBundleImport,
    BindingDescriptor,
    BindingEnvelope,
    BindingFailurePosture,
    BindingOwnership,
    BlockingCondition,
    DecisionRef,
    DecisionSummary,
    ExecutionRef,
    FilterSet,
    InstallationBinding,
    InstallationRef,
    InstallResult,
    InstallTemplate,
    NextStepPreview,
    OperatorAction,
    OperatorActionRef,
    OperatorActionRequest,
    OperatorProjection,
    PageRequest,
    PageResult,
    PendingObligation,
    ProjectionRef,
    ReadLease,
    RequestContext,
    Result,
    RunRef,
    RunRequest,
    StreamAttachLease,
    SubjectDetail,
    SubjectRef,
    SubjectSummary,
    SurfaceError,
    Telemetry,
    TimelineEvent,
    UnifiedTrace,
    UnifiedTraceStep
  }

  alias Mezzanine.Archival.Query, as: ArchivalQuery

  @impl true
  def ingest_subject(%RequestContext{} = context, attrs, opts)
      when is_map(attrs) and is_list(opts) do
    with {:ok, tenant_id} <- tenant_id(context),
         {:ok, program_id} <- program_id(context, opts),
         {:ok, work_class_id} <- work_class_id(context, attrs, opts),
         merged_attrs <-
           attrs
           |> Map.new()
           |> Map.put_new(:tenant_id, tenant_id)
           |> Map.put_new(:program_id, program_id)
           |> Map.put_new(:work_class_id, work_class_id),
         {:ok, subject} <- work_query_service(opts).ingest_subject(merged_attrs, opts),
         {:ok, subject_ref} <- subject_ref_from_summary(subject, context) do
      {:ok, subject_ref}
    else
      {:error, reason} -> normalize_surface_error(reason)
    end
  end

  @impl true
  def list_subjects(%RequestContext{} = context, filters, %PageRequest{} = page_request, opts)
      when (is_nil(filters) or is_struct(filters, FilterSet)) and is_list(opts) do
    with {:ok, tenant_id} <- tenant_id(context),
         {:ok, program_id} <- program_id(context, opts),
         {:ok, rows} <-
           work_query_service(opts).list_subjects(
             tenant_id,
             program_id,
             work_filters(filters || page_request.filters)
           ),
         {:ok, entries} <- map_each(rows, &subject_summary_from_row(&1, context)),
         {:ok, page_result} <- page_result(entries, page_request) do
      {:ok, page_result}
    else
      {:error, reason} -> normalize_surface_error(reason)
    end
  end

  @impl true
  def get_subject(%RequestContext{} = context, %SubjectRef{} = subject_ref, opts)
      when is_list(opts) do
    with :ok <- ensure_subject_not_archived(context, subject_ref),
         {:ok, tenant_id} <- tenant_id(context),
         {:ok, row} <- work_query_service(opts).get_subject_detail(tenant_id, subject_ref.id),
         {:ok, detail} <- subject_detail_from_row(row, context) do
      {:ok, detail}
    else
      {:error, :archived, manifest_ref} -> normalize_surface_error({:archived, manifest_ref})
      {:error, reason} -> normalize_surface_error(reason)
    end
  end

  @impl true
  def get_projection(%RequestContext{} = context, %ProjectionRef{} = projection_ref, opts)
      when is_list(opts) do
    with {:ok, tenant_id} <- tenant_id(context),
         {:ok, subject_id} <- subject_id_from_projection(projection_ref),
         {:ok, projection} <-
           work_query_service(opts).get_subject_projection(tenant_id, subject_id) do
      {:ok, projection}
    else
      {:error, :archived, manifest_ref} -> normalize_surface_error({:archived, manifest_ref})
      {:error, reason} -> normalize_surface_error(reason)
    end
  end

  @impl true
  def queue_stats(%RequestContext{} = context, filters, opts)
      when (is_nil(filters) or is_struct(filters, FilterSet)) and is_list(opts) do
    with {:ok, tenant_id} <- tenant_id(context),
         {:ok, program_id} <- program_id(context, opts),
         {:ok, stats} <- work_query_service(opts).queue_stats(tenant_id, program_id) do
      {:ok, Map.merge(stats, %{filters: work_filters(filters)})}
    else
      {:error, reason} -> normalize_surface_error(reason)
    end
  end

  @impl true
  def list_pending(%RequestContext{} = context, %PageRequest{} = page_request, opts)
      when is_list(opts) do
    with {:ok, tenant_id} <- tenant_id(context),
         {:ok, program_id} <- program_id(context, opts),
         {:ok, rows} <- review_query_service(opts).list_pending_reviews(tenant_id, program_id),
         {:ok, entries} <- map_each(rows, &decision_summary_from_row(&1, context)),
         {:ok, page_result} <- page_result(entries, page_request) do
      {:ok, page_result}
    else
      {:error, reason} -> normalize_surface_error(reason)
    end
  end

  @impl true
  def get_review(%RequestContext{} = context, %DecisionRef{} = decision_ref, opts)
      when is_list(opts) do
    with {:ok, tenant_id} <- tenant_id(context),
         {:ok, review_detail} <-
           review_query_service(opts).get_review_detail(tenant_id, decision_ref.id) do
      {:ok, review_detail}
    else
      {:error, reason} -> normalize_surface_error(reason)
    end
  end

  @impl true
  def record_decision(%RequestContext{} = context, %DecisionRef{} = decision_ref, attrs, opts)
      when is_map(attrs) and is_list(opts) do
    with {:ok, tenant_id} <- tenant_id(context),
         {:ok, program_id} <- program_id(context, opts),
         merged_attrs <-
           attrs
           |> Map.new()
           |> Map.put_new(:program_id, program_id)
           |> Map.put_new(:actor_ref, context.actor_ref.id),
         {:ok, bridge_result} <-
           review_action_service(opts).record_decision(
             tenant_id,
             decision_ref.id,
             merged_attrs,
             opts
           ),
         {:ok, action_result} <- action_result_from_bridge(bridge_result) do
      {:ok, action_result}
    else
      {:error, reason} -> normalize_surface_error(reason)
    end
  end

  @impl true
  def create_installation(%RequestContext{} = context, %InstallTemplate{} = template, opts)
      when is_list(opts) do
    with {:ok, tenant_id} <- tenant_id(context),
         attrs <-
           template
           |> Map.from_struct()
           |> Map.put(:tenant_id, tenant_id)
           |> maybe_put_runtime_profile(context)
           |> Map.put_new(:metadata, %{}),
         {:ok, bridge_result} <- installation_service(opts).create_installation(attrs, opts),
         {:ok, install_result} <- install_result_from_bridge(bridge_result) do
      {:ok, install_result}
    else
      {:error, reason} -> normalize_surface_error(reason)
    end
  end

  @impl true
  def import_authoring_bundle(
        %RequestContext{} = context,
        %AuthoringBundleImport{} = bundle_import,
        opts
      )
      when is_list(opts) do
    with {:ok, tenant_id} <- tenant_id(context),
         attrs <-
           bundle_import
           |> Map.from_struct()
           |> Map.put(:tenant_id, tenant_id),
         {:ok, bridge_result} <- installation_service(opts).import_authoring_bundle(attrs, opts),
         {:ok, install_result} <- install_result_from_bridge(bridge_result) do
      {:ok, install_result}
    else
      {:error, reason} -> normalize_surface_error(reason)
    end
  end

  @impl true
  def get_installation(%RequestContext{} = _context, %InstallationRef{} = installation_ref, opts)
      when is_list(opts) do
    with {:ok, detail} <- installation_service(opts).get_installation(installation_ref.id, opts),
         {:ok, normalized_ref} <- installation_ref_from_detail(detail) do
      {:ok, normalized_ref}
    else
      {:error, reason} -> normalize_surface_error(reason)
    end
  end

  @impl true
  def update_bindings(
        %RequestContext{} = _context,
        %InstallationRef{} = installation_ref,
        bindings,
        opts
      )
      when is_list(bindings) and is_list(opts) do
    with {:ok, bridge_result} <-
           installation_service(opts).update_bindings(
             installation_ref.id,
             binding_config(bindings),
             opts
           ),
         {:ok, action_result} <- action_result_from_bridge(bridge_result) do
      {:ok, action_result}
    else
      {:error, reason} -> normalize_surface_error(reason)
    end
  end

  @impl true
  def list_installations(%RequestContext{} = context, %PageRequest{} = page_request, opts)
      when is_list(opts) do
    with {:ok, tenant_id} <- tenant_id(context),
         {:ok, rows} <-
           installation_service(opts).list_installations(
             tenant_id,
             installation_filters(page_request.filters),
             opts
           ),
         {:ok, entries} <- map_each(rows, &installation_ref_from_detail/1),
         {:ok, page_result} <- page_result(entries, page_request) do
      {:ok, page_result}
    else
      {:error, reason} -> normalize_surface_error(reason)
    end
  end

  @impl true
  def suspend_installation(
        %RequestContext{} = _context,
        %InstallationRef{} = installation_ref,
        opts
      )
      when is_list(opts) do
    with {:ok, bridge_result} <-
           installation_service(opts).suspend_installation(installation_ref.id, opts),
         {:ok, action_result} <- action_result_from_bridge(bridge_result) do
      {:ok, action_result}
    else
      {:error, reason} -> normalize_surface_error(reason)
    end
  end

  @impl true
  def reactivate_installation(
        %RequestContext{} = _context,
        %InstallationRef{} = installation_ref,
        opts
      )
      when is_list(opts) do
    with {:ok, bridge_result} <-
           installation_service(opts).reactivate_installation(installation_ref.id, opts),
         {:ok, action_result} <- action_result_from_bridge(bridge_result) do
      {:ok, action_result}
    else
      {:error, reason} -> normalize_surface_error(reason)
    end
  end

  @impl true
  def start_run(%RequestContext{} = context, %RunRequest{} = run_request, opts)
      when is_list(opts) do
    service = work_control_service(opts)

    if service_exports?(service, :start_run, 3) do
      case service.start_run(context, run_request, opts) do
        {:ok, result} -> {:ok, result}
        {:error, reason} -> normalize_surface_error(reason)
      end
    else
      with {:ok, bridge_result} <- start_run_via_operator_action(context, run_request, opts),
           {:ok, action_result} <- action_result_from_bridge(bridge_result),
           {:ok, projection} <- fetch_operator_projection(context, run_request.subject_ref, opts),
           {:ok, run_ref} <- run_ref_from_projection(projection, context, run_request, opts),
           {:ok, result} <- run_result_from_projection(projection, run_ref, action_result) do
        {:ok, result}
      else
        {:error, reason} -> normalize_surface_error(reason)
      end
    end
  end

  @impl true
  def retry_run(%RequestContext{} = context, %RunRef{} = run_ref, opts) when is_list(opts) do
    service = work_control_service(opts)

    if service_exports?(service, :retry_run, 3) do
      case service.retry_run(context, run_ref, opts) do
        {:ok, result} -> {:ok, result}
        {:error, reason} -> normalize_surface_error(reason)
      end
    else
      work_control_action(context, run_ref, :replan, "retry", opts)
    end
  end

  @impl true
  def cancel_run(%RequestContext{} = context, %RunRef{} = run_ref, opts) when is_list(opts) do
    service = work_control_service(opts)

    if service_exports?(service, :cancel_run, 3) do
      case service.cancel_run(context, run_ref, opts) do
        {:ok, result} -> {:ok, result}
        {:error, reason} -> normalize_surface_error(reason)
      end
    else
      work_control_action(context, run_ref, :cancel, "cancel", opts)
    end
  end

  @impl true
  def subject_status(%RequestContext{} = context, %SubjectRef{} = subject_ref, opts)
      when is_list(opts) do
    with :ok <- ensure_subject_not_archived(context, subject_ref),
         {:ok, tenant_id} <- tenant_id(context),
         {:ok, row} <- operator_query_service(opts).subject_status(tenant_id, subject_ref.id),
         {:ok, projection} <- operator_projection_from_row(row, context) do
      {:ok, projection}
    else
      {:error, :archived, manifest_ref} -> normalize_surface_error({:archived, manifest_ref})
      {:error, reason} -> normalize_surface_error(reason)
    end
  end

  @impl true
  def timeline(%RequestContext{} = context, %SubjectRef{} = subject_ref, opts)
      when is_list(opts) do
    with :ok <- ensure_subject_not_archived(context, subject_ref),
         {:ok, tenant_id} <- tenant_id(context),
         {:ok, timeline_result} <-
           operator_query_service(opts).timeline(tenant_id, subject_ref.id),
         entries <- fetch_value(timeline_result, :entries) || [],
         {:ok, timeline_entries} <- map_each(entries, &timeline_event_from_map/1) do
      {:ok, timeline_entries}
    else
      {:error, :archived, manifest_ref} -> normalize_surface_error({:archived, manifest_ref})
      {:error, reason} -> normalize_surface_error(reason)
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
         {:ok, trace} <- operator_query_service(opts).get_unified_trace(trace_attrs, opts),
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
      {:error, reason} -> normalize_surface_error(reason)
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
         {:ok, lease} <- lease_service(opts).issue_read_lease(attrs, opts),
         {:ok, read_lease} <- read_lease_from_map(lease) do
      {:ok, read_lease}
    else
      {:error, reason} -> normalize_surface_error(reason)
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
         {:ok, lease} <- lease_service(opts).issue_stream_attach_lease(attrs, opts),
         {:ok, stream_attach_lease} <- stream_attach_lease_from_map(lease) do
      {:ok, stream_attach_lease}
    else
      {:error, reason} -> normalize_surface_error(reason)
    end
  end

  @impl true
  def available_actions(%RequestContext{} = context, %SubjectRef{} = subject_ref, opts)
      when is_list(opts) do
    with :ok <- ensure_subject_not_archived(context, subject_ref),
         {:ok, tenant_id} <- tenant_id(context),
         {:ok, rows} <- operator_query_service(opts).available_actions(tenant_id, subject_ref.id),
         {:ok, actions} <- map_each(rows, &operator_action_from_map/1) do
      {:ok, actions}
    else
      {:error, :archived, manifest_ref} -> normalize_surface_error({:archived, manifest_ref})
      {:error, reason} -> normalize_surface_error(reason)
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
         action_params <- operator_action_params(action_request),
         actor <- actor_payload(context),
         {:ok, bridge_result} <-
           operator_action_service(opts).apply_action(
             tenant_id,
             subject_ref.id,
             action_kind,
             action_params,
             actor
           ),
         {:ok, action_result} <- action_result_from_bridge(bridge_result) do
      {:ok, action_result}
    else
      {:error, reason} -> normalize_surface_error(reason)
    end
  end

  @impl true
  def start_run(domain_call, opts) when is_map(domain_call) and is_list(opts) do
    work_control_service(opts).start_run(domain_call, opts)
  end

  @impl true
  def run_status(run_ref, attrs, opts) when is_map(attrs) and is_list(opts) do
    case operator_query_service(opts).run_status(run_ref, attrs, opts) do
      {:ok, result} -> {:ok, result}
      {:error, :archived, manifest_ref} -> normalize_surface_error({:archived, manifest_ref})
      {:error, reason} -> normalize_surface_error(reason)
    end
  end

  @impl true
  def review_run(run_ref, evidence_attrs, opts) when is_map(evidence_attrs) and is_list(opts) do
    operator_action_service(opts).review_run(run_ref, evidence_attrs, opts)
  end

  defp start_run_via_operator_action(
         %RequestContext{} = context,
         %RunRequest{} = run_request,
         opts
       ) do
    with {:ok, tenant_id} <- tenant_id(context) do
      operator_action_service(opts).apply_action(
        tenant_id,
        run_request.subject_ref.id,
        :replan,
        run_request_action_params(run_request),
        actor_payload(context)
      )
    end
  end

  defp fetch_operator_projection(%RequestContext{} = context, %SubjectRef{} = subject_ref, opts) do
    with {:ok, tenant_id} <- tenant_id(context),
         {:ok, row} <- operator_query_service(opts).subject_status(tenant_id, subject_ref.id) do
      operator_projection_from_row(row, context)
    end
  end

  defp execution_trace_lineage(%RequestContext{} = context, %ExecutionRef{} = execution_ref, opts) do
    with {:ok, installation_id} <- installation_or_tenant_id(context),
         {:ok, lineage} <- operator_query_service(opts).execution_trace_lineage(execution_ref.id),
         true <- lineage.installation_id == installation_id do
      {:ok, lineage}
    else
      false -> {:error, :unauthorized_lower_read}
      {:error, reason} -> {:error, reason}
    end
  end

  defp run_result_from_projection(
         %OperatorProjection{} = projection,
         %RunRef{} = run_ref,
         action_result
       ) do
    Result.new(%{
      surface: :work_control,
      state: run_state(projection),
      payload: %{
        run_ref: run_ref,
        work_object_id: projection.subject_ref.id,
        subject_ref: projection.subject_ref,
        action_result: action_result
      }
    })
  end

  defp run_state(%OperatorProjection{pending_decision_refs: [_ | _]}), do: :waiting_review
  defp run_state(_projection), do: :scheduled

  defp run_ref_from_projection(
         %OperatorProjection{} = projection,
         %RequestContext{} = context,
         %RunRequest{} = run_request,
         opts
       ) do
    scope_id = scope_id(context, opts, projection.subject_ref.id)
    execution_id = projection.current_execution_ref && projection.current_execution_ref.id

    RunRef.new(%{
      run_id: execution_id || "subject/#{projection.subject_ref.id}",
      scope_id: scope_id,
      metadata: %{
        tenant_id: context.tenant_ref.id,
        work_object_id: projection.subject_ref.id,
        recipe_ref: run_request.recipe_ref,
        trace_id: context.trace_id
      }
    })
  end

  defp scope_id(%RequestContext{} = context, opts, subject_id) do
    case Keyword.get(opts, :scope_id) || context_metadata(context, :scope_id) do
      value when is_binary(value) and value != "" ->
        value

      _ ->
        case program_id(context, opts) do
          {:ok, value} -> "program/#{value}"
          {:error, _reason} -> "subject/#{subject_id}"
        end
    end
  end

  defp work_control_action(
         %RequestContext{} = context,
         %RunRef{} = run_ref,
         action,
         public_kind,
         opts
       ) do
    with {:ok, tenant_id} <- tenant_id(context),
         {:ok, subject_ref} <- subject_ref_from_run_ref(run_ref),
         {:ok, bridge_result} <-
           operator_action_service(opts).apply_action(
             tenant_id,
             subject_ref.id,
             action,
             %{requested_by: public_kind},
             actor_payload(context)
           ),
         {:ok, action_result} <- action_result_from_bridge(bridge_result),
         {:ok, normalized_result} <- normalize_public_action_result(action_result, public_kind) do
      {:ok, normalized_result}
    else
      {:error, reason} -> normalize_surface_error(reason)
    end
  end

  defp subject_ref_from_run_ref(%RunRef{metadata: metadata}) when is_map(metadata) do
    case Map.get(metadata, :work_object_id) || Map.get(metadata, "work_object_id") ||
           Map.get(metadata, :subject_id) || Map.get(metadata, "subject_id") do
      value when is_binary(value) ->
        SubjectRef.new(%{id: value, subject_kind: "work_object"})

      _ ->
        {:error, :missing_subject_id}
    end
  end

  defp subject_ref_from_run_ref(_run_ref), do: {:error, :missing_subject_id}

  defp normalize_public_action_result(%ActionResult{} = action_result, public_kind) do
    action_kind = normalize_string(public_kind)

    with {:ok, normalized_action_ref} <- public_action_ref(action_result.action_ref, action_kind) do
      ActionResult.new(%{
        status: action_result.status,
        action_ref: normalized_action_ref,
        execution_ref: action_result.execution_ref,
        message: public_action_message(action_result.message, action_kind),
        metadata: action_result.metadata
      })
    end
  end

  defp public_action_ref(nil, _action_kind), do: {:ok, nil}

  defp public_action_ref(%OperatorActionRef{} = action_ref, action_kind) do
    rewritten_id =
      case String.split(action_ref.id, ":", parts: 2) do
        [subject_id, _legacy_kind] -> "#{subject_id}:#{action_kind}"
        _other -> action_ref.id
      end

    OperatorActionRef.new(%{
      id: rewritten_id,
      action_kind: action_kind,
      subject_ref: action_ref.subject_ref
    })
  end

  defp public_action_message(nil, "retry"), do: "Retry queued"
  defp public_action_message(nil, "cancel"), do: "Cancelled"
  defp public_action_message(message, _action_kind), do: message

  defp operator_projection_from_row(row, %RequestContext{} = context) do
    payload = operator_projection_payload(row)

    with {:ok, subject_ref} <-
           operator_projection_subject_ref(row, context),
         {:ok, current_execution_ref} <-
           execution_ref_from_bridge(fetch_value(row, :current_execution_ref)),
         {:ok, pending_decision_refs} <-
           pending_decision_refs_from_maps(fetch_value(row, :pending_decision_refs) || []),
         {:ok, available_actions} <-
           operator_actions_from_maps(fetch_value(row, :available_actions) || []),
         {:ok, pending_obligations} <-
           operator_projection_pending_obligations(row, payload),
         {:ok, blocking_conditions} <-
           operator_projection_blocking_conditions(row, payload),
         {:ok, next_step_preview} <-
           operator_projection_next_step_preview(row, payload),
         {:ok, timeline} <- operator_projection_timeline(row, payload) do
      OperatorProjection.new(%{
        subject_ref: subject_ref,
        lifecycle_state:
          normalize_string(
            fetch_value(row, :lifecycle_state) || fetch_value(row, :status) || "unknown"
          ),
        current_execution_ref: current_execution_ref,
        pending_decision_refs: pending_decision_refs,
        available_actions: available_actions,
        pending_obligations: pending_obligations,
        blocking_conditions: blocking_conditions,
        next_step_preview: next_step_preview,
        timeline: timeline,
        updated_at:
          coerce_datetime(fetch_value(row, :updated_at) || fetch_value(payload, :last_event_at)),
        payload: payload
      })
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp operator_projection_payload(row), do: fetch_value(row, :payload) || %{}

  defp operator_projection_subject_ref(row, %RequestContext{} = context) do
    case subject_ref_from_any(fetch_value(row, :subject_ref), context) do
      {:ok, nil} -> {:error, :invalid_subject_ref}
      other -> other
    end
  end

  defp operator_projection_pending_obligations(row, payload) do
    pending_obligations_from_maps(
      fetch_value(row, :pending_obligations) || fetch_value(payload, :pending_obligations) || []
    )
  end

  defp operator_projection_blocking_conditions(row, payload) do
    blocking_conditions_from_maps(
      fetch_value(row, :blocking_conditions) || fetch_value(payload, :blocking_conditions) || []
    )
  end

  defp operator_projection_next_step_preview(row, payload) do
    next_step_preview_from_map(
      fetch_value(row, :next_step_preview) || fetch_value(payload, :next_step_preview)
    )
  end

  defp operator_projection_timeline(row, payload) do
    row
    |> operator_projection_timeline_rows(payload)
    |> map_each(&timeline_event_from_map/1)
  end

  defp operator_projection_timeline_rows(row, payload) do
    fetch_value(payload, :timeline) || fetch_value(row, :timeline) || []
  end

  defp pending_decision_refs_from_maps(rows) when is_list(rows) do
    rows
    |> Enum.map(&DecisionRef.new/1)
    |> collect()
  end

  defp operator_actions_from_maps(rows) when is_list(rows) do
    map_each(rows, &operator_action_from_map/1)
  end

  defp pending_obligations_from_maps(rows) when is_list(rows) do
    map_each(rows, &pending_obligation_from_map/1)
  end

  defp pending_obligation_from_map(row) when is_map(row) do
    PendingObligation.new(%{
      obligation_id: fetch_value(row, :obligation_id),
      obligation_kind:
        normalize_string(fetch_value(row, :obligation_kind) || fetch_value(row, :kind)),
      status: normalize_string(fetch_value(row, :status) || "pending"),
      summary: fetch_value(row, :summary),
      decision_ref_id: fetch_value(row, :decision_ref_id),
      required_by: coerce_datetime(fetch_value(row, :required_by)),
      blocking?: fetch_value(row, :blocking?) || false,
      metadata: fetch_value(row, :metadata) || %{}
    })
  end

  defp pending_obligation_from_map(_row), do: {:error, :invalid_pending_obligation}

  defp blocking_conditions_from_maps(rows) when is_list(rows) do
    map_each(rows, &blocking_condition_from_map/1)
  end

  defp blocking_condition_from_map(row) when is_map(row) do
    BlockingCondition.new(%{
      blocker_kind: normalize_string(fetch_value(row, :blocker_kind) || fetch_value(row, :kind)),
      status: normalize_string(fetch_value(row, :status) || "blocked"),
      summary: fetch_value(row, :summary),
      reason: normalize_string(fetch_value(row, :reason)),
      obligation_id: fetch_value(row, :obligation_id),
      decision_ref_id: fetch_value(row, :decision_ref_id),
      metadata: fetch_value(row, :metadata) || %{}
    })
  end

  defp blocking_condition_from_map(_row), do: {:error, :invalid_blocking_condition}

  defp next_step_preview_from_map(nil), do: {:ok, nil}

  defp next_step_preview_from_map(row) when is_map(row) do
    NextStepPreview.new(%{
      step_kind: normalize_string(fetch_value(row, :step_kind)),
      status: normalize_string(fetch_value(row, :status)),
      summary: fetch_value(row, :summary),
      blocking_condition_kinds:
        Enum.map(fetch_value(row, :blocking_condition_kinds) || [], &normalize_string/1),
      obligation_ids: fetch_value(row, :obligation_ids) || [],
      metadata: fetch_value(row, :metadata) || %{}
    })
  end

  defp next_step_preview_from_map(_row), do: {:error, :invalid_next_step_preview}

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

  defp installation_or_tenant_id(%RequestContext{
         installation_ref: %InstallationRef{id: installation_id}
       })
       when is_binary(installation_id),
       do: {:ok, installation_id}

  defp installation_or_tenant_id(%RequestContext{tenant_ref: %{id: tenant_id}})
       when is_binary(tenant_id),
       do: {:ok, tenant_id}

  defp installation_or_tenant_id(_context), do: {:error, :missing_installation_id}

  defp actor_payload(%RequestContext{actor_ref: %{id: actor_id}}) when is_binary(actor_id),
    do: %{actor_ref: actor_id}

  defp actor_payload(_context), do: %{actor_ref: "app_kit"}

  defp coerce_datetime(nil), do: nil
  defp coerce_datetime(%DateTime{} = value), do: value

  defp coerce_datetime(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _offset} -> datetime
      _other -> value
    end
  end

  defp coerce_datetime(value), do: value

  defp action_kind(%OperatorActionRequest{
         action_ref: %OperatorActionRef{action_kind: action_kind}
       }),
       do: action_kind

  defp operator_action_params(%OperatorActionRequest{} = action_request) do
    action_request.params
    |> Map.new()
    |> maybe_put("reason", action_request.reason)
  end

  defp run_request_action_params(%RunRequest{} = run_request) do
    run_request.params
    |> Map.new()
    |> maybe_put("recipe_ref", run_request.recipe_ref)
    |> maybe_put("reason", run_request.reason)
  end

  defp work_query_service(opts),
    do: Keyword.get(opts, :work_query_service, Mezzanine.AppKitBridge.WorkQueryService)

  defp review_query_service(opts),
    do: Keyword.get(opts, :review_query_service, Mezzanine.AppKitBridge.ReviewQueryService)

  defp review_action_service(opts),
    do: Keyword.get(opts, :review_action_service, Mezzanine.AppKitBridge.ReviewActionService)

  defp installation_service(opts),
    do: Keyword.get(opts, :installation_service, Mezzanine.AppKitBridge.InstallationService)

  defp lease_service(opts),
    do: Keyword.get(opts, :lease_service, Mezzanine.AppKitBridge.LeaseService)

  defp work_control_service(opts),
    do: Keyword.get(opts, :work_control_service, Mezzanine.AppKitBridge.WorkControlService)

  defp program_context_service(opts),
    do: Keyword.get(opts, :program_context_service, Mezzanine.AppKitBridge.ProgramContextService)

  defp operator_query_service(opts),
    do: Keyword.get(opts, :operator_query_service, Mezzanine.AppKitBridge.OperatorQueryService)

  defp operator_action_service(opts),
    do: Keyword.get(opts, :operator_action_service, Mezzanine.AppKitBridge.OperatorActionService)

  defp service_exports?(service, function_name, arity)
       when is_atom(service) and is_atom(function_name) and is_integer(arity) do
    match?({:module, ^service}, Code.ensure_loaded(service)) and
      function_exported?(service, function_name, arity)
  end

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

  defp program_id(%RequestContext{} = context, opts) do
    case explicit_program_id(context, opts) do
      {:ok, program_id} ->
        {:ok, program_id}

      :missing ->
        with {:ok, tenant_id} <- tenant_id(context),
             {:ok, program_slug} <- program_slug(context, opts),
             {:ok, resolution} <-
               program_context_service(opts).resolve(
                 tenant_id,
                 %{program_slug: program_slug},
                 opts
               ),
             {:ok, program_id} <- resolved_id(resolution, :program_id, :missing_program_id) do
          {:ok, program_id}
        else
          {:error, :missing_program_slug} -> {:error, :missing_program_id}
          {:error, reason} -> {:error, reason}
        end
    end
  end

  defp work_class_id(%RequestContext{} = context, attrs, opts) do
    case explicit_work_class_id(context, attrs, opts) do
      {:ok, work_class_id} ->
        {:ok, work_class_id}

      :missing ->
        with {:ok, tenant_id} <- tenant_id(context),
             {:ok, program_slug} <- program_slug(context, opts),
             {:ok, work_class_name} <- work_class_name(context, attrs, opts),
             {:ok, resolution} <-
               program_context_service(opts).resolve(
                 tenant_id,
                 %{program_slug: program_slug, work_class_name: work_class_name},
                 opts
               ),
             {:ok, work_class_id} <-
               resolved_id(resolution, :work_class_id, :missing_work_class_id) do
          {:ok, work_class_id}
        else
          {:error, :missing_program_slug} -> {:error, :missing_work_class_id}
          {:error, :missing_work_class_name} -> {:error, :missing_work_class_id}
          {:error, reason} -> {:error, reason}
        end
    end
  end

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
          _ -> {:error, missing_revision_epoch_reason(key)}
        end

      _ ->
        {:error, missing_revision_epoch_reason(key)}
    end
  end

  defp missing_revision_epoch_reason(:installation_revision), do: :missing_installation_revision
  defp missing_revision_epoch_reason(:activation_epoch), do: :missing_activation_epoch
  defp missing_revision_epoch_reason(:lease_epoch), do: :missing_lease_epoch

  defp explicit_program_id(%RequestContext{} = context, opts) do
    case Keyword.get(opts, :program_id) || context_metadata(context, :program_id) do
      value when is_binary(value) and value != "" -> {:ok, value}
      _ -> :missing
    end
  end

  defp explicit_work_class_id(%RequestContext{} = context, attrs, opts) do
    case Keyword.get(opts, :work_class_id) || fetch_value(attrs, :work_class_id) ||
           context_metadata(context, :work_class_id) do
      value when is_binary(value) and value != "" -> {:ok, value}
      _ -> :missing
    end
  end

  defp program_slug(%RequestContext{} = context, opts) do
    case Keyword.get(opts, :program_slug) || context_metadata(context, :program_slug) do
      value when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, :missing_program_slug}
    end
  end

  defp work_class_name(%RequestContext{} = context, attrs, opts) do
    case Keyword.get(opts, :work_class_name) || fetch_value(attrs, :work_class_name) ||
           context_metadata(context, :work_class_name) do
      value when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, :missing_work_class_name}
    end
  end

  defp resolved_id(resolution, key, error) when is_map(resolution) do
    case fetch_value(resolution, key) do
      value when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, error}
    end
  end

  defp subject_id_from_projection(%ProjectionRef{subject_ref: %SubjectRef{id: subject_id}})
       when is_binary(subject_id),
       do: {:ok, subject_id}

  defp subject_id_from_projection(_projection_ref), do: {:error, :missing_subject_id}

  defp work_filters(nil), do: %{}

  defp work_filters(%FilterSet{clauses: clauses}) do
    Enum.reduce(clauses, %{}, fn clause, acc ->
      field = fetch_value(clause, :field)
      op = fetch_value(clause, :op)
      value = fetch_value(clause, :value)

      case {field, op, value} do
        {"status", "eq", filter_value} ->
          Map.put(acc, :statuses, [normalize_atomish(filter_value)])

        {"status", "in", filter_value} when is_list(filter_value) ->
          Map.put(acc, :statuses, Enum.map(filter_value, &normalize_atomish/1))

        {"lifecycle_state", "eq", filter_value} ->
          Map.put(acc, :statuses, [normalize_atomish(filter_value)])

        {"source_kind", "eq", filter_value} when is_binary(filter_value) ->
          Map.put(acc, :source_kind, filter_value)

        {"work_class_id", "eq", filter_value} when is_binary(filter_value) ->
          Map.put(acc, :work_class_id, filter_value)

        _ ->
          acc
      end
    end)
  end

  defp installation_filters(nil), do: %{}

  defp installation_filters(%FilterSet{clauses: clauses}) do
    Enum.reduce(clauses, %{}, fn clause, acc ->
      field = fetch_value(clause, :field)
      op = fetch_value(clause, :op)
      value = fetch_value(clause, :value)

      case {field, op, value} do
        {"status", "eq", filter_value} ->
          Map.put(acc, :status, normalize_atomish(filter_value))

        {"environment", "eq", filter_value} when is_binary(filter_value) ->
          Map.put(acc, :environment, filter_value)

        {"pack_slug", "eq", filter_value} when is_binary(filter_value) ->
          Map.put(acc, :pack_slug, filter_value)

        _ ->
          acc
      end
    end)
  end

  defp binding_config(bindings) do
    Enum.reduce(bindings, %{}, fn %InstallationBinding{} = binding, acc ->
      kind_key = "#{binding.binding_kind}_bindings"

      config =
        binding.config
        |> Map.new()
        |> maybe_put("credential_ref", binding.credential_ref)
        |> maybe_put("descriptor", serialize_binding_descriptor(binding.descriptor))

      Map.update(acc, kind_key, %{binding.binding_key => config}, fn grouped ->
        Map.put(grouped, binding.binding_key, config)
      end)
    end)
  end

  defp serialize_binding_descriptor(nil), do: nil

  defp serialize_binding_descriptor(%BindingDescriptor{} = descriptor) do
    %{
      "attachment" => descriptor.attachment,
      "contract" => Atom.to_string(descriptor.contract),
      "envelope" => serialize_binding_envelope(descriptor.envelope),
      "failure" => serialize_binding_failure(descriptor.failure),
      "ownership" => serialize_binding_ownership(descriptor.ownership)
    }
  end

  defp serialize_binding_envelope(%BindingEnvelope{} = envelope) do
    %{
      "staleness_class" => Atom.to_string(envelope.staleness_class),
      "trace_propagation" => Atom.to_string(envelope.trace_propagation),
      "tenant_scope" => Atom.to_string(envelope.tenant_scope),
      "blast_radius" => Atom.to_string(envelope.blast_radius),
      "timeout_ms" => envelope.timeout_ms,
      "runbook_ref" => envelope.runbook_ref
    }
  end

  defp serialize_binding_failure(%BindingFailurePosture{} = failure) do
    %{
      "on_unavailable" => Atom.to_string(failure.on_unavailable),
      "on_timeout" => Atom.to_string(failure.on_timeout)
    }
  end

  defp serialize_binding_ownership(%BindingOwnership{} = ownership) do
    %{
      "external_system" => ownership.external_system,
      "external_system_ref" => ownership.external_system_ref,
      "operator_owner" => ownership.operator_owner
    }
  end

  defp page_result(entries, %PageRequest{} = page_request) do
    sorted_entries = sort_entries(entries, page_request.sort)
    offset = decode_cursor(page_request.cursor)
    page_entries = Enum.slice(sorted_entries, offset, page_request.limit)
    has_more = offset + length(page_entries) < length(sorted_entries)
    next_cursor = if has_more, do: Integer.to_string(offset + length(page_entries)), else: nil

    PageResult.new(%{
      entries: page_entries,
      next_cursor: next_cursor,
      total_count: length(sorted_entries),
      has_more: has_more
    })
  end

  defp sort_entries(entries, []), do: entries

  defp sort_entries(entries, [sort_spec | _rest]) do
    sorter = fn entry ->
      value = fetch_value(entry, sort_spec.field)

      case {value, sort_spec.nulls || :last} do
        {nil, :first} -> {0, nil}
        {nil, :last} -> {1, nil}
        {other, _nulls} -> {1, other}
      end
    end

    direction = if sort_spec.direction == :desc, do: :desc, else: :asc
    Enum.sort_by(entries, sorter, direction)
  end

  defp decode_cursor(nil), do: 0

  defp decode_cursor(cursor) when is_binary(cursor) do
    case Integer.parse(cursor) do
      {offset, ""} when offset >= 0 -> offset
      _ -> 0
    end
  end

  defp map_each(entries, mapper) do
    Enum.reduce_while(entries, {:ok, []}, fn entry, {:ok, acc} ->
      case mapper.(entry) do
        {:ok, mapped} -> {:cont, {:ok, [mapped | acc]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, mapped} -> {:ok, Enum.reverse(mapped)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp subject_ref_from_summary(summary, %RequestContext{} = context) do
    SubjectRef.new(%{
      id: fetch_value(summary, :subject_id),
      subject_kind: normalize_string(fetch_value(summary, :subject_kind) || "subject"),
      installation_ref: context.installation_ref
    })
  end

  defp subject_summary_from_row(row, %RequestContext{} = context) do
    with {:ok, subject_ref} <- subject_ref_from_summary(row, context) do
      SubjectSummary.new(%{
        subject_ref: subject_ref,
        lifecycle_state: normalize_string(fetch_value(row, :status) || "unknown"),
        title: fetch_value(row, :title),
        summary: fetch_value(row, :description),
        opened_at: fetch_value(row, :inserted_at),
        updated_at: fetch_value(row, :updated_at),
        schema_ref: "mezzanine/work_object",
        schema_version: 1,
        payload:
          compact_map(%{
            program_id: fetch_value(row, :program_id),
            work_class_id: fetch_value(row, :work_class_id),
            external_ref: fetch_value(row, :external_ref),
            priority: fetch_value(row, :priority),
            source_kind: fetch_value(row, :source_kind),
            current_plan_id: fetch_value(row, :current_plan_id)
          })
      })
    end
  end

  defp subject_detail_from_row(row, %RequestContext{} = context) do
    with {:ok, subject_ref} <- subject_ref_from_summary(row, context),
         {:ok, current_execution_ref} <- execution_ref_from_row(row, subject_ref),
         {:ok, pending_decision_refs} <- pending_decision_refs_from_row(row, subject_ref),
         {:ok, pending_obligations} <-
           pending_obligations_from_maps(fetch_value(row, :pending_obligations) || []),
         {:ok, blocking_conditions} <-
           blocking_conditions_from_maps(fetch_value(row, :blocking_conditions) || []),
         {:ok, next_step_preview} <-
           next_step_preview_from_map(fetch_value(row, :next_step_preview)) do
      SubjectDetail.new(%{
        subject_ref: subject_ref,
        lifecycle_state: normalize_string(fetch_value(row, :status) || "unknown"),
        title: fetch_value(row, :title),
        description: fetch_value(row, :description),
        current_execution_ref: current_execution_ref,
        pending_decision_refs: pending_decision_refs,
        available_actions: [],
        pending_obligations: pending_obligations,
        blocking_conditions: blocking_conditions,
        next_step_preview: next_step_preview,
        schema_ref: "mezzanine/work_object",
        schema_version: 1,
        payload:
          compact_map(%{
            program_id: fetch_value(row, :program_id),
            work_class_id: fetch_value(row, :work_class_id),
            external_ref: fetch_value(row, :external_ref),
            priority: fetch_value(row, :priority),
            source_kind: fetch_value(row, :source_kind),
            current_plan_id: fetch_value(row, :current_plan_id),
            current_plan_status: normalize_string(fetch_value(row, :current_plan_status)),
            active_run_id: fetch_value(row, :active_run_id),
            active_run_status: normalize_string(fetch_value(row, :active_run_status)),
            active_execution_trace_id:
              normalize_string(fetch_value(row, :active_execution_trace_id)),
            latest_execution_id: fetch_value(row, :latest_execution_id),
            latest_execution_dispatch_state:
              normalize_string(fetch_value(row, :latest_execution_dispatch_state)),
            latest_execution_trace_id:
              normalize_string(fetch_value(row, :latest_execution_trace_id)),
            gate_status: fetch_value(row, :gate_status),
            timeline: fetch_value(row, :timeline),
            audit_events: fetch_value(row, :audit_events),
            run_series_ids: fetch_value(row, :run_series_ids),
            obligation_ids: fetch_value(row, :obligation_ids),
            pending_obligations: fetch_value(row, :pending_obligations),
            blocking_conditions: fetch_value(row, :blocking_conditions),
            next_step_preview: fetch_value(row, :next_step_preview),
            evidence_bundle_id: fetch_value(row, :evidence_bundle_id),
            control_session_id: fetch_value(row, :control_session_id),
            control_mode: normalize_string(fetch_value(row, :control_mode)),
            last_event_at: fetch_value(row, :last_event_at)
          })
      })
    end
  end

  defp execution_ref_from_row(row, %SubjectRef{} = subject_ref) do
    case fetch_value(row, :active_execution_id) do
      execution_id when is_binary(execution_id) ->
        ExecutionRef.new(%{
          id: execution_id,
          subject_ref: subject_ref,
          dispatch_state: normalize_string(fetch_value(row, :active_execution_dispatch_state))
        })

      _ ->
        {:ok, nil}
    end
  end

  defp pending_decision_refs_from_row(row, %SubjectRef{} = subject_ref) do
    pending_review_ids = fetch_value(row, :pending_review_ids) || []

    pending_review_ids
    |> Enum.map(fn review_id ->
      DecisionRef.new(%{
        id: review_id,
        decision_kind: "review",
        subject_ref: subject_ref
      })
    end)
    |> collect()
  end

  defp decision_summary_from_row(row, %RequestContext{} = context) do
    with {:ok, decision_ref} <- decision_ref_from_row(row, context) do
      DecisionSummary.new(%{
        decision_ref: decision_ref,
        status: normalize_string(fetch_value(row, :status) || "pending"),
        required_by: fetch_value(row, :required_by),
        subject_ref: decision_ref.subject_ref,
        summary: fetch_value(row, :summary),
        schema_ref: "mezzanine/review_unit",
        schema_version: 1,
        payload: fetch_value(row, :payload) || %{}
      })
    end
  end

  defp decision_ref_from_row(row, %RequestContext{} = context) do
    raw_ref = fetch_value(row, :decision_ref) || %{}
    raw_subject_ref = fetch_value(raw_ref, :subject_ref) || fetch_value(row, :subject_ref)

    with {:ok, subject_ref} <- subject_ref_from_any(raw_subject_ref, context) do
      DecisionRef.new(%{
        id: fetch_value(raw_ref, :id) || fetch_value(row, :review_unit_id),
        decision_kind:
          normalize_string(
            fetch_value(raw_ref, :decision_kind) || fetch_value(row, :review_kind) || "review"
          ),
        subject_ref: subject_ref
      })
    end
  end

  defp subject_ref_from_any(nil, _context), do: {:ok, nil}

  defp subject_ref_from_any(raw_subject_ref, %RequestContext{} = context)
       when is_map(raw_subject_ref) do
    SubjectRef.new(%{
      id: fetch_value(raw_subject_ref, :id),
      subject_kind: normalize_string(fetch_value(raw_subject_ref, :subject_kind) || "subject"),
      installation_ref: context.installation_ref
    })
  end

  defp install_result_from_bridge(bridge_result) do
    with {:ok, installation_ref} <-
           installation_ref_from_map(fetch_value(bridge_result, :installation_ref)) do
      InstallResult.new(%{
        installation_ref: installation_ref,
        status: fetch_value(bridge_result, :status),
        message: fetch_value(bridge_result, :message),
        metadata: fetch_value(bridge_result, :metadata) || %{}
      })
    end
  end

  defp installation_ref_from_detail(detail) do
    installation_ref_from_map(fetch_value(detail, :installation_ref))
  end

  defp installation_ref_from_map(raw_installation_ref) when is_map(raw_installation_ref) do
    InstallationRef.new(%{
      id: fetch_value(raw_installation_ref, :id),
      pack_slug: fetch_value(raw_installation_ref, :pack_slug),
      pack_version: fetch_value(raw_installation_ref, :pack_version),
      compiled_pack_revision: fetch_value(raw_installation_ref, :compiled_pack_revision),
      status: normalize_atomish(fetch_value(raw_installation_ref, :status))
    })
  end

  defp installation_ref_from_map(_raw_installation_ref), do: {:error, :invalid_installation_ref}

  defp maybe_put_runtime_profile(attrs, %RequestContext{} = context) do
    case context_metadata(context, :runtime_profile) do
      runtime_profile when is_map(runtime_profile) ->
        Map.put(attrs, :runtime_profile, runtime_profile)

      _other ->
        attrs
    end
  end

  defp action_result_from_bridge(bridge_result) do
    with {:ok, action_ref} <-
           operator_action_ref_from_map(fetch_value(bridge_result, :action_ref)),
         {:ok, execution_ref} <-
           execution_ref_from_bridge(fetch_value(bridge_result, :execution_ref)) do
      ActionResult.new(%{
        status: fetch_value(bridge_result, :status),
        action_ref: action_ref,
        execution_ref: execution_ref,
        message: fetch_value(bridge_result, :message),
        metadata: fetch_value(bridge_result, :metadata) || %{}
      })
    end
  end

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
      _ -> {:error, :invalid_subject_ref}
    end
  end

  defp execution_ref_from_bridge(nil), do: {:ok, nil}

  defp execution_ref_from_bridge(raw_execution_ref) when is_map(raw_execution_ref),
    do: ExecutionRef.new(raw_execution_ref)

  defp execution_ref_from_bridge(_raw_execution_ref), do: {:error, :invalid_execution_ref}

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

  defp collect(results) do
    Enum.reduce_while(results, {:ok, []}, fn
      {:ok, value}, {:ok, acc} -> {:cont, {:ok, [value | acc]}}
      {:error, reason}, _acc -> {:halt, {:error, reason}}
    end)
    |> case do
      {:ok, values} -> {:ok, Enum.reverse(values)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp fetch_value(map_or_struct, key) when is_map(map_or_struct) do
    map = if is_struct(map_or_struct), do: Map.from_struct(map_or_struct), else: map_or_struct
    Map.get(map, key) || Map.get(map, alternate_key(map, key))
  end

  defp fetch_value(_map_or_struct, _key), do: nil

  defp alternate_key(_map, key) when is_atom(key), do: Atom.to_string(key)

  defp alternate_key(map, key) when is_binary(key) do
    Enum.find(Map.keys(map), fn
      existing_key when is_atom(existing_key) -> Atom.to_string(existing_key) == key
      _existing_key -> false
    end)
  end

  defp alternate_key(_map, _key), do: nil

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp compact_map(map) do
    Map.reject(map, fn {_key, value} -> is_nil(value) end)
  end

  @normalized_atomish_values %{
    "active" => :active,
    "awaiting_review" => :awaiting_review,
    "blocked" => :blocked,
    "created" => :created,
    "degraded" => :degraded,
    "inactive" => :inactive,
    "pending" => :pending,
    "planned" => :planned,
    "planning" => :planning,
    "reused" => :reused,
    "running" => :running,
    "suspended" => :suspended,
    "updated" => :updated
  }

  @not_found_reasons [:bridge_not_found, :not_found, :pack_registration_not_found]
  @conflict_reasons [:installation_pack_conflict, :review_gate_not_satisfied]
  @transient_reasons [:timeout, :temporarily_unavailable]
  @validation_reason_prefixes ["missing_", "invalid_", "unsupported_"]

  defp normalize_atomish(value) when is_binary(value),
    do: Map.get(@normalized_atomish_values, value, value)

  defp normalize_atomish(value), do: value

  defp normalize_string(nil), do: nil
  defp normalize_string(value) when is_atom(value), do: Atom.to_string(value)
  defp normalize_string(value), do: value

  defp normalize_surface_error(%SurfaceError{} = error), do: {:error, error}

  defp normalize_surface_error({:archived, manifest_ref}) when is_binary(manifest_ref) do
    {:ok, error} =
      SurfaceError.new(%{
        code: "archived",
        message: "Subject is archived",
        kind: :terminal,
        retryable: false,
        details: %{manifest_ref: manifest_ref}
      })

    {:error, error}
  end

  defp normalize_surface_error(reason) do
    {:ok, error} =
      SurfaceError.new(%{
        code: surface_error_code(reason),
        message: surface_error_message(reason),
        kind: surface_error_kind(reason),
        retryable: surface_error_retryable?(reason),
        details: %{reason: inspect(reason)}
      })

    {:error, error}
  end

  defp surface_error_code(reason) when is_atom(reason), do: Atom.to_string(reason)
  defp surface_error_code(_reason), do: "bridge_error"

  defp surface_error_message(reason) do
    reason
    |> inspect()
    |> String.trim_leading(":")
    |> String.replace("_", " ")
    |> String.capitalize()
  end

  defp surface_error_kind(reason) when reason in @authorization_reasons, do: :authorization
  defp surface_error_kind(reason) when reason in @not_found_reasons, do: :not_found
  defp surface_error_kind(reason) when reason in @conflict_reasons, do: :conflict
  defp surface_error_kind(reason) when reason in @transient_reasons, do: :transient

  defp surface_error_kind(reason) when is_atom(reason) do
    if validation_reason?(reason), do: :validation, else: :boundary
  end

  defp surface_error_kind(_reason), do: :boundary

  defp surface_error_retryable?(reason), do: surface_error_kind(reason) == :transient

  defp validation_reason?(reason) when is_atom(reason) do
    reason
    |> Atom.to_string()
    |> then(fn string_reason ->
      Enum.any?(@validation_reason_prefixes, &String.starts_with?(string_reason, &1))
    end)
  end
end
