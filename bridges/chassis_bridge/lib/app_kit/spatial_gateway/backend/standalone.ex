defmodule AppKit.SpatialGateway.Backend.Standalone do
  @moduledoc "Standalone fallback backend. CHASSIS_DEPLOYMENT_PROFILE is only used here."

  @behaviour AppKit.SpatialGateway.Backend

  alias AppKit.SpatialGateway.Request

  @impl true
  def handle(%Request.GetActiveProfile{}, _opts) do
    {:ok, System.get_env("CHASSIS_DEPLOYMENT_PROFILE", "profile:monolith")}
  end

  @impl true
  def handle(%Request.GetHealthStatus{}, _opts), do: {:ok, :healthy}

  @impl true
  def handle(%Request.RegisterDeployedApp{}, _opts), do: {:error, :standalone}

  @impl true
  def handle(%Request.TriggerRollback{}, _opts), do: {:error, :standalone}
end
