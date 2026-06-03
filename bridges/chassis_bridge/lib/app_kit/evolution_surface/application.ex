defmodule AppKit.EvolutionSurface.Application do
  @moduledoc "Application supervisor for AppKit EvolutionSurface."

  use Application

  @impl true
  def start(_type, _args) do
    Supervisor.start_link([AppKit.EvolutionSurface.Server],
      strategy: :one_for_one,
      name: AppKit.EvolutionSurface.Supervisor
    )
  end
end
