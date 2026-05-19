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
    OperatorAdapter,
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

  alias AppKit.Core.{
    AuthoringBundleImport,
    DecisionRef,
    ExecutionRef,
    FilterSet,
    InstallationRef,
    InstallTemplate,
    MemoryFragmentListRequest,
    MemoryInvalidationRequest,
    MemoryPromotionRequest,
    MemoryProofTokenLookup,
    MemoryShareUpRequest,
    OperatorActionRequest,
    PageRequest,
    ProjectionRef,
    RequestContext,
    RunRef,
    RunRequest,
    SubjectRef
  }

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
    OperatorAdapter.subject_status(context, subject_ref, opts)
  end

  @impl true
  def timeline(%RequestContext{} = context, %SubjectRef{} = subject_ref, opts)
      when is_list(opts) do
    OperatorAdapter.timeline(context, subject_ref, opts)
  end

  @impl true
  def get_unified_trace(%RequestContext{} = context, %ExecutionRef{} = execution_ref, opts)
      when is_list(opts) do
    OperatorAdapter.get_unified_trace(context, execution_ref, opts)
  end

  @impl true
  def issue_read_lease(%RequestContext{} = context, %ExecutionRef{} = execution_ref, opts)
      when is_list(opts) do
    OperatorAdapter.issue_read_lease(context, execution_ref, opts)
  end

  @impl true
  def issue_stream_attach_lease(
        %RequestContext{} = context,
        %ExecutionRef{} = execution_ref,
        opts
      )
      when is_list(opts) do
    OperatorAdapter.issue_stream_attach_lease(context, execution_ref, opts)
  end

  @impl true
  def available_actions(%RequestContext{} = context, %SubjectRef{} = subject_ref, opts)
      when is_list(opts) do
    OperatorAdapter.available_actions(context, subject_ref, opts)
  end

  @impl true
  def apply_action(
        %RequestContext{} = context,
        %SubjectRef{} = subject_ref,
        %OperatorActionRequest{} = action_request,
        opts
      )
      when is_list(opts) do
    OperatorAdapter.apply_action(context, subject_ref, action_request, opts)
  end

  @impl true
  def list_memory_fragments(
        %RequestContext{} = context,
        %MemoryFragmentListRequest{} = request,
        opts
      )
      when is_list(opts) do
    OperatorAdapter.list_memory_fragments(context, request, opts)
  end

  @impl true
  def memory_fragment_by_proof_token(
        %RequestContext{} = context,
        %MemoryProofTokenLookup{} = lookup,
        opts
      )
      when is_list(opts) do
    OperatorAdapter.memory_fragment_by_proof_token(context, lookup, opts)
  end

  @impl true
  def memory_fragment_provenance(%RequestContext{} = context, fragment_ref, opts)
      when is_binary(fragment_ref) and is_list(opts) do
    OperatorAdapter.memory_fragment_provenance(context, fragment_ref, opts)
  end

  @impl true
  def request_memory_share_up(
        %RequestContext{} = context,
        %MemoryShareUpRequest{} = request,
        opts
      )
      when is_list(opts) do
    OperatorAdapter.request_memory_share_up(context, request, opts)
  end

  @impl true
  def request_memory_promotion(
        %RequestContext{} = context,
        %MemoryPromotionRequest{} = request,
        opts
      )
      when is_list(opts) do
    OperatorAdapter.request_memory_promotion(context, request, opts)
  end

  @impl true
  def request_memory_invalidation(
        %RequestContext{} = context,
        %MemoryInvalidationRequest{} = request,
        opts
      )
      when is_list(opts) do
    OperatorAdapter.request_memory_invalidation(context, request, opts)
  end

  @impl true
  def start_run(domain_call, opts) when is_map(domain_call) and is_list(opts) do
    WorkAdapter.start_run(domain_call, opts)
  end

  @impl true
  def run_status(run_ref, attrs, opts) when is_map(attrs) and is_list(opts) do
    OperatorAdapter.run_status(run_ref, attrs, opts)
  end

  @impl true
  def review_run(run_ref, evidence_attrs, opts) when is_map(evidence_attrs) and is_list(opts) do
    OperatorAdapter.review_run(run_ref, evidence_attrs, opts)
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
end
