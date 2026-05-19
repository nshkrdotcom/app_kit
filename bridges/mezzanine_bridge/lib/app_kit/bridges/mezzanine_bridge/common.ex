defmodule AppKit.Bridges.MezzanineBridge.Common do
  @moduledoc false

  alias AppKit.Core.{PageRequest, PageResult}

  @normalized_atomish_values %{
    "active" => :active,
    "awaiting_review" => :awaiting_review,
    "blocked" => :blocked,
    "created" => :created,
    "degraded" => :degraded,
    "inactive" => :inactive,
    "pending" => :pending,
    "planned" => :planned,
    "planning" => :planning,
    "reused" => :reused,
    "running" => :running,
    "suspended" => :suspended,
    "updated" => :updated
  }

  def fetch_value(map_or_struct, key) when is_map(map_or_struct) do
    map = if is_struct(map_or_struct), do: Map.from_struct(map_or_struct), else: map_or_struct
    Map.get(map, key) || Map.get(map, alternate_key(map, key))
  end

  def fetch_value(_map_or_struct, _key), do: nil

  def maybe_put(map, _key, nil), do: map
  def maybe_put(map, key, value), do: Map.put(map, key, value)

  def compact_map(map) do
    Map.reject(map, fn {_key, value} -> is_nil(value) end)
  end

  def normalize_atomish(value) when is_binary(value),
    do: Map.get(@normalized_atomish_values, value, value)

  def normalize_atomish(value), do: value

  def normalize_string(nil), do: nil
  def normalize_string(value) when is_atom(value), do: Atom.to_string(value)
  def normalize_string(value), do: value

  def coerce_datetime(nil), do: nil
  def coerce_datetime(%DateTime{} = value), do: value

  def coerce_datetime(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _offset} -> datetime
      _other -> value
    end
  end

  def coerce_datetime(value), do: value

  def collect(results) do
    Enum.reduce_while(results, {:ok, []}, fn
      {:ok, value}, {:ok, acc} -> {:cont, {:ok, [value | acc]}}
      {:error, reason}, _acc -> {:halt, {:error, reason}}
    end)
    |> case do
      {:ok, values} -> {:ok, Enum.reverse(values)}
      {:error, reason} -> {:error, reason}
    end
  end

  def map_each(entries, mapper) do
    Enum.reduce_while(entries, {:ok, []}, fn entry, {:ok, acc} ->
      case mapper.(entry) do
        {:ok, mapped} -> {:cont, {:ok, [mapped | acc]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, mapped} -> {:ok, Enum.reverse(mapped)}
      {:error, reason} -> {:error, reason}
    end
  end

  def page_result(entries, %PageRequest{} = page_request) do
    sorted_entries = sort_entries(entries, page_request.sort)
    offset = decode_cursor(page_request.cursor)
    page_entries = Enum.slice(sorted_entries, offset, page_request.limit)
    has_more = offset + length(page_entries) < length(sorted_entries)
    next_cursor = if has_more, do: Integer.to_string(offset + length(page_entries)), else: nil

    PageResult.new(%{
      entries: page_entries,
      next_cursor: next_cursor,
      total_count: length(sorted_entries),
      has_more: has_more
    })
  end

  defp alternate_key(_map, key) when is_atom(key), do: Atom.to_string(key)

  defp alternate_key(map, key) when is_binary(key) do
    Enum.find(Map.keys(map), fn
      existing_key when is_atom(existing_key) -> Atom.to_string(existing_key) == key
      _existing_key -> false
    end)
  end

  defp alternate_key(_map, _key), do: nil

  defp sort_entries(entries, []), do: entries

  defp sort_entries(entries, [sort_spec | _rest]) do
    sorter = fn entry ->
      value = fetch_value(entry, sort_spec.field)

      case {value, sort_spec.nulls || :last} do
        {nil, :first} -> {0, nil}
        {nil, :last} -> {1, nil}
        {other, _nulls} -> {1, other}
      end
    end

    direction = if sort_spec.direction == :desc, do: :desc, else: :asc
    Enum.sort_by(entries, sorter, direction)
  end

  defp decode_cursor(nil), do: 0

  defp decode_cursor(cursor) when is_binary(cursor) do
    case Integer.parse(cursor) do
      {offset, ""} when offset >= 0 -> offset
      _ -> 0
    end
  end
end
