defmodule AppKit.Bridges.MezzanineBridge do
  @moduledoc """
  Internal AppKit backend adapter over lower-backed Mezzanine service modules.

  The bridge owns translation from lower service-shaped maps into the stable
  `AppKit.Core.*` contract so product-facing surfaces do not inherit lower
  structs or lower package topology.
  """

  alias AppKit.Bridges.MezzanineBridge.{
    AgentIntakeAdapter,
    HeadlessAdapter,
    InstallationAdapter,
    ReviewAdapter,
    RuntimeAdapter,
    SourceAdapter,
    WorkAdapter,
    WorkQueryAdapter
  }

  @behaviour AppKit.Core.Backends.InstallationBackend
  @behaviour AppKit.Core.Backends.OperatorBackend
  @behaviour AppKit.Core.Backends.ReviewBackend
  @behaviour AppKit.Core.Backends.SourceBackend
  @behaviour AppKit.Core.Backends.WorkBackend
  @behaviour AppKit.Core.Backends.WorkQueryBackend
  @behaviour AppKit.Core.Backends.HeadlessBackend
  @behaviour AppKit.Core.Backends.AgentIntakeBackend
  @behaviour AppKit.Core.Backends.RuntimeBackend

  @authorization_reasons [
    :cross_tenant_operator_command_denied,
    :operator_actor_tenant_mismatch,
    :unauthorized_lower_read
  ]
  alias AppKit.Core.{
    ActionResult,
    ActorRef,
    AuthoringBundleImport,
    BlockingCondition,
    DecisionRef,
    ExecutionRef,
    FilterSet,
    InstallationRef,
    InstallTemplate,
    MemoryFragmentListRequest,
    MemoryFragmentProjection,
    MemoryFragmentProvenance,
    MemoryInvalidationRequest,
    MemoryPromotionRequest,
    MemoryProofTokenLookup,
    MemoryShareUpRequest,
    NextStepPreview,
    OperatorAction,
    OperatorActionRef,
    OperatorActionRequest,
    OperatorProjection,
    PageRequest,
    PendingObligation,
    ProjectionRef,
    ReadLease,
    RequestContext,
    RunRef,
    RunRequest,
    StreamAttachLease,
    SubjectRef,
    SurfaceError,
    Telemetry,
    TimelineEvent,
    UnifiedTrace,
    UnifiedTraceStep
  }

  alias Mezzanine.Archival.Query, as: ArchivalQuery

  @impl true
  def sync_source(%RequestContext{} = context, source_role_ref, source_page, opts)
      when (is_atom(source_role_ref) or is_binary(source_role_ref)) and is_map(source_page) and
             is_list(opts) do
    SourceAdapter.sync_source(
      context,
      source_role_ref,
      source_page,
      opts
    )
  end

  @impl true
  def current_states(%RequestContext{} = context, source_role_ref, request, opts)
      when (is_atom(source_role_ref) or is_binary(source_role_ref)) and is_map(request) and
             is_list(opts) do
    SourceAdapter.current_states(
      context,
      source_role_ref,
      request,
      opts
    )
  end

  @impl true
  def fetch_candidates(%RequestContext{} = context, source_role_ref, request, opts)
      when (is_atom(source_role_ref) or is_binary(source_role_ref)) and is_map(request) and
             is_list(opts) do
    SourceAdapter.fetch_candidates(
      context,
      source_role_ref,
      request,
      opts
    )
  end

  @impl true
  def publish_source(%RequestContext{} = context, publication_role_ref, request, opts)
      when (is_atom(publication_role_ref) or is_binary(publication_role_ref)) and
             is_map(request) and is_list(opts) do
    SourceAdapter.publish_source(
      context,
      publication_role_ref,
      request,
      opts
    )
  end

  def invoke_runtime_operation(
        %RequestContext{} = context,
        runtime_role_ref,
        operation_role_ref,
        request,
        opts
      )
      when (is_atom(runtime_role_ref) or is_binary(runtime_role_ref)) and
             (is_atom(operation_role_ref) or is_binary(operation_role_ref)) and is_map(request) and
             is_list(opts) do
    RuntimeAdapter.invoke_runtime_operation(
      context,
      runtime_role_ref,
      operation_role_ref,
      request,
      opts
    )
  end

  def invoke_runtime_tool(
        %RequestContext{} = context,
        tool_role_ref,
        operation_role_ref,
        request,
        opts
      )
      when (is_atom(tool_role_ref) or is_binary(tool_role_ref)) and
             (is_atom(operation_role_ref) or is_binary(operation_role_ref)) and is_map(request) and
             is_list(opts) do
    RuntimeAdapter.invoke_runtime_tool(context, tool_role_ref, operation_role_ref, request, opts)
  end

  @impl true
  def apply_runtime_profile(%RequestContext{} = context, runtime_profile, opts)
      when is_map(runtime_profile) and is_list(opts) do
    RuntimeAdapter.apply_runtime_profile(context, runtime_profile, opts)
  end

  @impl true
  def runtime_status(%RequestContext{} = context, request, opts)
      when is_map(request) and is_list(opts) do
    RuntimeAdapter.runtime_status(context, request, opts)
  end

  @impl true
  def runtime_logs(%RequestContext{} = context, request, opts)
      when is_map(request) and is_list(opts) do
    RuntimeAdapter.runtime_logs(context, request, opts)
  end

  @impl true
  def record_live_effect(%RequestContext{} = context, attrs, opts \\ [])
      when is_map(attrs) and is_list(opts) do
    RuntimeAdapter.record_live_effect(context, attrs, opts)
  end

  def collect_evidence(%RequestContext{} = context, evidence_role_ref, request, opts)
      when (is_atom(evidence_role_ref) or is_binary(evidence_role_ref)) and is_map(request) and
             is_list(opts) do
    RuntimeAdapter.collect_evidence(context, evidence_role_ref, request, opts)
  end

  def invoke_resource_effect(%RequestContext{} = context, resource_effect_role_ref, request, opts)
      when (is_atom(resource_effect_role_ref) or is_binary(resource_effect_role_ref)) and
             is_map(request) and is_list(opts) do
    RuntimeAdapter.invoke_resource_effect(context, resource_effect_role_ref, request, opts)
  end

  @impl true
  def ingest_subject(%RequestContext{} = context, attrs, opts)
      when is_map(attrs) and is_list(opts) do
    WorkQueryAdapter.ingest_subject(context, attrs, opts)
  end

  @impl true
  def list_subjects(%RequestContext{} = context, filters, %PageRequest{} = page_request, opts)
      when (is_nil(filters) or is_struct(filters, FilterSet)) and is_list(opts) do
    WorkQueryAdapter.list_subjects(context, filters, page_request, opts)
  end

  @impl true
  def get_subject(%RequestContext{} = context, %SubjectRef{} = subject_ref, opts)
      when is_list(opts) do
    WorkQueryAdapter.get_subject(context, subject_ref, opts)
  end

  @impl true
  def get_projection(%RequestContext{} = context, %ProjectionRef{} = projection_ref, opts)
      when is_list(opts) do
    WorkQueryAdapter.get_projection(context, projection_ref, opts)
  end

  @impl true
  def get_runtime_projection(%RequestContext{} = context, %SubjectRef{} = subject_ref, opts)
      when is_list(opts) do
    WorkQueryAdapter.get_runtime_projection(context, subject_ref, opts)
  end

  @impl true
  def queue_stats(%RequestContext{} = context, filters, opts)
      when (is_nil(filters) or is_struct(filters, FilterSet)) and is_list(opts) do
    WorkQueryAdapter.queue_stats(context, filters, opts)
  end

  @impl true
  def list_pending(%RequestContext{} = context, %PageRequest{} = page_request, opts)
      when is_list(opts) do
    ReviewAdapter.list_pending(context, page_request, opts)
  end

  @impl true
  def get_review(%RequestContext{} = context, %DecisionRef{} = decision_ref, opts)
      when is_list(opts) do
    ReviewAdapter.get_review(context, decision_ref, opts)
  end

  @impl true
  def record_decision(%RequestContext{} = context, %DecisionRef{} = decision_ref, attrs, opts)
      when is_map(attrs) and is_list(opts) do
    ReviewAdapter.record_decision(context, decision_ref, attrs, opts)
  end

  @impl true
  def record_decision_by_id(%RequestContext{} = context, decision_id, attrs, opts)
      when is_binary(decision_id) and is_map(attrs) and is_list(opts) do
    ReviewAdapter.record_decision_by_id(context, decision_id, attrs, opts)
  end

  @impl true
  def create_installation(%RequestContext{} = context, %InstallTemplate{} = template, opts)
      when is_list(opts) do
    InstallationAdapter.create_installation(context, template, opts)
  end

  @impl true
  def import_authoring_bundle(
        %RequestContext{} = context,
        %AuthoringBundleImport{} = bundle_import,
        opts
      )
      when is_list(opts) do
    InstallationAdapter.import_authoring_bundle(context, bundle_import, opts)
  end

  @impl true
  def get_installation(%RequestContext{} = context, %InstallationRef{} = installation_ref, opts)
      when is_list(opts) do
    InstallationAdapter.get_installation(context, installation_ref, opts)
  end

  @impl true
  def update_bindings(
        %RequestContext{} = context,
        %InstallationRef{} = installation_ref,
        bindings,
        opts
      )
      when is_list(bindings) and is_list(opts) do
    InstallationAdapter.update_bindings(context, installation_ref, bindings, opts)
  end

  @impl true
  def list_installations(%RequestContext{} = context, %PageRequest{} = page_request, opts)
      when is_list(opts) do
    InstallationAdapter.list_installations(context, page_request, opts)
  end

  @impl true
  def suspend_installation(
        %RequestContext{} = context,
        %InstallationRef{} = installation_ref,
        opts
      )
      when is_list(opts) do
    InstallationAdapter.suspend_installation(context, installation_ref, opts)
  end

  @impl true
  def reactivate_installation(
        %RequestContext{} = context,
        %InstallationRef{} = installation_ref,
        opts
      )
      when is_list(opts) do
    InstallationAdapter.reactivate_installation(context, installation_ref, opts)
  end

  @impl true
  def start_run(%RequestContext{} = context, %RunRequest{} = run_request, opts)
      when is_list(opts) do
    WorkAdapter.start_run(context, run_request, opts)
  end

  @impl true
  def retry_run(%RequestContext{} = context, %RunRef{} = run_ref, opts) when is_list(opts) do
    WorkAdapter.retry_run(context, run_ref, opts)
  end

  @impl true
  def cancel_run(%RequestContext{} = context, %RunRef{} = run_ref, opts) when is_list(opts) do
    WorkAdapter.cancel_run(context, run_ref, opts)
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
         action_params <- operator_action_params(context, subject_ref, action_request),
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
  def list_memory_fragments(
        %RequestContext{} = context,
        %MemoryFragmentListRequest{} = request,
        opts
      )
      when is_list(opts) do
    with attrs <- memory_request_attrs(context, request),
         {:ok, rows} <- memory_control_service(opts).list_fragments_by_proof_token(attrs, opts),
         {:ok, fragments} <- map_each(rows, &memory_fragment_projection_from_map/1) do
      {:ok, fragments}
    else
      {:error, reason} -> normalize_surface_error(reason)
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
         {:ok, row} <- memory_control_service(opts).lookup_fragment_by_proof_token(attrs, opts),
         {:ok, fragment} <- memory_fragment_projection_from_map(row) do
      {:ok, fragment}
    else
      {:error, reason} -> normalize_surface_error(reason)
    end
  end

  @impl true
  def memory_fragment_provenance(%RequestContext{} = context, fragment_ref, opts)
      when is_binary(fragment_ref) and is_list(opts) do
    with attrs <- Map.put(memory_context_attrs(context), :fragment_ref, fragment_ref),
         {:ok, row} <- memory_control_service(opts).fragment_provenance(attrs, opts),
         {:ok, provenance} <- memory_fragment_provenance_from_map(row) do
      {:ok, provenance}
    else
      {:error, reason} -> normalize_surface_error(reason)
    end
  end

  @impl true
  def request_memory_share_up(
        %RequestContext{} = context,
        %MemoryShareUpRequest{} = request,
        opts
      )
      when is_list(opts) do
    with attrs <- memory_request_attrs(context, request),
         {:ok, bridge_result} <- memory_control_service(opts).request_share_up(attrs, opts),
         {:ok, action_result} <- action_result_from_bridge(bridge_result) do
      {:ok, action_result}
    else
      {:error, reason} -> normalize_surface_error(reason)
    end
  end

  @impl true
  def request_memory_promotion(
        %RequestContext{} = context,
        %MemoryPromotionRequest{} = request,
        opts
      )
      when is_list(opts) do
    with attrs <- memory_request_attrs(context, request),
         {:ok, bridge_result} <- memory_control_service(opts).request_promotion(attrs, opts),
         {:ok, action_result} <- action_result_from_bridge(bridge_result) do
      {:ok, action_result}
    else
      {:error, reason} -> normalize_surface_error(reason)
    end
  end

  @impl true
  def request_memory_invalidation(
        %RequestContext{} = context,
        %MemoryInvalidationRequest{} = request,
        opts
      )
      when is_list(opts) do
    with attrs <- memory_request_attrs(context, request),
         {:ok, bridge_result} <- memory_control_service(opts).request_invalidation(attrs, opts),
         {:ok, action_result} <- action_result_from_bridge(bridge_result) do
      {:ok, action_result}
    else
      {:error, reason} -> normalize_surface_error(reason)
    end
  end

  @impl true
  def start_run(domain_call, opts) when is_map(domain_call) and is_list(opts) do
    WorkAdapter.start_run(domain_call, opts)
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

  defp lease_service(opts),
    do: Keyword.get(opts, :lease_service, Mezzanine.AppKitBridge.LeaseService)

  defp operator_query_service(opts),
    do: Keyword.get(opts, :operator_query_service, Mezzanine.AppKitBridge.OperatorQueryService)

  defp operator_action_service(opts),
    do: Keyword.get(opts, :operator_action_service, Mezzanine.AppKitBridge.OperatorActionService)

  defp memory_control_service(opts),
    do: Keyword.get(opts, :memory_control_service, Mezzanine.AppKitBridge.MemoryControlService)

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
          _ -> {:error, missing_revision_epoch_reason(key)}
        end

      _ ->
        {:error, missing_revision_epoch_reason(key)}
    end
  end

  defp missing_revision_epoch_reason(:installation_revision), do: :missing_installation_revision
  defp missing_revision_epoch_reason(:activation_epoch), do: :missing_activation_epoch
  defp missing_revision_epoch_reason(:lease_epoch), do: :missing_lease_epoch

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

  defp subject_ref_from_any(nil, _context), do: {:ok, nil}

  defp subject_ref_from_any(raw_subject_ref, %RequestContext{} = context)
       when is_map(raw_subject_ref) do
    SubjectRef.new(%{
      id: fetch_value(raw_subject_ref, :id),
      subject_kind: normalize_string(fetch_value(raw_subject_ref, :subject_kind) || "subject"),
      installation_ref: context.installation_ref
    })
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

  @impl AppKit.Core.Backends.HeadlessBackend
  def state_snapshot(%RequestContext{} = context, request, opts) when is_list(opts) do
    HeadlessAdapter.state_snapshot(context, request, opts)
  end

  @impl AppKit.Core.Backends.HeadlessBackend
  def runtime_subject_detail(%RequestContext{} = context, subject_ref, request, opts)
      when is_list(opts) do
    HeadlessAdapter.runtime_subject_detail(context, subject_ref, request, opts)
  end

  @impl AppKit.Core.Backends.HeadlessBackend
  def runtime_run_detail(%RequestContext{} = context, run_ref, request, opts) do
    HeadlessAdapter.runtime_run_detail(context, run_ref, request, opts)
  end

  @impl AppKit.Core.Backends.HeadlessBackend
  def request_runtime_refresh(%RequestContext{} = context, request, opts) do
    HeadlessAdapter.request_runtime_refresh(context, request, opts)
  end

  @impl AppKit.Core.Backends.HeadlessBackend
  def request_runtime_control(%RequestContext{} = context, request, opts) do
    HeadlessAdapter.request_runtime_control(context, request, opts)
  end

  @impl AppKit.Core.Backends.AgentIntakeBackend
  def start_agent_run(%RequestContext{} = context, request, opts) do
    AgentIntakeAdapter.start_agent_run(context, request, opts)
  end

  @impl AppKit.Core.Backends.AgentIntakeBackend
  def submit_agent_turn(%RequestContext{} = context, turn_submission, opts) do
    AgentIntakeAdapter.submit_agent_turn(context, turn_submission, opts)
  end

  @impl AppKit.Core.Backends.AgentIntakeBackend
  def cancel_agent_run(%RequestContext{} = context, run_ref, opts) do
    AgentIntakeAdapter.cancel_agent_run(context, run_ref, opts)
  end

  @impl AppKit.Core.Backends.AgentIntakeBackend
  def await_agent_outcome(%RequestContext{} = context, run_ref, request, opts) do
    AgentIntakeAdapter.await_agent_outcome(context, run_ref, request, opts)
  end

  defp fetch_value(map_or_struct, key) when is_map(map_or_struct) and is_atom(key) do
    map = if is_struct(map_or_struct), do: Map.from_struct(map_or_struct), else: map_or_struct
    Map.get(map, key) || Map.get(map, alternate_key(map, key))
  end

  defp fetch_value(_map_or_struct, _key), do: nil

  defp alternate_key(_map, key) when is_atom(key), do: Atom.to_string(key)

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp compact_map(map) do
    Map.reject(map, fn {_key, value} -> is_nil(value) end)
  end

  @not_found_reasons [:bridge_not_found, :not_found, :pack_registration_not_found]
  @conflict_reasons [:installation_pack_conflict, :review_gate_not_satisfied]
  @transient_reasons [:timeout, :temporarily_unavailable]
  @validation_reasons [:stale_proof_token]
  @validation_reason_prefixes ["missing_", "invalid_", "unsupported_"]

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
  defp surface_error_kind(reason) when reason in @validation_reasons, do: :validation

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
