defmodule AppKit.OperatorSurface do
  @moduledoc """
  Operator-facing composition around lower review and projection reads.
  """

  alias AppKit.AppConfig

  alias AppKit.Core.{
    ActionResult,
    ExecutionRef,
    MemoryFragmentListRequest,
    MemoryFragmentProjection,
    MemoryFragmentProvenance,
    MemoryInvalidationRequest,
    MemoryPromotionRequest,
    MemoryProofTokenLookup,
    MemoryShareUpRequest,
    OperatorAction,
    OperatorActionRequest,
    OperatorProjection,
    ReadLease,
    RequestContext,
    RunRef,
    StreamAttachLease,
    SubjectRef,
    SurfaceError,
    TimelineEvent,
    UnifiedTrace
  }

  @spec subject_status(RequestContext.t(), SubjectRef.t()) ::
          {:ok, OperatorProjection.t()} | {:error, SurfaceError.t()}
  def subject_status(%RequestContext{} = context, %SubjectRef{} = subject_ref) do
    subject_status(context, subject_ref, [])
  end

  @spec subject_status(RequestContext.t(), SubjectRef.t(), keyword()) ::
          {:ok, OperatorProjection.t()} | {:error, SurfaceError.t()}
  def subject_status(%RequestContext{} = context, %SubjectRef{} = subject_ref, opts)
      when is_list(opts) do
    with_operator_surface(opts, fn backend ->
      backend.subject_status(context, subject_ref, opts)
    end)
  end

  @spec timeline(RequestContext.t(), SubjectRef.t()) ::
          {:ok, [TimelineEvent.t()]} | {:error, SurfaceError.t()}
  def timeline(%RequestContext{} = context, %SubjectRef{} = subject_ref) do
    timeline(context, subject_ref, [])
  end

  @spec timeline(RequestContext.t(), SubjectRef.t(), keyword()) ::
          {:ok, [TimelineEvent.t()]} | {:error, SurfaceError.t()}
  def timeline(%RequestContext{} = context, %SubjectRef{} = subject_ref, opts)
      when is_list(opts) do
    with_operator_surface(opts, fn backend ->
      backend.timeline(context, subject_ref, opts)
    end)
  end

  @spec get_unified_trace(RequestContext.t(), ExecutionRef.t()) ::
          {:ok, UnifiedTrace.t()} | {:error, SurfaceError.t()}
  def get_unified_trace(%RequestContext{} = context, %ExecutionRef{} = execution_ref) do
    get_unified_trace(context, execution_ref, [])
  end

  @spec get_unified_trace(RequestContext.t(), ExecutionRef.t(), keyword()) ::
          {:ok, UnifiedTrace.t()} | {:error, SurfaceError.t()}
  def get_unified_trace(%RequestContext{} = context, %ExecutionRef{} = execution_ref, opts)
      when is_list(opts) do
    with_operator_surface(opts, fn backend ->
      backend.get_unified_trace(context, execution_ref, opts)
    end)
  end

  @spec issue_read_lease(RequestContext.t(), ExecutionRef.t()) ::
          {:ok, ReadLease.t()} | {:error, SurfaceError.t()}
  def issue_read_lease(%RequestContext{} = context, %ExecutionRef{} = execution_ref) do
    issue_read_lease(context, execution_ref, [])
  end

  @spec issue_read_lease(RequestContext.t(), ExecutionRef.t(), keyword()) ::
          {:ok, ReadLease.t()} | {:error, SurfaceError.t()}
  def issue_read_lease(%RequestContext{} = context, %ExecutionRef{} = execution_ref, opts)
      when is_list(opts) do
    with_operator_surface(opts, fn backend ->
      backend.issue_read_lease(context, execution_ref, opts)
    end)
  end

  @spec issue_stream_attach_lease(RequestContext.t(), ExecutionRef.t()) ::
          {:ok, StreamAttachLease.t()} | {:error, SurfaceError.t()}
  def issue_stream_attach_lease(%RequestContext{} = context, %ExecutionRef{} = execution_ref) do
    issue_stream_attach_lease(context, execution_ref, [])
  end

  @spec issue_stream_attach_lease(RequestContext.t(), ExecutionRef.t(), keyword()) ::
          {:ok, StreamAttachLease.t()} | {:error, SurfaceError.t()}
  def issue_stream_attach_lease(
        %RequestContext{} = context,
        %ExecutionRef{} = execution_ref,
        opts
      )
      when is_list(opts) do
    with_operator_surface(opts, fn backend ->
      backend.issue_stream_attach_lease(context, execution_ref, opts)
    end)
  end

  @spec available_actions(RequestContext.t(), SubjectRef.t()) ::
          {:ok, [OperatorAction.t()]} | {:error, SurfaceError.t()}
  def available_actions(%RequestContext{} = context, %SubjectRef{} = subject_ref) do
    available_actions(context, subject_ref, [])
  end

  @spec available_actions(RequestContext.t(), SubjectRef.t(), keyword()) ::
          {:ok, [OperatorAction.t()]} | {:error, SurfaceError.t()}
  def available_actions(%RequestContext{} = context, %SubjectRef{} = subject_ref, opts)
      when is_list(opts) do
    with_operator_surface(opts, fn backend ->
      backend.available_actions(context, subject_ref, opts)
    end)
  end

  @spec apply_action(RequestContext.t(), SubjectRef.t(), OperatorActionRequest.t()) ::
          {:ok, ActionResult.t()} | {:error, SurfaceError.t()}
  def apply_action(
        %RequestContext{} = context,
        %SubjectRef{} = subject_ref,
        %OperatorActionRequest{} = action_request
      ) do
    apply_action(context, subject_ref, action_request, [])
  end

  @spec apply_action(RequestContext.t(), SubjectRef.t(), OperatorActionRequest.t(), keyword()) ::
          {:ok, ActionResult.t()} | {:error, SurfaceError.t()}
  def apply_action(
        %RequestContext{} = context,
        %SubjectRef{} = subject_ref,
        %OperatorActionRequest{} = action_request,
        opts
      )
      when is_list(opts) do
    with_operator_surface(opts, fn backend ->
      backend.apply_action(context, subject_ref, action_request, opts)
    end)
  end

  @spec list_memory_fragments(RequestContext.t(), MemoryFragmentListRequest.t(), keyword()) ::
          {:ok, [MemoryFragmentProjection.t()]} | {:error, SurfaceError.t()}
  def list_memory_fragments(
        %RequestContext{} = context,
        %MemoryFragmentListRequest{} = request,
        opts \\ []
      )
      when is_list(opts) do
    with_operator_surface(opts, fn backend ->
      backend.list_memory_fragments(context, request, opts)
    end)
  end

  @spec memory_fragment_by_proof_token(RequestContext.t(), MemoryProofTokenLookup.t(), keyword()) ::
          {:ok, MemoryFragmentProjection.t()} | {:error, SurfaceError.t()}
  def memory_fragment_by_proof_token(
        %RequestContext{} = context,
        %MemoryProofTokenLookup{} = lookup,
        opts \\ []
      )
      when is_list(opts) do
    with_operator_surface(opts, fn backend ->
      backend.memory_fragment_by_proof_token(context, lookup, opts)
    end)
  end

  @spec memory_fragment_provenance(RequestContext.t(), String.t(), keyword()) ::
          {:ok, MemoryFragmentProvenance.t()} | {:error, SurfaceError.t()}
  def memory_fragment_provenance(%RequestContext{} = context, fragment_ref, opts \\ [])
      when is_binary(fragment_ref) and is_list(opts) do
    with_operator_surface(opts, fn backend ->
      backend.memory_fragment_provenance(context, fragment_ref, opts)
    end)
  end

  @spec request_memory_share_up(RequestContext.t(), MemoryShareUpRequest.t(), keyword()) ::
          {:ok, ActionResult.t()} | {:error, SurfaceError.t()}
  def request_memory_share_up(
        %RequestContext{} = context,
        %MemoryShareUpRequest{} = request,
        opts \\ []
      )
      when is_list(opts) do
    with_operator_surface(opts, fn backend ->
      backend.request_memory_share_up(context, request, opts)
    end)
  end

  @spec request_memory_promotion(RequestContext.t(), MemoryPromotionRequest.t(), keyword()) ::
          {:ok, ActionResult.t()} | {:error, SurfaceError.t()}
  def request_memory_promotion(
        %RequestContext{} = context,
        %MemoryPromotionRequest{} = request,
        opts \\ []
      )
      when is_list(opts) do
    with_operator_surface(opts, fn backend ->
      backend.request_memory_promotion(context, request, opts)
    end)
  end

  @spec request_memory_invalidation(RequestContext.t(), MemoryInvalidationRequest.t(), keyword()) ::
          {:ok, ActionResult.t()} | {:error, SurfaceError.t()}
  def request_memory_invalidation(
        %RequestContext{} = context,
        %MemoryInvalidationRequest{} = request,
        opts \\ []
      )
      when is_list(opts) do
    with_operator_surface(opts, fn backend ->
      backend.request_memory_invalidation(context, request, opts)
    end)
  end

  @spec run_status(RunRef.t(), map(), keyword()) :: {:ok, map()} | {:error, atom()}
  def run_status(%RunRef{} = run_ref, attrs, opts \\ []) do
    with_operator_surface(opts, fn backend ->
      backend.run_status(run_ref, attrs, opts)
    end)
  end

  @spec review_run(RunRef.t(), map(), keyword()) :: {:ok, map()} | {:error, atom()}
  def review_run(%RunRef{} = run_ref, evidence_attrs, opts \\ []) do
    with_operator_surface(opts, fn backend ->
      backend.review_run(run_ref, evidence_attrs, opts)
    end)
  end

  defp backend(opts) do
    Keyword.get(opts, :operator_backend) ||
      Application.get_env(:app_kit_core, :operator_backend, AppKit.OperatorSurface.DefaultBackend)
  end

  defp with_operator_surface(opts, callback) when is_function(callback, 1) do
    with {:ok, config} <- AppConfig.normalize(Keyword.get(opts, :config)),
         true <- config.operator_surface? do
      callback.(backend(opts))
    else
      false -> {:error, :operator_surface_disabled}
      {:error, reason} -> {:error, reason}
    end
  end
end
