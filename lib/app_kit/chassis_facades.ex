defmodule AppKit.SpatialGateway do
  @moduledoc "Root workspace facade for Chassis spatial readback smoke commands."

  alias AppKit.SpatialGateway.Backend.Standalone

  @spec get_active_profile(keyword()) :: {:ok, map()}
  def get_active_profile(opts \\ []),
    do: Standalone.get_active_profile(%{}, opts)
end

defmodule AppKit.SpatialGateway.Backend.Standalone do
  @moduledoc false

  @spec get_active_profile(map(), keyword()) :: {:ok, map()}
  def get_active_profile(_request, _opts) do
    {:ok,
     %{
       profile_ref:
         Application.get_env(:app_kit, :chassis_deployment_profile, "profile:monolith"),
       source: :standalone
     }}
  end
end

defmodule AppKit.EvolutionSurface do
  @moduledoc "Root workspace facade for Chassis Evolution smoke commands."

  @spec get_evolution_status(map(), map() | keyword(), keyword()) :: {:ok, map()}
  def get_evolution_status(_ctx, params, _opts \\ []) do
    {:ok, %{evolution_ref: params[:evolution_ref] || "evo:dev:smoke", state: :queued}}
  end
end
