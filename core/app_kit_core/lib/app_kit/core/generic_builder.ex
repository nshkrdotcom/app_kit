defmodule AppKit.Core.GenericBuilder do
  @moduledoc false

  alias AppKit.Core.Support

  @raw_secret_fields [
    "api" <> "_key",
    "access" <> "_token",
    "refresh" <> "_token",
    "secret",
    "private" <> "_key",
    "credential" <> "_body"
  ]

  @spec build(module(), map() | keyword(), [atom()], keyword()) ::
          {:ok, struct()} | {:error, term()}
  def build(module, attrs, required_fields, opts \\ []) do
    with {:ok, attrs} <- Support.normalize_attrs(attrs),
         :ok <- reject_forbidden_fields(attrs),
         :ok <- require_fields(attrs, required_fields),
         :ok <- validate_role_fields(attrs),
         :ok <- validate_custom(attrs, Keyword.get(opts, :validate, [])) do
      {:ok, struct(module, attrs)}
    end
  end

  @spec reject_forbidden_fields(map()) :: :ok | {:error, term()}
  def reject_forbidden_fields(attrs) when is_map(attrs) do
    case Enum.find(Map.keys(attrs), &forbidden_field?/1) do
      nil -> :ok
      field -> {:error, {:forbidden_generic_request_field, field}}
    end
  end

  defp validate_role_fields(attrs) do
    attrs
    |> Enum.filter(fn {key, _value} -> role_field?(key) end)
    |> Enum.find(fn {_key, value} -> not valid_role_ref?(value) end)
    |> case do
      nil -> :ok
      {key, value} -> {:error, {:invalid_role_ref, key, value}}
    end
  end

  defp require_fields(attrs, fields) do
    case Enum.find(fields, &(not present?(Map.get(attrs, &1)))) do
      nil -> :ok
      field -> {:error, {:missing_required_field, field}}
    end
  end

  defp validate_custom(attrs, validators) do
    Enum.reduce_while(validators, :ok, fn validator, :ok ->
      case validator.(attrs) do
        :ok -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp present?(value) when is_binary(value), do: String.trim(value) != ""
  defp present?(value), do: not is_nil(value)

  defp forbidden_field?(field) when is_atom(field),
    do: field |> Atom.to_string() |> forbidden_name?()

  defp forbidden_field?(field) when is_binary(field), do: forbidden_name?(field)
  defp forbidden_field?(_field), do: false

  defp forbidden_name?(name) do
    name == "binding_ref" or String.ends_with?(name, "_binding_ref") or name in @raw_secret_fields
  end

  defp role_field?(field) when is_atom(field), do: field |> Atom.to_string() |> role_name?()
  defp role_field?(field) when is_binary(field), do: role_name?(field)
  defp role_field?(_field), do: false

  defp role_name?(name), do: String.ends_with?(name, "_role_ref")

  defp valid_role_ref?(value) when is_atom(value), do: true

  defp valid_role_ref?(value) when is_binary(value) do
    value != "" and not String.starts_with?(value, "binding://")
  end

  defp valid_role_ref?(_value), do: false
end

defmodule AppKit.Core.GenericStruct do
  @moduledoc false

  defmacro __using__(opts) do
    required_fields = Keyword.fetch!(opts, :required)
    optional_fields = Keyword.get(opts, :optional, [])
    validators = Keyword.get(opts, :validate, [])

    optional_field_names =
      Enum.map(optional_fields, fn
        {field, _default} -> field
        field -> field
      end)

    quote bind_quoted: [
            optional_fields: optional_fields,
            optional_field_names: optional_field_names,
            required_fields: required_fields,
            validators: validators
          ] do
      alias AppKit.Core.GenericBuilder

      @generic_required_fields required_fields
      @generic_optional_field_names optional_field_names
      @generic_validators validators
      @enforce_keys required_fields
      defstruct required_fields ++ optional_fields

      @type t :: %__MODULE__{}

      @spec fields() :: [atom()]
      def fields, do: @generic_required_fields ++ @generic_optional_field_names

      @spec required_fields() :: [atom()]
      def required_fields, do: @generic_required_fields

      @spec new(map() | keyword()) :: {:ok, t()} | {:error, term()}
      def new(attrs),
        do:
          GenericBuilder.build(__MODULE__, attrs, @generic_required_fields,
            validate: @generic_validators
          )
    end
  end
end
