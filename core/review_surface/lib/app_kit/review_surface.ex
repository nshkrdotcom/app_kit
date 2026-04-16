defmodule AppKit.ReviewSurface do
  @moduledoc """
  Typed app-facing review listing, detail, and decision surface.
  """

  alias AppKit.Core.{
    ActionResult,
    DecisionRef,
    PageRequest,
    PageResult,
    RequestContext,
    SurfaceError
  }

  @spec list_pending(RequestContext.t(), PageRequest.t(), keyword()) ::
          {:ok, PageResult.t()} | {:error, SurfaceError.t()}
  def list_pending(%RequestContext{} = context, %PageRequest{} = page_request, opts \\ []) do
    backend(opts).list_pending(context, page_request, opts)
  end

  @spec get_review(RequestContext.t(), DecisionRef.t(), keyword()) ::
          {:ok, map()} | {:error, SurfaceError.t()}
  def get_review(%RequestContext{} = context, %DecisionRef{} = decision_ref, opts \\ []) do
    backend(opts).get_review(context, decision_ref, opts)
  end

  @spec record_decision(RequestContext.t(), DecisionRef.t(), map(), keyword()) ::
          {:ok, ActionResult.t()} | {:error, SurfaceError.t()}
  def record_decision(
        %RequestContext{} = context,
        %DecisionRef{} = decision_ref,
        attrs,
        opts \\ []
      )
      when is_map(attrs) do
    backend(opts).record_decision(context, decision_ref, attrs, opts)
  end

  defp backend(opts) do
    Keyword.get(opts, :review_backend) ||
      Application.get_env(:app_kit, :review_backend, AppKit.Bridges.MezzanineBridge)
  end
end
