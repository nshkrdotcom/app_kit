defmodule AppKit.Core.Backends.SourceBackend do
  @moduledoc """
  Frozen northbound backend contract for source intake and source state lookup.
  """

  alias AppKit.Core.{RequestContext, SurfaceError}

  @type source_role_ref :: atom() | String.t()

  @callback sync_source(RequestContext.t(), source_role_ref(), map(), keyword()) ::
              {:ok, map()} | {:error, SurfaceError.t()}

  @callback current_states(RequestContext.t(), source_role_ref(), map(), keyword()) ::
              {:ok, map()} | {:error, SurfaceError.t()}

  @callback fetch_candidates(RequestContext.t(), source_role_ref(), map(), keyword()) ::
              {:ok, map()} | {:error, SurfaceError.t()}

  @callback publish_source(RequestContext.t(), source_role_ref(), map(), keyword()) ::
              {:ok, map()} | {:error, SurfaceError.t()}
end
