defmodule AppKit.Core.Telemetry do
  @moduledoc """
  Frozen repo-owned telemetry contract for AppKit request-edge and trace joins.
  """

  @definitions %{
    trace_minted: %{
      event_name: [:app_kit, :trace, :minted],
      measurements: [:count],
      metadata: [:trace_id, :tenant_id, :source, :surface]
    },
    trace_rejected: %{
      event_name: [:app_kit, :trace, :rejected],
      measurements: [:count],
      metadata: [:reason, :tenant_id, :source, :surface]
    },
    trace_replaced: %{
      event_name: [:app_kit, :trace, :replaced],
      measurements: [:count],
      metadata: [:trace_id, :tenant_id, :reason, :source, :surface]
    },
    unified_trace_assembled: %{
      event_name: [:app_kit, :operator, :unified_trace, :assembled],
      measurements: [:count, :step_count, :join_key_count],
      metadata: [:trace_id, :tenant_id, :installation_id, :execution_id, :source, :surface]
    }
  }

  @type event_key :: :trace_minted | :trace_rejected | :trace_replaced | :unified_trace_assembled

  @spec definitions() :: map()
  def definitions, do: @definitions

  @spec event_name(event_key()) :: [atom(), ...]
  def event_name(key), do: definition!(key).event_name

  @spec measurement_keys(event_key()) :: [atom(), ...]
  def measurement_keys(key), do: definition!(key).measurements

  @spec metadata_keys(event_key()) :: [atom(), ...]
  def metadata_keys(key), do: definition!(key).metadata

  @spec trace_minted(map()) :: :ok
  def trace_minted(metadata), do: emit(:trace_minted, %{count: 1}, metadata)

  @spec trace_rejected(map()) :: :ok
  def trace_rejected(metadata), do: emit(:trace_rejected, %{count: 1}, metadata)

  @spec trace_replaced(map()) :: :ok
  def trace_replaced(metadata), do: emit(:trace_replaced, %{count: 1}, metadata)

  @spec unified_trace_assembled(map(), map()) :: :ok
  def unified_trace_assembled(metadata, measurements) do
    emit(:unified_trace_assembled, measurements, metadata)
  end

  @spec definition!(event_key()) :: map()
  def definition!(key) do
    case Map.fetch(@definitions, key) do
      {:ok, definition} -> definition
      :error -> raise ArgumentError, "unsupported AppKit telemetry definition: #{inspect(key)}"
    end
  end

  defp emit(key, measurements, metadata) do
    :telemetry.execute(event_name(key), measurements, metadata)
  end
end
