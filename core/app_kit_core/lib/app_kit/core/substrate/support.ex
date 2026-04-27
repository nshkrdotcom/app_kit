defmodule AppKit.Core.Substrate.SelectorRejection do
  @moduledoc "Shared provider-selector rejection for AppKit substrate DTOs."

  @forbidden MapSet.new(~w[
    codex_session_id github_issue_id github_issue_number github_pr_id github_pr_number
    issue_id issue_number linear_issue_id linear_issue_number model_id pr_id pr_number
    prompt raw_prompt raw_provider_body raw_provider_payload tool_call workflow_id workspace_path
  ])

  def reject(attrs, error) when is_map(attrs) do
    if selector?(attrs), do: {:error, error}, else: :ok
  end

  defp selector?(%DateTime{}), do: false
  defp selector?(%_{} = struct), do: struct |> Map.from_struct() |> selector?()
  defp selector?(values) when is_list(values), do: Enum.any?(values, &selector?/1)

  defp selector?(%{} = map) do
    Enum.any?(map, fn {key, value} -> forbidden?(key) or selector?(value) end)
  end

  defp selector?(_value), do: false

  defp forbidden?(key) when is_atom(key), do: forbidden?(Atom.to_string(key))
  defp forbidden?(key) when is_binary(key), do: MapSet.member?(@forbidden, String.downcase(key))
  defp forbidden?(_key), do: false
end

defmodule AppKit.Core.Substrate.Redaction do
  @moduledoc "Public DTO redaction helpers for S0 values."

  def safe_ref?(value) when is_binary(value) do
    String.trim(value) != "" and not absolute_path?(value)
  end

  def safe_ref?(_value), do: false

  def absolute_path?(value) when is_binary(value) do
    String.starts_with?(value, ["/", "~/"]) or Regex.match?(~r/^[A-Za-z]:[\\\/]/, value)
  end

  def absolute_path?(_value), do: false
end

defmodule AppKit.Core.Substrate.Dump do
  @moduledoc "Stable string-keyed dump helpers for AppKit substrate DTOs."

  def dump_value(%{__struct__: module} = value) do
    if function_exported?(module, :dump, 1), do: module.dump(value), else: Map.from_struct(value)
  end

  def dump_value(values) when is_list(values), do: Enum.map(values, &dump_value/1)

  def dump_value(%{} = value),
    do: Map.new(value, fn {key, val} -> {to_string(key), dump_value(val)} end)

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
