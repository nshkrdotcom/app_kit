defmodule AppKit.Core.RuntimeReadback.Support do
  @moduledoc false

  alias AppKit.Core.PersistencePosture
  alias AppKit.Core.Substrate.{Dump, Support}

  @type error :: {:error, atom()}

  def normalize(%module{} = value), do: {:ok, value, module}

  def normalize(attrs) do
    case Support.normalize_attrs(attrs) do
      {:ok, attrs} -> {:ok, attrs, nil}
      {:error, _reason} -> {:error, :invalid_attrs}
    end
  end

  def reject_selectors(attrs, reason), do: Support.reject_selectors(attrs, reason)
  def required(attrs, key), do: Support.required(attrs, key)
  def optional(attrs, key, default \\ nil), do: Support.optional(attrs, key, default)

  def present_binary?(value), do: is_binary(value) and String.trim(value) != ""
  def safe_ref?(value), do: Support.safe_ref?(value)
  def optional_ref?(nil), do: true
  def optional_ref?(value), do: safe_ref?(value)
  def optional_map?(nil), do: true
  def optional_map?(value), do: is_map(value)
  def optional_list?(nil), do: true
  def optional_list?(value), do: is_list(value)
  def bool?(value), do: is_boolean(value)
  def optional_bool?(nil), do: true
  def optional_bool?(value), do: is_boolean(value)
  def non_neg_integer?(value), do: is_integer(value) and value >= 0
  def optional_non_neg_integer?(nil), do: true
  def optional_non_neg_integer?(value), do: non_neg_integer?(value)
  def timestamp?(%DateTime{}), do: true
  def timestamp?(value), do: present_binary?(value)
  def optional_timestamp?(nil), do: true
  def optional_timestamp?(value), do: timestamp?(value)

  def atomish?(value), do: is_atom(value) or present_binary?(value)
  def optional_atomish?(nil), do: true
  def optional_atomish?(value), do: atomish?(value)

  def nested(nil, _module), do: {:ok, nil}
  def nested(%module{} = value, module), do: {:ok, value}
  def nested(value, module) when is_map(value) or is_list(value), do: module.new(value)
  def nested(_value, _module), do: {:error, :invalid_nested}

  def nested_list(nil, _module), do: {:ok, []}

  def nested_list(values, module) when is_list(values) do
    Enum.reduce_while(values, {:ok, []}, fn value, {:ok, acc} ->
      case nested(value, module) do
        {:ok, nil} -> {:halt, {:error, :invalid_nested}}
        {:ok, struct} -> {:cont, {:ok, [struct | acc]}}
        {:error, _reason} -> {:halt, {:error, :invalid_nested}}
      end
    end)
    |> case do
      {:ok, values} -> {:ok, Enum.reverse(values)}
      error -> error
    end
  end

  def nested_list(_values, _module), do: {:error, :invalid_nested}

  def persistence_posture(attrs, component \\ :runtime_projection),
    do: PersistencePosture.resolve(component, attrs)

  def dump_struct(%_{} = value) do
    value
    |> Map.from_struct()
    |> Dump.dump_value()
    |> Dump.drop_nil_values()
  end
end
