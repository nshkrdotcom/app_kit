defmodule AppKit.SpatialGateway.Application do
  @moduledoc "Application supervisor for the AppKit Chassis bridge."

  use Application

  @impl true
  def start(_type, _args) do
    Supervisor.start_link([AppKit.SpatialGateway.Server],
      strategy: :one_for_one,
      name: AppKit.SpatialGateway.Supervisor
    )
  end
end
