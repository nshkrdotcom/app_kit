defmodule AppKit.RuntimeSurface do
  @moduledoc """
  Product-facing runtime profile, status, logs, and live-effect proof facade.

  Products call this surface for durable runtime profile application and
  operator-safe runtime proof DTOs. The default backend is the Mezzanine bridge;
  tests and hosts can supply an explicit backend.
  """

  alias AppKit.BackendConfig
  alias AppKit.Core.RequestContext

  @backend_key :runtime_backend
  @default_backend AppKit.Bridges.MezzanineBridge

  @spec apply_runtime_profile(RequestContext.t(), map(), keyword()) ::
          {:ok, struct()} | {:error, term()}
  def apply_runtime_profile(%RequestContext{} = context, runtime_profile, opts \\ [])
      when is_map(runtime_profile) and is_list(opts) do
    backend(opts).apply_runtime_profile(context, runtime_profile, opts)
  end

  @spec runtime_status(RequestContext.t(), map(), keyword()) :: {:ok, struct()} | {:error, term()}
  def runtime_status(%RequestContext{} = context, request \\ %{}, opts \\ [])
      when is_map(request) and is_list(opts) do
    backend(opts).runtime_status(context, request, opts)
  end

  @spec runtime_logs(RequestContext.t(), map(), keyword()) :: {:ok, struct()} | {:error, term()}
  def runtime_logs(%RequestContext{} = context, request \\ %{}, opts \\ [])
      when is_map(request) and is_list(opts) do
    backend(opts).runtime_logs(context, request, opts)
  end

  @spec record_live_effect(RequestContext.t(), map(), keyword()) ::
          {:ok, struct()} | {:error, term()}
  def record_live_effect(%RequestContext{} = context, attrs, opts \\ [])
      when is_map(attrs) and is_list(opts) do
    backend(opts).record_live_effect(context, attrs, opts)
  end

  @spec fetch_github_pr_evidence(RequestContext.t(), map(), keyword()) ::
          {:ok, struct()} | {:error, term()}
  def fetch_github_pr_evidence(%RequestContext{} = context, request, opts \\ [])
      when is_map(request) and is_list(opts) do
    backend(opts).fetch_github_pr_evidence(context, request, opts)
  end

  @spec cleanup_github_pr_branch(RequestContext.t(), map(), keyword()) ::
          {:ok, struct()} | {:error, term()}
  def cleanup_github_pr_branch(%RequestContext{} = context, request, opts \\ [])
      when is_map(request) and is_list(opts) do
    backend(opts).cleanup_github_pr_branch(context, request, opts)
  end

  defp backend(opts) do
    BackendConfig.resolve(opts, :backend, @backend_key, @default_backend)
  end
end
