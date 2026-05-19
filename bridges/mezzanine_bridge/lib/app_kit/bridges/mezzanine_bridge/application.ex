defmodule AppKit.Bridges.MezzanineBridge.Application do
  @moduledoc false

  use Application

  alias AppKit.Bridges.MezzanineBridge.RuntimeProjectionStore

  @impl true
  def start(_type, _args) do
    children = [
      RuntimeProjectionStore
    ]

    Supervisor.start_link(children,
      strategy: :one_for_one,
      name: AppKit.Bridges.MezzanineBridge.Supervisor
    )
  end
end
