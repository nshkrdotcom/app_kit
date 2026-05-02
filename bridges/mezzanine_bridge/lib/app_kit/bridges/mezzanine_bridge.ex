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
  @behaviour AppKit.Core.Backends.HeadlessBackend
  @behaviour AppKit.Core.Backends.AgentIntakeBackend

  @authorization_reasons [
    :cross_tenant_operator_command_denied,
    :operator_actor_tenant_mismatch,
    :unauthorized_lower_read
  ]
  alias AppKit.Core.AgentIntake.RunOutcomeFuture

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
    EvidenceProjection,
    ExecutionRef,
    ExecutionStateProjection,
    FilterSet,
    InstallationBinding,
    InstallationRef,
    InstallResult,
    InstallTemplate,
    LowerReceiptSummary,
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
    OperatorCommandProjection,
    OperatorProjection,
    PageRequest,
    PageResult,
    PendingObligation,
    ProjectionRef,
    ReadLease,
    RequestContext,
    Result,
    ReviewProjection,
    RunRef,
    RunRequest,
    RuntimeEventSummary,
    RuntimeFactsProjection,
    SourceBindingProjection,
    StreamAttachLease,
    SubjectDetail,
    SubjectRef,
    SubjectRuntimeProjection,
    SubjectSummary,
    SurfaceError,
    Telemetry,
    TimelineEvent,
    UnifiedTrace,
    UnifiedTraceStep,
    WorkspaceRef
  }

  alias AppKit.Core.RuntimeReadback.{
    CommandResult,
    RuntimeEventRow,
    RuntimeRow,
    RuntimeRunDetail,
    RuntimeStateSnapshot,
    RuntimeSubjectDetail
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
           get_subject_projection(work_query_service(opts), tenant_id, subject_id, opts) do
      {:ok, projection}
    else
      {:error, :archived, manifest_ref} -> normalize_surface_error({:archived, manifest_ref})
      {:error, reason} -> normalize_surface_error(reason)
    end
  end

  @impl true
  def get_runtime_projection(%RequestContext{} = context, %SubjectRef{} = subject_ref, opts)
      when is_list(opts) do
    runtime_opts = Keyword.put(opts, :runtime_projection?, true)

    with :ok <- ensure_subject_not_archived(context, subject_ref),
         {:ok, tenant_id} <- tenant_id(context),
         {:ok, projection} <-
           get_subject_projection(
             work_query_service(opts),
             tenant_id,
             subject_ref.id,
             runtime_opts
           ),
         :ok <- ensure_runtime_projection_row(projection),
         {:ok, runtime_projection} <-
           subject_runtime_projection_from_map(projection, context, subject_ref) do
      {:ok, runtime_projection}
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

  defp get_subject_projection(service, tenant_id, subject_id, opts) do
    if function_exported?(service, :get_subject_projection, 3) do
      service.get_subject_projection(tenant_id, subject_id, opts)
    else
      service.get_subject_projection(tenant_id, subject_id)
    end
  end

  defp ensure_runtime_projection_row(projection) when is_map(projection) do
    if runtime_projection_row?(projection) do
      :ok
    else
      {:error, :runtime_projection_not_found}
    end
  end

  defp ensure_runtime_projection_row(_projection), do: {:error, :invalid_runtime_projection}

  defp runtime_projection_row?(projection) do
    fetch_value(projection, :projection_name) == "operator_subject_runtime" and
      not is_nil(fetch_value(projection, :computed_at) || fetch_value(projection, :updated_at)) and
      is_map(fetch_value(projection, :execution)) and
      is_map(fetch_value(projection, :lower_receipt)) and
      runtime_source_binding_rows(projection) != []
  end

  defp subject_runtime_projection_from_map(
         projection,
         %RequestContext{} = context,
         %SubjectRef{} = requested_subject_ref
       )
       when is_map(projection) do
    subject = fetch_value(projection, :subject) || %{}
    lifecycle_state = runtime_lifecycle_state(projection, subject)

    with {:ok, subject_ref} <-
           runtime_subject_ref(projection, subject, requested_subject_ref, context),
         {:ok, source_bindings} <- source_binding_projections(projection),
         {:ok, workspace_ref} <- runtime_workspace_ref(projection, context),
         {:ok, execution_state} <-
           execution_state_projection(projection, subject_ref, lifecycle_state),
         {:ok, lower_receipts} <- lower_receipt_summaries(projection, execution_state),
         {:ok, runtime} <- runtime_facts_projection(projection),
         {:ok, evidence} <- evidence_projections(projection),
         {:ok, review} <- review_projection(projection, subject_ref),
         {:ok, operator_commands} <- operator_command_projections(projection) do
      SubjectRuntimeProjection.new(%{
        subject_ref: subject_ref,
        lifecycle_state: lifecycle_state,
        source_bindings: source_bindings,
        workspace_ref: workspace_ref,
        execution_state: execution_state,
        lower_receipts: lower_receipts,
        runtime: runtime,
        evidence: evidence,
        review: review,
        operator_commands: operator_commands,
        updated_at:
          coerce_datetime(
            fetch_value(projection, :computed_at) || fetch_value(projection, :updated_at)
          ),
        schema_ref: "app_kit/subject_runtime_projection",
        schema_version: 1,
        payload: runtime_projection_payload(projection)
      })
    end
  end

  defp subject_runtime_projection_from_map(_projection, _context, _subject_ref),
    do: {:error, :invalid_runtime_projection}

  defp runtime_lifecycle_state(projection, subject) do
    normalize_string(
      fetch_value(projection, :lifecycle_state) ||
        fetch_value(projection, :work_status) ||
        fetch_value(subject, :lifecycle_state) ||
        fetch_value(subject, :status) ||
        "unknown"
    )
  end

  defp runtime_subject_ref(
         projection,
         subject,
         requested_subject_ref,
         %RequestContext{} = context
       ) do
    subject_id =
      fetch_value(projection, :subject_id) ||
        fetch_value(subject, :subject_id) ||
        fetch_value(subject, :id) ||
        requested_subject_ref.id

    subject_kind =
      normalize_string(
        fetch_value(projection, :subject_kind) ||
          fetch_value(subject, :subject_kind) ||
          requested_subject_ref.subject_kind ||
          "subject"
      )

    SubjectRef.new(%{
      id: subject_id,
      subject_kind: subject_kind,
      installation_ref: requested_subject_ref.installation_ref || context.installation_ref
    })
  end

  defp source_binding_projections(projection) do
    projection
    |> runtime_source_binding_rows()
    |> map_each(&source_binding_projection/1)
  end

  defp runtime_source_binding_rows(projection) do
    cond do
      is_list(fetch_value(projection, :source_bindings)) ->
        fetch_value(projection, :source_bindings)

      is_map(fetch_value(projection, :source_binding)) ->
        [fetch_value(projection, :source_binding)]

      true ->
        []
    end
  end

  defp source_binding_projection(row) when is_map(row) do
    SourceBindingProjection.new(%{
      binding_ref: fetch_value(row, :binding_ref) || fetch_value(row, :source_binding_ref),
      source_ref: fetch_value(row, :source_ref),
      source_kind:
        normalize_string(fetch_value(row, :source_kind) || fetch_value(row, :kind) || "source"),
      external_system: fetch_value(row, :external_system),
      source_state: normalize_string(fetch_value(row, :source_state) || fetch_value(row, :state)),
      source_url: fetch_value(row, :source_url) || fetch_value(row, :url),
      workpad_refs: fetch_value(row, :workpad_refs) || [],
      metadata: fetch_value(row, :metadata) || %{}
    })
  end

  defp source_binding_projection(_row), do: {:error, :invalid_source_binding_projection}

  defp runtime_workspace_ref(projection, %RequestContext{} = context) do
    case fetch_value(projection, :workspace_ref) || fetch_value(projection, :workspace) do
      nil ->
        {:ok, nil}

      row when is_map(row) ->
        WorkspaceRef.new(%{
          id: fetch_value(row, :id) || fetch_value(row, :workspace_id),
          tenant_id: fetch_value(row, :tenant_id) || context.tenant_ref.id,
          revision: fetch_value(row, :revision),
          display_label: fetch_value(row, :display_label) || fetch_value(row, :label)
        })

      _row ->
        {:error, :invalid_workspace_ref}
    end
  end

  defp execution_state_projection(projection, %SubjectRef{} = subject_ref, lifecycle_state) do
    case fetch_value(projection, :execution) do
      row when is_map(row) ->
        runtime_execution_state(row, subject_ref, lifecycle_state)

      _row ->
        {:ok, nil}
    end
  end

  defp runtime_execution_state(row, %SubjectRef{} = subject_ref, lifecycle_state) do
    execution_id = fetch_value(row, :execution_id) || fetch_value(row, :id)
    dispatch_state = normalize_string(fetch_value(row, :dispatch_state) || "unknown")

    with {:ok, execution_ref} <-
           ExecutionRef.new(%{
             id: execution_id,
             subject_ref: subject_ref,
             dispatch_state: dispatch_state
           }) do
      ExecutionStateProjection.new(%{
        execution_ref: execution_ref,
        lifecycle_state: lifecycle_state,
        dispatch_state: dispatch_state,
        failure_kind: normalize_string(fetch_value(row, :failure_kind)),
        updated_at: coerce_datetime(fetch_value(row, :updated_at)),
        metadata: fetch_value(row, :metadata) || %{}
      })
    end
  end

  defp lower_receipt_summaries(projection, execution_state) do
    projection
    |> lower_receipt_rows()
    |> map_each(&lower_receipt_summary(&1, execution_state))
  end

  defp lower_receipt_rows(projection) do
    cond do
      is_list(fetch_value(projection, :lower_receipts)) ->
        fetch_value(projection, :lower_receipts)

      is_map(fetch_value(projection, :lower_receipt)) ->
        [fetch_value(projection, :lower_receipt)]

      true ->
        []
    end
  end

  defp lower_receipt_summary(row, execution_state) when is_map(row) do
    LowerReceiptSummary.new(%{
      receipt_ref: fetch_value(row, :receipt_ref) || fetch_value(row, :receipt_id),
      receipt_state:
        normalize_string(fetch_value(row, :receipt_state) || fetch_value(row, :state)),
      lower_receipt_ref: fetch_value(row, :lower_receipt_ref),
      run_ref:
        runtime_lower_ref("lower-run", fetch_value(row, :run_ref) || fetch_value(row, :run_id)),
      attempt_ref:
        runtime_lower_ref(
          "lower-attempt",
          fetch_value(row, :attempt_ref) || fetch_value(row, :attempt_id)
        ),
      execution_ref: execution_state && execution_state.execution_ref,
      metadata: fetch_value(row, :metadata) || %{}
    })
  end

  defp lower_receipt_summary(_row, _execution_state), do: {:error, :invalid_lower_receipt_summary}

  defp runtime_lower_ref(_prefix, nil), do: nil

  defp runtime_lower_ref(prefix, value) when is_binary(value) do
    if String.contains?(value, "://"), do: value, else: "#{prefix}://#{value}"
  end

  defp runtime_lower_ref(_prefix, _value), do: nil

  defp runtime_facts_projection(projection) do
    runtime = fetch_value(projection, :runtime) || %{}

    with {:ok, events} <- runtime_event_summaries(fetch_value(runtime, :event_counts) || %{}) do
      RuntimeFactsProjection.new(%{
        token_totals: fetch_value(runtime, :token_totals) || %{},
        rate_limit: fetch_value(runtime, :rate_limit) || %{},
        events: events,
        metadata: fetch_value(runtime, :metadata) || %{}
      })
    end
  end

  defp runtime_event_summaries(event_counts) when is_map(event_counts) do
    event_counts
    |> Enum.sort_by(fn {event_kind, _count} -> normalize_string(event_kind) end)
    |> Enum.map(fn {event_kind, count} ->
      RuntimeEventSummary.new(%{
        event_kind: normalize_string(event_kind),
        count: count
      })
    end)
    |> collect()
  end

  defp runtime_event_summaries(_event_counts), do: {:error, :invalid_runtime_event_summary}

  defp evidence_projections(projection) do
    projection
    |> evidence_projection_rows()
    |> map_each(&evidence_projection/1)
  end

  defp evidence_projection_rows(projection) do
    evidence = fetch_value(projection, :evidence)

    cond do
      is_list(fetch_value(evidence, :evidence_refs)) -> fetch_value(evidence, :evidence_refs)
      is_list(evidence) -> evidence
      true -> []
    end
  end

  defp evidence_projection(row) when is_map(row) do
    EvidenceProjection.new(%{
      evidence_ref: fetch_value(row, :evidence_ref) || fetch_value(row, :evidence_id),
      evidence_kind:
        normalize_string(fetch_value(row, :evidence_kind) || fetch_value(row, :kind)),
      content_ref: fetch_value(row, :content_ref),
      status: normalize_string(fetch_value(row, :status) || "present"),
      metadata: fetch_value(row, :metadata) || %{}
    })
  end

  defp evidence_projection(_row), do: {:error, :invalid_evidence_projection}

  defp review_projection(projection, %SubjectRef{} = subject_ref) do
    review = fetch_value(projection, :review) || %{}
    pending_decision_ids = fetch_value(review, :pending_decision_ids) || []
    status = normalize_string(fetch_value(review, :status) || review_status(pending_decision_ids))

    pending_decision_ids
    |> Enum.map(fn decision_id ->
      DecisionRef.new(%{
        id: decision_id,
        decision_kind: "operator_review",
        subject_ref: subject_ref
      })
    end)
    |> collect()
    |> case do
      {:ok, pending_decision_refs} ->
        ReviewProjection.new(%{
          status: status,
          pending_decision_refs: pending_decision_refs,
          metadata: fetch_value(review, :metadata) || %{}
        })

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp review_status([_ | _]), do: "pending"
  defp review_status(_pending_decision_ids), do: "none"

  defp operator_command_projections(projection) do
    projection
    |> operator_command_rows()
    |> map_each(&operator_command_projection/1)
  end

  defp operator_command_rows(projection), do: fetch_value(projection, :available_actions) || []

  defp operator_command_projection(row) when is_map(row) do
    raw_action_ref = fetch_value(row, :action_ref) || row

    with {:ok, action_ref} <- operator_action_ref_from_map(raw_action_ref) do
      OperatorCommandProjection.new(%{
        command_ref: action_ref,
        status: normalize_string(fetch_value(row, :status) || "available"),
        enabled?: fetch_value(row, :enabled?) != false,
        reason: fetch_value(row, :reason),
        metadata: fetch_value(row, :metadata) || %{}
      })
    end
  end

  defp operator_command_projection(_row), do: {:error, :invalid_operator_command_projection}

  defp runtime_projection_payload(projection) do
    projection
    |> Map.new()
    |> Map.drop([
      :source_bindings,
      "source_bindings",
      :source_binding,
      "source_binding",
      :workspace,
      "workspace",
      :workspace_ref,
      "workspace_ref",
      :execution,
      "execution",
      :lower_receipt,
      "lower_receipt",
      :lower_receipts,
      "lower_receipts",
      :runtime,
      "runtime",
      :evidence,
      "evidence",
      :review,
      "review",
      :available_actions,
      "available_actions"
    ])
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

  defp run_request_action_params(%RunRequest{} = run_request) do
    run_request.params
    |> Map.new()
    |> maybe_put("recipe_ref", run_request.recipe_ref)
    |> maybe_put("reason", run_request.reason)
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

  defp memory_control_service(opts),
    do: Keyword.get(opts, :memory_control_service, Mezzanine.AppKitBridge.MemoryControlService)

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

  @impl AppKit.Core.Backends.HeadlessBackend
  def state_snapshot(%RequestContext{} = context, request, opts) when is_list(opts) do
    now = DateTime.utc_now()

    with {:ok, tenant_ref} <- tenant_id(context),
         {:ok, program_id} <- program_id(context, opts),
         installation_ref <- readback_installation_ref(context),
         {:ok, rows} <- work_query_service(opts).list_subjects(tenant_ref, program_id, %{}),
         {:ok, runtime_rows} <- map_each(rows, &runtime_row_from_map(&1, now)) do
      RuntimeStateSnapshot.new(%{
        tenant_ref: tenant_ref,
        installation_ref: installation_ref,
        generated_at: now,
        rows: runtime_rows,
        polling_state: %{
          checking?: false,
          poll_interval_ms: fetch_readback_page_size(request, 5_000),
          staleness_ms: 0
        },
        page: %{
          page_size: fetch_readback_page_size(request, 25),
          cursor: fetch_value(request || %{}, :cursor),
          total_entries: length(runtime_rows)
        }
      })
    else
      {:error, reason} -> normalize_surface_error(reason)
    end
  end

  @impl AppKit.Core.Backends.HeadlessBackend
  def runtime_subject_detail(%RequestContext{} = context, subject_ref, _request, opts)
      when is_list(opts) do
    subject_id = readback_ref_id(subject_ref)
    now = DateTime.utc_now()

    with {:ok, tenant_ref} <- tenant_id(context),
         {:ok, projection} <-
           get_subject_projection(
             work_query_service(opts),
             tenant_ref,
             subject_id,
             Keyword.put(opts, :runtime_projection?, true)
           ),
         {:ok, runtime_row} <-
           runtime_row_from_map(
             Map.merge(
               %{subject_ref: subject_id, run_ref: "run://#{subject_id}", updated_at: now},
               projection
             ),
             now
           ) do
      RuntimeSubjectDetail.new(%{
        subject_ref: subject_id,
        summary:
          compact_map(%{
            title: fetch_value(projection, :title),
            state: fetch_value(projection, :state),
            projection_ref: fetch_value(projection, :projection_ref)
          }),
        runtime_row: runtime_row,
        events: readback_events(projection, now)
      })
    else
      {:error, reason} -> normalize_surface_error(reason)
    end
  end

  @impl AppKit.Core.Backends.HeadlessBackend
  def runtime_run_detail(%RequestContext{} = _context, run_ref, request, opts) do
    now = DateTime.utc_now()
    run_id = readback_ref_id(run_ref)

    case agent_loop_projection(request, opts) do
      nil ->
        default_runtime_run_detail(run_id, request, now)

      projection ->
        runtime_run_detail_from_agent_loop_projection(projection, now)
    end
  end

  @impl AppKit.Core.Backends.HeadlessBackend
  def request_runtime_refresh(%RequestContext{} = _context, request, _opts) do
    CommandResult.new(%{
      command_ref: "command://#{request.idempotency_key}",
      command_kind: :refresh,
      accepted?: true,
      coalesced?: false,
      status: :accepted,
      authority_state: :local_policy,
      authority_refs: [],
      workflow_effect_state: "pending_signal",
      projection_state: :pending,
      idempotency_key: request.idempotency_key,
      message: "Refresh command accepted with database_first acknowledgement"
    })
  end

  @impl AppKit.Core.Backends.HeadlessBackend
  def request_runtime_control(%RequestContext{} = _context, request, _opts) do
    command_kind = request.action

    workflow_effect_state =
      if to_string(command_kind) == "inspect_memory_proof",
        do: "not_available",
        else: "pending_signal"

    diagnostics =
      if to_string(command_kind) == "inspect_memory_proof" do
        [
          %{
            severity: :info,
            code: "memory_proof_not_available",
            message: "Memory proof readback is not available until Phase 7"
          }
        ]
      else
        []
      end

    CommandResult.new(%{
      command_ref: "command://#{request.idempotency_key}",
      command_kind: command_kind,
      accepted?: true,
      coalesced?: false,
      status: :accepted,
      authority_state: :local_policy,
      authority_refs: [],
      workflow_effect_state: workflow_effect_state,
      projection_state: :pending,
      idempotency_key: request.idempotency_key,
      message: "Control command accepted with database_first acknowledgement",
      diagnostics: diagnostics
    })
  end

  @impl AppKit.Core.Backends.AgentIntakeBackend
  def start_agent_run(%RequestContext{} = context, request, opts) do
    runtime = agent_runtime(opts)

    with {:ok, spec_attrs} <- agent_run_spec_attrs(context, request),
         true <- runtime_available?(runtime),
         {:ok, projection} <- runtime.run(spec_attrs) do
      RunOutcomeFuture.new(%{
        run_ref: fetch_value(projection, :run_ref),
        workflow_ref: fetch_value(projection, :workflow_ref),
        accepted?: true,
        command_ref: "command://#{request.idempotency_key}",
        correlation_id: request.correlation_id,
        polling_hint: %{checking?: false, poll_interval_ms: 1_000, staleness_ms: 0}
      })
    else
      false -> {:error, :agent_turn_runtime_not_available}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl AppKit.Core.Backends.AgentIntakeBackend
  def submit_agent_turn(%RequestContext{}, turn_submission, opts) do
    if runtime_available?(agent_runtime(opts)) do
      CommandResult.new(%{
        command_ref: "command://#{turn_submission.idempotency_key}",
        command_kind: :submit_turn,
        accepted?: true,
        coalesced?: false,
        status: :accepted,
        authority_state: :local_policy,
        authority_refs: [],
        workflow_effect_state: "pending_signal",
        projection_state: :pending,
        trace_id: nil,
        correlation_id: turn_submission.run_ref,
        idempotency_key: turn_submission.idempotency_key,
        message: "Agent turn submission accepted through AppKit"
      })
    else
      {:error, :agent_turn_runtime_not_available}
    end
  end

  @impl AppKit.Core.Backends.AgentIntakeBackend
  def cancel_agent_run(%RequestContext{}, run_ref, opts) do
    if runtime_available?(agent_runtime(opts)) do
      run_id = readback_ref_id(run_ref)

      CommandResult.new(%{
        command_ref: "command://cancel/#{run_id}",
        command_kind: :cancel,
        accepted?: true,
        coalesced?: false,
        status: :accepted,
        authority_state: :local_policy,
        authority_refs: [],
        workflow_effect_state: "pending_signal",
        projection_state: :pending,
        correlation_id: run_id,
        idempotency_key: "agent-run:cancel:#{run_id}",
        message: "Agent run cancellation accepted through AppKit"
      })
    else
      {:error, :agent_turn_runtime_not_available}
    end
  end

  @impl AppKit.Core.Backends.AgentIntakeBackend
  def await_agent_outcome(%RequestContext{}, run_ref, request, opts) do
    if runtime_available?(agent_runtime(opts)) do
      run_id = readback_ref_id(run_ref)

      RunOutcomeFuture.new(%{
        run_ref: run_id,
        workflow_ref: fetch_value(request || %{}, :workflow_ref),
        accepted?: true,
        command_ref: "command://await/#{run_id}",
        correlation_id: fetch_value(request || %{}, :correlation_id) || run_id,
        polling_hint: %{checking?: false, poll_interval_ms: 1_000, staleness_ms: 0}
      })
    else
      {:error, :agent_turn_runtime_not_available}
    end
  end

  defp agent_run_spec_attrs(%RequestContext{} = context, request) do
    params = request.params || %{}
    profile_bundle = request.profile_bundle

    run_ref =
      param(params, :run_ref, "run://agent-loop/#{ref_suffix(request.submission_dedupe_key)}")

    {:ok,
     %{
       tenant_ref: request.tenant_ref,
       installation_ref: request.installation_ref,
       profile_ref: param(params, :profile_ref, "profile://app-kit/agent-loop"),
       subject_ref: request.subject_ref,
       run_ref: run_ref,
       session_ref: param(params, :session_ref, "session://agent-loop/#{ref_suffix(run_ref)}"),
       workspace_ref:
         param(params, :workspace_ref, "workspace://agent-loop/#{ref_suffix(run_ref)}"),
       worker_ref:
         param(params, :worker_ref, "worker://agent-loop/#{ref_suffix(run_ref)}/fixture"),
       trace_id: request.trace_id,
       idempotency_key: request.idempotency_key,
       objective: request.initial_input_ref,
       runtime_profile_ref: profile_bundle.runtime_profile_ref,
       tool_catalog_ref: request.tool_catalog_ref,
       authority_context_ref:
         param(
           params,
           :authority_context_ref,
           "authority-context://agent-loop/#{ref_suffix(run_ref)}"
         ),
       memory_profile_ref: profile_bundle.memory_profile_ref,
       artifact_policy_ref:
         param(params, :artifact_policy_ref, "artifact-policy://app-kit/agent-loop"),
       max_turns: param(params, :max_turns, 1),
       timeout_policy: timeout_policy(params),
       profile_bundle: Map.from_struct(profile_bundle),
       fixture_script: param(params, :fixture_script, "success_first_try"),
       continue_as_new_turn_threshold: param(params, :continue_as_new_turn_threshold, 50),
       source_ref: "actor://#{context.actor_ref.id}"
     }}
  end

  defp agent_loop_projection(request, opts),
    do:
      Keyword.get(opts, :agent_loop_projection) ||
        fetch_value(request || %{}, :agent_loop_projection)

  defp default_runtime_run_detail(run_id, request, now) do
    request = request || %{}
    subject_id = fetch_value(request, :subject_ref) || "subject://unknown"

    with {:ok, runtime_row} <-
           RuntimeRow.new(%{
             subject_ref: subject_id,
             run_ref: run_id,
             state: fetch_value(request, :state) || "unknown",
             updated_at: now,
             polling_state: %{checking?: false, poll_interval_ms: 5_000, staleness_ms: 0}
           }) do
      RuntimeRunDetail.new(%{
        run_ref: run_id,
        runtime_row: runtime_row,
        events: readback_events(request, now),
        turns: [],
        budget_state: nil,
        candidate_fact_refs: [],
        memory_proof_refs: [],
        agent_loop_diagnostics: []
      })
    end
  end

  defp timeout_policy(params),
    do:
      param(params, :timeout_policy, %{turn_timeout_ms: param(params, :turn_timeout_ms, 30_000)})

  defp param(params, key, default) do
    case fetch_value(params, key) do
      nil -> default
      value -> value
    end
  end

  defp runtime_run_detail_from_agent_loop_projection(projection, now) do
    with {:ok, runtime_row} <-
           RuntimeRow.new(%{
             subject_ref: fetch_value(projection, :subject_ref),
             run_ref: fetch_value(projection, :run_ref),
             workflow_ref: fetch_value(projection, :workflow_ref),
             state: fetch_value(projection, :status),
             updated_at: now,
             polling_state: %{checking?: false, poll_interval_ms: 1_000, staleness_ms: 0}
           }),
         {:ok, events} <-
           map_each(fetch_value(projection, :runtime_events) || [], fn event ->
             event |> public_readback_map() |> RuntimeEventRow.new()
           end) do
      RuntimeRunDetail.new(%{
        run_ref: fetch_value(projection, :run_ref),
        runtime_row: runtime_row,
        events: events,
        turns: Enum.map(fetch_value(projection, :turn_states) || [], &public_readback_map/1),
        budget_state: fetch_value(projection, :budget_state),
        candidate_fact_refs: fetch_value(projection, :candidate_fact_refs) || [],
        memory_proof_refs: fetch_value(projection, :memory_proof_refs) || [],
        agent_loop_diagnostics: [],
        diagnostics: action_receipt_diagnostics(projection)
      })
    end
  end

  defp action_receipt_diagnostics(projection) do
    (fetch_value(projection, :action_receipts) || [])
    |> Enum.reject(&(fetch_value(&1, :status) in [:succeeded, "succeeded"]))
    |> Enum.map(fn receipt ->
      status = fetch_value(receipt, :status)

      %{
        severity: :info,
        code: "agent_loop_action_#{status}",
        message: "Agent loop action receipt recorded as #{status}"
      }
    end)
  end

  defp runtime_available?(runtime) when is_atom(runtime),
    do: Code.ensure_loaded?(runtime) and function_exported?(runtime, :run, 1)

  defp runtime_available?(_runtime), do: false

  defp agent_runtime(opts),
    do:
      Keyword.get(opts, :agent_loop_runtime) || Application.get_env(:app_kit_core, :agent_runtime)

  defp public_readback_map(%DateTime{} = value), do: value

  defp public_readback_map(%_{} = value) do
    value
    |> Map.from_struct()
    |> public_readback_map()
  end

  defp public_readback_map(%{} = value) do
    Map.new(value, fn {key, val} -> {key, public_readback_map(val)} end)
  end

  defp public_readback_map(values) when is_list(values),
    do: Enum.map(values, &public_readback_map/1)

  defp public_readback_map(value), do: value

  defp ref_suffix(ref) when is_binary(ref) do
    ref
    |> String.replace(~r/[^A-Za-z0-9]+/, "-")
    |> String.trim("-")
  end

  defp ref_suffix(ref), do: ref |> to_string() |> ref_suffix()

  defp runtime_row_from_map(row, now) do
    RuntimeRow.new(readback_row_attrs(row, now))
  end

  defp readback_row_attrs(row, now) do
    subject_ref = subject_ref_for_row(row)

    %{
      subject_ref: subject_ref,
      run_ref: run_ref_for_row(row, subject_ref),
      execution_ref:
        normalize_optional_readback_ref(
          first_value(row, [:execution_ref, :execution_id]),
          "execution"
        ),
      workflow_ref: normalize_optional_readback_ref(fetch_value(row, :workflow_ref), "workflow"),
      state: first_value(row, [:state, :status]) || "unknown",
      status_reason: fetch_value(row, :status_reason),
      updated_at: fetch_value(row, :updated_at) || now,
      session_ref: readback_session_ref(row),
      workspace_ref: readback_workspace_ref(row),
      polling_state: %{checking?: false, poll_interval_ms: 5_000, staleness_ms: 0},
      provider_refs: fetch_value(row, :provider_refs) || %{},
      extensions: fetch_value(row, :extensions) || %{}
    }
  end

  defp readback_events(source, now) do
    source
    |> event_values()
    |> Enum.with_index()
    |> Enum.flat_map(&readback_event_row(&1, now))
  end

  defp readback_event_row({event, index}, now) do
    case RuntimeEventRow.new(readback_event_attrs(event, index, now)) do
      {:ok, event_row} -> [event_row]
      {:error, _reason} -> []
    end
  end

  defp readback_event_attrs(event, index, now) do
    %{
      event_ref:
        normalize_readback_ref(fetch_value(event, :event_ref) || "event-#{index}", "event"),
      event_seq: fetch_value(event, :event_seq) || index,
      event_kind: first_value(event, [:event_kind, :kind]) || "unknown",
      observed_at: fetch_value(event, :observed_at) || now,
      subject_ref: normalize_optional_readback_ref(fetch_value(event, :subject_ref), "subject"),
      run_ref: normalize_optional_readback_ref(fetch_value(event, :run_ref), "run"),
      level: fetch_value(event, :level) || :info,
      message_summary: first_value(event, [:message_summary, :summary]),
      payload_ref: normalize_optional_readback_ref(fetch_value(event, :payload_ref), "payload"),
      extensions: fetch_value(event, :extensions) || %{}
    }
  end

  defp event_values(source) do
    case fetch_value(source, :events) do
      events when is_list(events) -> events
      _other -> []
    end
  end

  defp subject_ref_for_row(row),
    do: row |> first_value([:subject_ref, :subject_id, :id]) |> normalize_readback_ref("subject")

  defp run_ref_for_row(row, subject_ref) do
    row
    |> first_value([:run_ref, :run_id])
    |> case do
      nil -> subject_ref
      value -> value
    end
    |> normalize_readback_ref("run")
  end

  defp first_value(source, keys), do: Enum.find_value(keys, &fetch_value(source, &1))

  defp readback_session_ref(row) do
    case fetch_value(row, :session_ref) || fetch_value(row, :session_id) do
      nil -> nil
      value -> %{id: normalize_readback_ref(value, "session")}
    end
  end

  defp readback_workspace_ref(row) do
    case fetch_value(row, :workspace_ref) || fetch_value(row, :workspace_id) do
      nil ->
        nil

      value ->
        %{
          id: normalize_readback_ref(value, "workspace"),
          display_label: fetch_value(row, :workspace_label),
          path_redacted?: true
        }
    end
  end

  defp readback_installation_ref(context) do
    context
    |> fetch_value(:installation_ref)
    |> readback_ref_id()
    |> case do
      nil -> "installation://unknown"
      value -> normalize_readback_ref(value, "installation")
    end
  end

  defp readback_ref_id(%{id: id}), do: id
  defp readback_ref_id(value) when is_binary(value), do: value
  defp readback_ref_id(value) when is_atom(value), do: Atom.to_string(value)
  defp readback_ref_id(nil), do: nil
  defp readback_ref_id(value), do: to_string(value)

  defp normalize_optional_readback_ref(nil, _scheme), do: nil
  defp normalize_optional_readback_ref(value, scheme), do: normalize_readback_ref(value, scheme)

  defp normalize_readback_ref(value, scheme) do
    value = readback_ref_id(value) || "unknown"

    if String.contains?(value, "://"), do: value, else: "#{scheme}://#{value}"
  end

  defp fetch_readback_page_size(request, default) do
    case fetch_value(request || %{}, :page_size) do
      value when is_integer(value) and value > 0 -> value
      _other -> default
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
  @validation_reasons [:stale_proof_token]
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
