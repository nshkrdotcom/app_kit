defmodule AppKit.Core.Support do
  @moduledoc false

  @spec normalize_attrs(map() | keyword()) :: {:ok, map()} | {:error, :invalid_attrs}
  def normalize_attrs(attrs) when is_list(attrs), do: {:ok, Map.new(attrs)}

  def normalize_attrs(attrs) when is_map(attrs) do
    if Map.has_key?(attrs, :__struct__) do
      {:ok, Map.from_struct(attrs)}
    else
      {:ok, attrs}
    end
  end

  def normalize_attrs(_), do: {:error, :invalid_attrs}

  @spec present_binary?(term()) :: boolean()
  def present_binary?(value), do: is_binary(value) and byte_size(value) > 0

  @spec optional_binary?(term()) :: boolean()
  def optional_binary?(nil), do: true
  def optional_binary?(value), do: is_binary(value)

  @spec optional_map?(term()) :: boolean()
  def optional_map?(nil), do: true
  def optional_map?(value), do: is_map(value)

  @spec optional_boolean?(term()) :: boolean()
  def optional_boolean?(nil), do: true
  def optional_boolean?(value), do: is_boolean(value)

  @spec optional_non_neg_integer?(term()) :: boolean()
  def optional_non_neg_integer?(nil), do: true
  def optional_non_neg_integer?(value), do: is_integer(value) and value >= 0

  @spec positive_integer?(term()) :: boolean()
  def positive_integer?(value), do: is_integer(value) and value > 0

  @spec optional_datetime?(term()) :: boolean()
  def optional_datetime?(nil), do: true
  def optional_datetime?(%DateTime{}), do: true
  def optional_datetime?(_), do: false

  @spec atom_or_binary?(term()) :: boolean()
  def atom_or_binary?(value), do: is_atom(value) or is_binary(value)

  @spec optional_atom_or_binary?(term()) :: boolean()
  def optional_atom_or_binary?(nil), do: true
  def optional_atom_or_binary?(value), do: atom_or_binary?(value)

  @spec enum?(term(), [term()]) :: boolean()
  def enum?(value, allowed), do: value in allowed

  @spec optional_enum?(term(), [term()]) :: boolean()
  def optional_enum?(nil, _allowed), do: true
  def optional_enum?(value, allowed), do: enum?(value, allowed)

  @spec list_of?(term(), (term() -> boolean())) :: boolean()
  def list_of?(value, predicate) when is_list(value), do: Enum.all?(value, predicate)
  def list_of?(_value, _predicate), do: false

  @spec optional_list_of?(term(), (term() -> boolean())) :: boolean()
  def optional_list_of?(nil, _predicate), do: true
  def optional_list_of?(value, predicate), do: list_of?(value, predicate)

  @spec string_key_boolean_map?(term()) :: boolean()
  def string_key_boolean_map?(value) when is_map(value) do
    Enum.all?(value, fn
      {key, flag} when is_binary(key) and is_boolean(flag) -> true
      _other -> false
    end)
  end

  def string_key_boolean_map?(_value), do: false

  @spec nested_struct(term(), module()) :: {:ok, struct() | nil} | {:error, :invalid_nested}
  def nested_struct(nil, _module), do: {:ok, nil}

  def nested_struct(value, module) do
    cond do
      is_struct(value, module) ->
        {:ok, value}

      is_map(value) or is_list(value) ->
        module.new(value)

      true ->
        {:error, :invalid_nested}
    end
  end

  @spec nested_structs(term(), module()) :: {:ok, [struct()]} | {:error, :invalid_nested}
  def nested_structs(values, module) when is_list(values) do
    Enum.reduce_while(values, {:ok, []}, fn value, {:ok, acc} ->
      case nested_struct(value, module) do
        {:ok, nil} -> {:halt, {:error, :invalid_nested}}
        {:ok, struct} -> {:cont, {:ok, [struct | acc]}}
        {:error, _reason} -> {:halt, {:error, :invalid_nested}}
      end
    end)
    |> case do
      {:ok, structs} -> {:ok, Enum.reverse(structs)}
      error -> error
    end
  end

  def nested_structs(_values, _module), do: {:error, :invalid_nested}
end
