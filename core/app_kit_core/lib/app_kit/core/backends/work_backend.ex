defmodule AppKit.Core.Backends.WorkBackend do
  @moduledoc """
  Backend contract for `AppKit.WorkControl`.

  This keeps the northbound surface stable while allowing different lower
  implementations to back it.
  """

  alias AppKit.Core.{ActionResult, RequestContext, Result, RunRef, RunRequest, SurfaceError}

  @callback start_run(RequestContext.t(), RunRequest.t(), keyword()) ::
              {:ok, Result.t()} | {:error, SurfaceError.t()}

  @callback retry_run(RequestContext.t(), RunRef.t(), keyword()) ::
              {:ok, ActionResult.t()} | {:error, SurfaceError.t()}

  @callback cancel_run(RequestContext.t(), RunRef.t(), keyword()) ::
              {:ok, ActionResult.t()} | {:error, SurfaceError.t()}

  @callback start_run(map(), keyword()) :: {:ok, Result.t()} | {:error, atom()}

  @optional_callbacks start_run: 2, start_run: 3, retry_run: 3, cancel_run: 3
end
