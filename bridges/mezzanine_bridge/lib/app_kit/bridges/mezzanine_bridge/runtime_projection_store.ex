defmodule AppKit.Bridges.MezzanineBridge.RuntimeProjectionStore do
  @moduledoc false

  use GenServer

  alias AppKit.Core.RequestContext

  @default_name __MODULE__
  @default_ttl_ms :timer.hours(1)
  @default_max_entries 1_000

  defstruct entries: %{}, ttl_ms: @default_ttl_ms, max_entries: @default_max_entries

  def start_link(opts) when is_list(opts) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, @default_name))
  end

  def put(context, run_ref, projection, opts \\ [])

  def put(%RequestContext{} = context, run_ref, projection, opts)
      when is_binary(run_ref) and is_map(projection) and is_list(opts) do
    call(opts, {:put, tenant_ref(context), run_ref, projection, Keyword.get(opts, :ttl_ms)})
  end

  def put(_context, _run_ref, _projection, _opts),
    do: {:error, :invalid_runtime_projection}

  def get(context, run_ref, opts \\ [])

  def get(%RequestContext{} = context, run_ref, opts)
      when is_binary(run_ref) and is_list(opts) do
    call(opts, {:get, tenant_ref(context), run_ref}, nil)
  end

  def get(_context, _run_ref, _opts), do: nil

  def reset(opts \\ []) when is_list(opts) do
    case Keyword.fetch(opts, :tenant_ref) do
      {:ok, tenant_ref} -> call(opts, {:reset_tenant, normalize_ref(tenant_ref)})
      :error -> call(opts, :reset_all)
    end
  end

  @impl true
  def init(opts) do
    {:ok,
     %__MODULE__{
       ttl_ms: Keyword.get(opts, :ttl_ms, @default_ttl_ms),
       max_entries: Keyword.get(opts, :max_entries, @default_max_entries)
     }}
  end

  @impl true
  def handle_call({:put, tenant_ref, run_ref, projection, ttl_ms}, _from, state) do
    now_ms = now_ms()
    ttl_ms = normalize_ttl_ms(ttl_ms, state.ttl_ms)
    key = {tenant_ref, run_ref}

    entry = %{
      projection: projection,
      inserted_at_ms: now_ms,
      expires_at_ms: now_ms + ttl_ms
    }

    entries =
      state.entries
      |> prune_expired(now_ms)
      |> Map.put(key, entry)
      |> trim_entries(state.max_entries)

    {:reply, :ok, %{state | entries: entries}}
  end

  def handle_call({:get, tenant_ref, run_ref}, _from, state) do
    now_ms = now_ms()
    key = {tenant_ref, run_ref}
    entries = prune_expired(state.entries, now_ms)

    reply =
      case Map.fetch(entries, key) do
        {:ok, %{projection: projection}} -> projection
        :error -> nil
      end

    {:reply, reply, %{state | entries: entries}}
  end

  def handle_call({:reset_tenant, tenant_ref}, _from, state) do
    entries =
      Map.reject(state.entries, fn
        {{^tenant_ref, _run_ref}, _entry} -> true
        {_key, _entry} -> false
      end)

    {:reply, :ok, %{state | entries: entries}}
  end

  def handle_call(:reset_all, _from, state) do
    {:reply, :ok, %{state | entries: %{}}}
  end

  defp call(opts, message, default \\ {:error, :runtime_projection_store_unavailable}) do
    server =
      opts
      |> Keyword.get(:runtime_projection_store, @default_name)
      |> registered_process()

    case server do
      nil -> default
      pid -> GenServer.call(pid, message)
    end
  end

  defp registered_process(pid) when is_pid(pid), do: pid
  defp registered_process(name) when is_atom(name), do: Process.whereis(name)
  defp registered_process(_name), do: nil

  defp tenant_ref(%RequestContext{tenant_ref: %{id: id}}), do: normalize_ref(id)

  defp normalize_ref(%{id: id}), do: normalize_ref(id)
  defp normalize_ref(value) when is_binary(value), do: value
  defp normalize_ref(value) when is_atom(value), do: Atom.to_string(value)
  defp normalize_ref(value), do: to_string(value)

  defp normalize_ttl_ms(value, _default) when is_integer(value) and value >= 0, do: value
  defp normalize_ttl_ms(_value, default), do: default

  defp prune_expired(entries, now_ms) do
    Map.reject(entries, fn {_key, %{expires_at_ms: expires_at_ms}} ->
      expires_at_ms <= now_ms
    end)
  end

  defp trim_entries(entries, max_entries) when map_size(entries) <= max_entries, do: entries

  defp trim_entries(entries, max_entries) do
    entries
    |> Enum.sort_by(fn {_key, %{inserted_at_ms: inserted_at_ms}} -> inserted_at_ms end)
    |> Enum.drop(max(map_size(entries) - max_entries, 0))
    |> Map.new()
  end

  defp now_ms do
    System.monotonic_time(:millisecond)
  end
end
