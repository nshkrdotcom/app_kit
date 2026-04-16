defmodule AppKit.Core.Backends.ReviewBackend do
  @moduledoc """
  Frozen northbound backend contract for review and decision flows.
  """

  alias AppKit.Core.{
    ActionResult,
    DecisionRef,
    PageRequest,
    PageResult,
    RequestContext,
    SurfaceError
  }

  @callback list_pending(RequestContext.t(), PageRequest.t(), keyword()) ::
              {:ok, PageResult.t()} | {:error, SurfaceError.t()}

  @callback get_review(RequestContext.t(), DecisionRef.t(), keyword()) ::
              {:ok, map()} | {:error, SurfaceError.t()}

  @callback record_decision(RequestContext.t(), DecisionRef.t(), map(), keyword()) ::
              {:ok, ActionResult.t()} | {:error, SurfaceError.t()}
end
