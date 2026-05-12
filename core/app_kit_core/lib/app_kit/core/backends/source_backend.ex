defmodule AppKit.Core.Backends.SourceBackend do
  @moduledoc """
  Frozen northbound backend contract for source intake and source state lookup.
  """

  alias AppKit.Core.{RequestContext, SurfaceError}

  @callback sync_linear_issues(RequestContext.t(), map(), keyword()) ::
              {:ok, map()} | {:error, SurfaceError.t()}

  @callback current_linear_issue_states(RequestContext.t(), [String.t()], map(), keyword()) ::
              {:ok, map()} | {:error, SurfaceError.t()}

  @callback fetch_linear_candidates(RequestContext.t(), map(), keyword()) ::
              {:ok, map()} | {:error, SurfaceError.t()}

  @callback publish_linear_source(RequestContext.t(), map(), keyword()) ::
              {:ok, map()} | {:error, SurfaceError.t()}
end
