defmodule AppKit.SpatialGateway.Server do
  @moduledoc "Private GenServer that caches Chassis active profile readback."

  use GenServer

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    {name, opts} = Keyword.pop(opts, :name, __MODULE__)

    case name do
      nil -> GenServer.start_link(__MODULE__, opts, [])
      _ -> GenServer.start_link(__MODULE__, opts, name: name)
    end
  end

  @spec get_active_profile(GenServer.server()) :: {:ok, String.t()} | {:error, term()}
  def get_active_profile(server \\ __MODULE__), do: GenServer.call(server, :get_active_profile)

  @impl true
  def init(opts) do
    {:ok, %{opts: opts, active_profile: nil}}
  end

  @impl true
  def handle_call(:get_active_profile, _from, state) do
    case AppKit.SpatialGateway.get_active_profile(state.opts) do
      {:ok, profile} -> {:reply, {:ok, profile}, %{state | active_profile: profile}}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end
end
