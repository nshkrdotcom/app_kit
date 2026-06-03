defmodule AppKit.ChassisFacades do
  @moduledoc "Root workspace marker for Chassis bridge surfaces supplied by `app_kit_chassis_bridge`."

  @spec spatial_gateway() :: module()
  def spatial_gateway, do: AppKit.SpatialGateway

  @spec evolution_surface() :: module()
  def evolution_surface, do: AppKit.EvolutionSurface
end
