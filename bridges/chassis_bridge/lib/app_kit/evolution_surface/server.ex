defmodule AppKit.EvolutionSurface.Server do
  @moduledoc "Private GenServer for cached EvolutionSurface readback calls."

  use GenServer

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    {name, opts} = Keyword.pop(opts, :name, __MODULE__)

    case name do
      nil -> GenServer.start_link(__MODULE__, opts, [])
      _ -> GenServer.start_link(__MODULE__, opts, name: name)
    end
  end

  @spec list_evolution_batches(GenServer.server(), map()) :: {:ok, term()} | {:error, term()}
  def list_evolution_batches(server \\ __MODULE__, request \\ %{}) do
    GenServer.call(server, {:list_evolution_batches, request})
  end

  @impl true
  def init(opts) do
    {:ok, %{opts: opts, last_page: nil}}
  end

  @impl true
  def handle_call({:list_evolution_batches, request}, _from, state) do
    context = Keyword.fetch!(state.opts, :context)

    case AppKit.EvolutionSurface.list_evolution_batches(context, request, state.opts) do
      {:ok, page} -> {:reply, {:ok, page}, %{state | last_page: page}}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end
end
