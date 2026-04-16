defmodule AppKit.Core.Backends.OperatorBackend do
  @moduledoc """
  Backend contract for `AppKit.OperatorSurface`.

  The public operator surface stays stable while projections and review wiring
  can come from different lower implementations.
  """

  alias AppKit.Core.{
    ActionResult,
    ExecutionRef,
    OperatorAction,
    OperatorActionRequest,
    OperatorProjection,
    RequestContext,
    RunRef,
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

  @callback available_actions(RequestContext.t(), SubjectRef.t(), keyword()) ::
              {:ok, [OperatorAction.t()]} | {:error, SurfaceError.t()}

  @callback apply_action(RequestContext.t(), SubjectRef.t(), OperatorActionRequest.t(), keyword()) ::
              {:ok, ActionResult.t()} | {:error, SurfaceError.t()}

  @callback run_status(RunRef.t(), map(), keyword()) :: {:ok, map()} | {:error, atom()}
  @callback review_run(RunRef.t(), map(), keyword()) :: {:ok, map()} | {:error, atom()}

  @optional_callbacks [
    subject_status: 3,
    timeline: 3,
    get_unified_trace: 3,
    available_actions: 3,
    apply_action: 4,
    run_status: 3,
    review_run: 3
  ]
end
