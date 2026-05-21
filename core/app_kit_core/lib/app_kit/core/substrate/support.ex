defmodule AppKit.Core.Substrate.SelectorRejection do
  @moduledoc "Shared static-selector rejection for AppKit substrate DTOs."

  @forbidden_exact_keys MapSet.new(~w[
    access_token api_key auth_token credential credential_material credential_ref endpoint
    lower_selector prompt protocol_module provider_body provider_payload raw_endpoint raw_prompt
    raw_provider_body raw_provider_payload runtime_endpoint runtime_module secret secret_key
    secret_ref token tool_call transport_endpoint workspace_path
  ])

  @forbidden_value_fragments [
    "A2A.",
    "A2ABridge",
    "AXGrpc",
    "AgentInterop",
    "AxGrpc",
    "AxRuntime",
    "AxSidecar",
    "ControllerService.Exec",
    Enum.join(["Jido", "Integration"], "."),
    "System.cmd(\"ax\"",
    "ax serve",
    "generated A2A",
    "generated AX proto"
  ]

  @raw_endpoint_prefixes ["http://", "https://", "ws://", "wss://", "grpc://"]

  def reject(attrs, error) when is_map(attrs) do
    if selector?(attrs), do: {:error, error}, else: :ok
  end

  defp selector?(%DateTime{}), do: false
  defp selector?(%_{} = struct), do: struct |> Map.from_struct() |> selector?()
  defp selector?(values) when is_list(values), do: Enum.any?(values, &selector?/1)
  defp selector?(value) when is_binary(value), do: forbidden_value?(value)

  defp selector?(%{} = map) do
    Enum.any?(map, fn {key, value} -> forbidden?(key) or selector?(value) end)
  end

  defp selector?(_value), do: false

  defp forbidden?(key) when is_atom(key), do: forbidden?(Atom.to_string(key))

  defp forbidden?(key) when is_binary(key) do
    normalized = String.downcase(key)
    parts = String.split(normalized, "_")

    MapSet.member?(@forbidden_exact_keys, normalized) or static_selector_parts?(parts)
  end

  defp forbidden?(_key), do: false

  defp forbidden_value?(value) do
    trimmed = String.trim(value)

    String.starts_with?(trimmed, @raw_endpoint_prefixes) or
      String.contains?(trimmed, @forbidden_value_fragments)
  end

  defp static_selector_parts?(parts) do
    ("pr" in parts and Enum.any?(parts, &(&1 in ["id", "number"]))) or
      ("issue" in parts and Enum.any?(parts, &(&1 in ["id", "number"]))) or
      ("model" in parts and "id" in parts)
  end
end

defmodule AppKit.Core.Substrate.Redaction do
  @moduledoc "Public DTO redaction helpers for S0 values."

  def safe_ref?(value) when is_binary(value) do
    String.trim(value) != "" and not absolute_path?(value)
  end

  def safe_ref?(_value), do: false

  def absolute_path?(value) when is_binary(value) do
    String.starts_with?(value, ["/", "~/"]) or windows_absolute_path?(value)
  end

  def absolute_path?(_value), do: false

  defp windows_absolute_path?(<<drive, ?:, separator, _rest::binary>>) do
    (drive in ?A..?Z or drive in ?a..?z) and separator in [?\\, ?/]
  end

  defp windows_absolute_path?(_value), do: false
end

defmodule AppKit.Core.Substrate.Dump do
  @moduledoc "Stable string-keyed dump helpers for AppKit substrate DTOs."

  def dump_value(%DateTime{} = value), do: DateTime.to_iso8601(value)

  def dump_value(%{__struct__: module} = value) do
    if function_exported?(module, :dump, 1), do: module.dump(value), else: Map.from_struct(value)
  end

  def dump_value(values) when is_list(values), do: Enum.map(values, &dump_value/1)

  def dump_value(%{} = value),
    do: Map.new(value, fn {key, val} -> {to_string(key), dump_value(val)} end)

  def dump_value(nil), do: nil
  def dump_value(value) when is_boolean(value), do: value
  def dump_value(value) when is_atom(value), do: Atom.to_string(value)
  def dump_value(value), do: value

  def drop_nil_values(map), do: Map.reject(map, fn {_key, value} -> is_nil(value) end)
end

defmodule AppKit.Core.Substrate.Support do
  @moduledoc false

  alias AppKit.Core.Substrate.{Redaction, SelectorRejection}
  alias AppKit.Core.Support, as: CoreSupport

  def normalize_attrs(attrs), do: CoreSupport.normalize_attrs(attrs)
  def required(attrs, key), do: Map.get(attrs, key, Map.get(attrs, Atom.to_string(key)))

  def optional(attrs, key, default \\ nil),
    do: Map.get(attrs, key, Map.get(attrs, Atom.to_string(key), default))

  def safe_ref?(value), do: Redaction.safe_ref?(value)
  def reject_selectors(attrs, error), do: SelectorRejection.reject(attrs, error)
end
