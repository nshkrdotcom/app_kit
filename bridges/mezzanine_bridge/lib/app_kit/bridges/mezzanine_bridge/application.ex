defmodule AppKit.Bridges.MezzanineBridge.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    Supervisor.start_link([],
      strategy: :one_for_one,
      name: AppKit.Bridges.MezzanineBridge.Supervisor
    )
  end
end
