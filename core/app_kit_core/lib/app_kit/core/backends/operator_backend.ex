defmodule AppKit.Core.Backends.OperatorBackend do
  @moduledoc """
  Backend contract for `AppKit.OperatorSurface`.

  The public operator surface stays stable while projections and review wiring
  can come from different lower implementations.
  """

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

  @callback subject_status(RequestContext.t(), SubjectRef.t(), keyword()) ::
              {:ok, OperatorProjection.t()} | {:error, SurfaceError.t()}

  @callback timeline(RequestContext.t(), SubjectRef.t(), keyword()) ::
              {:ok, [TimelineEvent.t()]} | {:error, SurfaceError.t()}

  @callback get_unified_trace(RequestContext.t(), ExecutionRef.t(), keyword()) ::
              {:ok, UnifiedTrace.t()} | {:error, SurfaceError.t()}

  @callback issue_read_lease(RequestContext.t(), ExecutionRef.t(), keyword()) ::
              {:ok, ReadLease.t()} | {:error, SurfaceError.t()}

  @callback issue_stream_attach_lease(RequestContext.t(), ExecutionRef.t(), keyword()) ::
              {:ok, StreamAttachLease.t()} | {:error, SurfaceError.t()}

  @callback available_actions(RequestContext.t(), SubjectRef.t(), keyword()) ::
              {:ok, [OperatorAction.t()]} | {:error, SurfaceError.t()}

  @callback apply_action(RequestContext.t(), SubjectRef.t(), OperatorActionRequest.t(), keyword()) ::
              {:ok, ActionResult.t()} | {:error, SurfaceError.t()}

  @callback list_memory_fragments(RequestContext.t(), MemoryFragmentListRequest.t(), keyword()) ::
              {:ok, [MemoryFragmentProjection.t()]} | {:error, SurfaceError.t()}

  @callback memory_fragment_by_proof_token(
              RequestContext.t(),
              MemoryProofTokenLookup.t(),
              keyword()
            ) ::
              {:ok, MemoryFragmentProjection.t()} | {:error, SurfaceError.t()}

  @callback memory_fragment_provenance(RequestContext.t(), String.t(), keyword()) ::
              {:ok, MemoryFragmentProvenance.t()} | {:error, SurfaceError.t()}

  @callback request_memory_share_up(RequestContext.t(), MemoryShareUpRequest.t(), keyword()) ::
              {:ok, ActionResult.t()} | {:error, SurfaceError.t()}

  @callback request_memory_promotion(RequestContext.t(), MemoryPromotionRequest.t(), keyword()) ::
              {:ok, ActionResult.t()} | {:error, SurfaceError.t()}

  @callback request_memory_invalidation(
              RequestContext.t(),
              MemoryInvalidationRequest.t(),
              keyword()
            ) ::
              {:ok, ActionResult.t()} | {:error, SurfaceError.t()}

  @callback run_status(RunRef.t(), map(), keyword()) :: {:ok, map()} | {:error, atom()}
  @callback review_run(RunRef.t(), map(), keyword()) :: {:ok, map()} | {:error, atom()}

  @optional_callbacks [
    subject_status: 3,
    timeline: 3,
    get_unified_trace: 3,
    issue_read_lease: 3,
    issue_stream_attach_lease: 3,
    available_actions: 3,
    apply_action: 4,
    list_memory_fragments: 3,
    memory_fragment_by_proof_token: 3,
    memory_fragment_provenance: 3,
    request_memory_share_up: 3,
    request_memory_promotion: 3,
    request_memory_invalidation: 3,
    run_status: 3,
    review_run: 3
  ]
end
