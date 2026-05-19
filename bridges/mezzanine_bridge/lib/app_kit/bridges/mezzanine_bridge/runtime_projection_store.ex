defmodule AppKit.Bridges.MezzanineBridge.RuntimeProjectionStore do
  @moduledoc false

  @table __MODULE__

  def put(run_ref, projection) when is_binary(run_ref) do
    table = ensure_table()
    true = :ets.insert(table, {run_ref, projection})
    :ok
  end

  def get(run_ref) when is_binary(run_ref) do
    table = ensure_table()

    case :ets.lookup(table, run_ref) do
      [{^run_ref, projection}] -> projection
      [] -> nil
    end
  end

  def get(_run_ref), do: nil

  defp ensure_table do
    case :ets.whereis(@table) do
      :undefined ->
        try do
          :ets.new(@table, [
            :named_table,
            :public,
            {:read_concurrency, true},
            {:write_concurrency, true}
          ])
        rescue
          ArgumentError -> @table
        end

      _table ->
        @table
    end
  end
end
