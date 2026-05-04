defmodule AppKit.AuthorityProjections do
  @moduledoc """
  Ref-only authority projection DTOs for AppKit surfaces.
  """

  @required_refs [
    :authority_packet_ref,
    :system_authorization_ref,
    :provider_family,
    :provider_account_ref,
    :connector_instance_ref,
    :connector_binding_ref,
    :credential_handle_ref,
    :credential_lease_ref,
    :native_auth_assertion_ref,
    :target_ref,
    :attach_grant_ref,
    :operation_policy_ref,
    :evidence_ref,
    :redaction_ref
  ]

  @forbidden_material [
    :api_key,
    :auth_json,
    :authorization_header,
    :native_auth_file,
    :private_key,
    :provider_payload,
    :raw_secret,
    :raw_token,
    :system_secret,
    :target_credentials,
    :token
  ]

  @projection_fields @required_refs ++ [:trace_ref]

  @enforce_keys @required_refs
  defstruct @required_refs ++
              [
                :trace_ref,
                raw_material_present?: false,
                projection_schema: "AppKit.AuthorityProjection.v1"
              ]

  @type t :: %__MODULE__{
          authority_packet_ref: String.t(),
          system_authorization_ref: String.t(),
          provider_family: String.t(),
          provider_account_ref: String.t(),
          connector_instance_ref: String.t(),
          connector_binding_ref: String.t(),
          credential_handle_ref: String.t(),
          credential_lease_ref: String.t(),
          native_auth_assertion_ref: String.t(),
          target_ref: String.t(),
          attach_grant_ref: String.t(),
          operation_policy_ref: String.t(),
          evidence_ref: String.t(),
          redaction_ref: String.t(),
          trace_ref: String.t() | nil,
          raw_material_present?: false,
          projection_schema: String.t()
        }

  @spec required_refs() :: [atom()]
  def required_refs, do: @required_refs

  @spec forbidden_material() :: [atom()]
  def forbidden_material, do: @forbidden_material

  @spec project(map() | keyword()) ::
          {:ok, t()}
          | {:error, {:missing_required_refs, [atom()]}}
          | {:error, {:forbidden_projection_material, [atom()]}}
  def project(attrs) when is_map(attrs) or is_list(attrs) do
    attrs = normalize(attrs)

    case forbidden_material_present(attrs) do
      [] ->
        case missing_required(attrs) do
          [] -> {:ok, build_projection(attrs)}
          missing -> {:error, {:missing_required_refs, missing}}
        end

      forbidden ->
        {:error, {:forbidden_projection_material, forbidden}}
    end
  end

  @spec project!(map() | keyword()) :: t()
  def project!(attrs) do
    case project(attrs) do
      {:ok, projection} -> projection
      {:error, reason} -> raise ArgumentError, "invalid authority projection: #{inspect(reason)}"
    end
  end

  @spec dump(t()) :: map()
  def dump(%__MODULE__{} = projection) do
    projection
    |> Map.from_struct()
    |> Map.new(fn {key, value} -> {to_string(key), value} end)
  end

  @spec operator_dto(t()) :: map()
  def operator_dto(%__MODULE__{} = projection) do
    projection
    |> dump()
    |> Map.take(Enum.map(@projection_fields, &Atom.to_string/1))
    |> Map.put("projection_schema", projection.projection_schema)
    |> Map.put("raw_material_present?", false)
  end

  defp build_projection(attrs) do
    attrs =
      attrs
      |> Map.take(@projection_fields)
      |> Map.put(:raw_material_present?, false)
      |> Map.put(:projection_schema, "AppKit.AuthorityProjection.v1")

    struct!(__MODULE__, attrs)
  end

  defp missing_required(attrs) do
    Enum.reject(@required_refs, &present?(Map.get(attrs, &1)))
  end

  defp forbidden_material_present(attrs) do
    Enum.filter(@forbidden_material, &Map.has_key?(attrs, &1))
  end

  defp normalize(attrs) when is_list(attrs), do: attrs |> Map.new() |> normalize()

  defp normalize(attrs) when is_map(attrs) do
    Map.new(attrs, fn {key, value} -> {normalize_key(key), value} end)
  end

  defp normalize_key(key) when is_atom(key), do: key

  defp normalize_key(key) when is_binary(key) do
    Enum.find(@projection_fields ++ @forbidden_material, key, fn candidate ->
      Atom.to_string(candidate) == key
    end)
  end

  defp present?(value) when is_binary(value), do: String.trim(value) != ""
  defp present?(value), do: not is_nil(value)
end
