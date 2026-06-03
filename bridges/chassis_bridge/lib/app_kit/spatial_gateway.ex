defmodule AppKit.SpatialGateway do
  @moduledoc "Northbound AppKit surface for Chassis spatial readback and operator actions."

  alias AppKit.BackendConfig
  alias AppKit.SpatialGateway.Request

  @default_backend AppKit.SpatialGateway.Backend.Local

  @type app_atom :: atom()
  @type profile_ref :: String.t()
  @type git_sha :: String.t()
  @type receipt_ref :: String.t()
  @type health_status :: :healthy | :degraded | :unhealthy | String.t()

  @spec get_active_profile(keyword()) :: {:ok, profile_ref()} | {:error, term()}
  def get_active_profile(opts \\ []) do
    dispatch(%Request.GetActiveProfile{}, opts)
  end

  @spec register_deployed_app(app_atom(), git_sha(), keyword()) ::
          {:ok, receipt_ref()} | {:error, term()}
  def register_deployed_app(app_atom, git_sha, opts \\ [])
      when is_atom(app_atom) and is_binary(git_sha) do
    dispatch(%Request.RegisterDeployedApp{app_atom: app_atom, git_sha: git_sha}, opts)
  end

  @spec get_health_status(keyword()) :: {:ok, health_status()} | {:error, term()}
  def get_health_status(opts \\ []) do
    dispatch(%Request.GetHealthStatus{}, opts)
  end

  @spec trigger_rollback(receipt_ref(), keyword()) :: {:ok, receipt_ref()} | {:error, term()}
  def trigger_rollback(receipt_ref, opts \\ []) when is_binary(receipt_ref) do
    dispatch(%Request.TriggerRollback{previous_receipt_ref: receipt_ref}, opts)
  end

  defp dispatch(request, opts) do
    opts
    |> resolve_backend()
    |> handle(request, opts)
  end

  defp resolve_backend(opts) do
    BackendConfig.resolve(
      opts,
      :spatial_gateway_backend,
      :spatial_gateway_backend,
      @default_backend
    )
  end

  defp handle(backend, request, opts) when is_atom(backend), do: backend.handle(request, opts)

  defp handle({backend, backend_opts}, request, opts),
    do: backend.handle(request, Keyword.merge(backend_opts, opts))
end
