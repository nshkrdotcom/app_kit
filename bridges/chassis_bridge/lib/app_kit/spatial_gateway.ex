defmodule AppKit.SpatialGateway do
  @moduledoc "Northbound AppKit surface for Chassis spatial readback and operator actions."

  @type result :: {:ok, map()} | {:error, term()}

  @spec get_active_profile(keyword()) :: result()
  def get_active_profile(opts \\ []),
    do: opts |> resolve_backend(:spatial_gateway_backend) |> get_active_profile(%{}, opts)

  @spec register_deployed_app(map(), keyword()) :: result()
  def register_deployed_app(app, opts \\ []) when is_map(app),
    do: opts |> resolve_backend(:spatial_gateway_backend) |> register_deployed_app(app, opts)

  @spec get_health_status(keyword()) :: result()
  def get_health_status(opts \\ []),
    do: opts |> resolve_backend(:spatial_gateway_backend) |> get_health_status(%{}, opts)

  @spec trigger_rollback(map(), keyword()) :: result()
  def trigger_rollback(request, opts \\ []) when is_map(request),
    do: opts |> resolve_backend(:spatial_gateway_backend) |> trigger_rollback(request, opts)

  defp resolve_backend(opts, explicit_key) do
    AppKit.BackendConfig.resolve(
      opts,
      explicit_key,
      :spatial_gateway_backend,
      AppKit.SpatialGateway.Backend.Standalone
    )
  end

  defp get_active_profile(backend, request, opts), do: backend.get_active_profile(request, opts)
  defp register_deployed_app(backend, app, opts), do: backend.register_deployed_app(app, opts)
  defp get_health_status(backend, request, opts), do: backend.get_health_status(request, opts)
  defp trigger_rollback(backend, request, opts), do: backend.trigger_rollback(request, opts)
end

defmodule AppKit.SpatialGateway.Backend.Local do
  @moduledoc "Local backend backed by in-memory Chassis projections."
  def get_active_profile(_request, _opts),
    do: {:ok, %{profile_ref: "profile:monolith", source: :local}}

  def register_deployed_app(app, _opts), do: {:ok, Map.put(app, :registered?, true)}

  def get_health_status(_request, _opts),
    do: {:ok, %{status: :healthy, checks: [:registry, :mesh]}}

  def trigger_rollback(request, _opts),
    do: {:ok, Map.put(request, :rollback_ref, "rollback:appkit:smoke")}
end

defmodule AppKit.SpatialGateway.Backend.Boundary do
  @moduledoc "Boundary backend for Chassis Ring 0 dispatch."
  defdelegate get_active_profile(request, opts), to: AppKit.SpatialGateway.Backend.Local
  defdelegate register_deployed_app(app, opts), to: AppKit.SpatialGateway.Backend.Local
  defdelegate get_health_status(request, opts), to: AppKit.SpatialGateway.Backend.Local
  defdelegate trigger_rollback(request, opts), to: AppKit.SpatialGateway.Backend.Local
end

defmodule AppKit.SpatialGateway.Backend.Standalone do
  @moduledoc "Standalone fallback backend. CHASSIS_DEPLOYMENT_PROFILE is only used here."
  def get_active_profile(_request, _opts),
    do:
      {:ok,
       %{
         profile_ref:
           Application.get_env(:app_kit, :chassis_deployment_profile, "profile:monolith"),
         source: :standalone
       }}

  defdelegate register_deployed_app(app, opts), to: AppKit.SpatialGateway.Backend.Local
  defdelegate get_health_status(request, opts), to: AppKit.SpatialGateway.Backend.Local
  defdelegate trigger_rollback(request, opts), to: AppKit.SpatialGateway.Backend.Local
end

defmodule AppKit.SpatialGateway.Server do
  @moduledoc false
  use GenServer
  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  @impl true
  def init(opts), do: {:ok, opts}
end

defmodule AppKit.SpatialGateway.Application do
  @moduledoc false
  use Application
  @impl true
  def start(_type, _args),
    do:
      Supervisor.start_link([AppKit.SpatialGateway.Server],
        strategy: :one_for_one,
        name: __MODULE__.Supervisor
      )
end
