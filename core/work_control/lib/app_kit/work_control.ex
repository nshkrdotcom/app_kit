defmodule AppKit.WorkControl do
  @moduledoc """
  Reusable governed-run and work-submission helpers.
  """

  alias AppKit.Core.{
    ActionResult,
    RequestContext,
    Result,
    RunRef,
    RunRequest,
    SurfaceError
  }

  alias AppKit.BackendConfig

  def start_run(domain_call_or_context, opts_or_request \\ [])

  @spec start_run(map(), keyword()) :: {:ok, Result.t()} | {:error, atom()}
  def start_run(domain_call, opts) when is_map(domain_call) and is_list(opts) do
    backend(opts).start_run(domain_call, opts)
  end

  @spec start_run(RequestContext.t(), RunRequest.t()) ::
          {:ok, Result.t()} | {:error, SurfaceError.t()}
  def start_run(%RequestContext{} = context, %RunRequest{} = run_request) do
    start_run(context, run_request, [])
  end

  @spec start_run(RequestContext.t(), RunRequest.t(), keyword()) ::
          {:ok, Result.t()} | {:error, SurfaceError.t()}
  def start_run(%RequestContext{} = context, %RunRequest{} = run_request, opts)
      when is_list(opts) do
    backend(opts).start_run(context, run_request, opts)
  end

  @spec retry_run(RequestContext.t(), RunRef.t()) ::
          {:ok, ActionResult.t()} | {:error, SurfaceError.t()}
  def retry_run(%RequestContext{} = context, %RunRef{} = run_ref) do
    retry_run(context, run_ref, [])
  end

  @spec retry_run(RequestContext.t(), RunRef.t(), keyword()) ::
          {:ok, ActionResult.t()} | {:error, SurfaceError.t()}
  def retry_run(%RequestContext{} = context, %RunRef{} = run_ref, opts) when is_list(opts) do
    backend(opts).retry_run(context, run_ref, opts)
  end

  @spec cancel_run(RequestContext.t(), RunRef.t()) ::
          {:ok, ActionResult.t()} | {:error, SurfaceError.t()}
  def cancel_run(%RequestContext{} = context, %RunRef{} = run_ref) do
    cancel_run(context, run_ref, [])
  end

  @spec cancel_run(RequestContext.t(), RunRef.t(), keyword()) ::
          {:ok, ActionResult.t()} | {:error, SurfaceError.t()}
  def cancel_run(%RequestContext{} = context, %RunRef{} = run_ref, opts) when is_list(opts) do
    backend(opts).cancel_run(context, run_ref, opts)
  end

  defp backend(opts) do
    BackendConfig.resolve(opts, :work_backend, :work_backend, AppKit.WorkControl.DefaultBackend)
  end
end
