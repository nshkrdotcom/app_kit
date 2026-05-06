defmodule AppKit.ModelSurface.ModelProfileProjection do
  @moduledoc "Model profile inventory projection."
  @enforce_keys [
    :model_profile_ref,
    :provider_ref,
    :capability_refs,
    :readiness_ref,
    :operation_classes,
    :cost_posture_ref,
    :source_status,
    :operation_policy_ref
  ]
  defstruct @enforce_keys
  @type t :: %__MODULE__{}
end

defmodule AppKit.ModelSurface.EndpointProfileProjection do
  @moduledoc "Endpoint profile inventory projection."
  @enforce_keys [
    :endpoint_profile_ref,
    :endpoint_ref,
    :endpoint_identity_ref,
    :provider_credential_ref,
    :readiness_ref,
    :source_status,
    :model_profile_refs
  ]
  defstruct @enforce_keys
  @type t :: %__MODULE__{}
end

defmodule AppKit.ModelSurface.CatalogProjection do
  @moduledoc "Product-safe model and endpoint catalog projection."
  @enforce_keys [
    :tenant_ref,
    :authority_ref,
    :model_profiles,
    :endpoint_profiles,
    :trace_refs,
    :redaction_posture
  ]
  defstruct @enforce_keys
  @type t :: %__MODULE__{}
end

defmodule AppKit.ModelSurface.AdmissionRequest do
  @moduledoc "Model profile admission request."
  @enforce_keys [
    :request_ref,
    :tenant_ref,
    :authority_ref,
    :model_profile_ref,
    :endpoint_profile_ref,
    :operation_policy_ref,
    :trace_refs
  ]
  defstruct @enforce_keys
  @type t :: %__MODULE__{}
end

defmodule AppKit.ModelSurface do
  @moduledoc """
  DTO-only model and endpoint inventory surface.
  """

  alias AppKit.ModelSurface.{
    AdmissionRequest,
    CatalogProjection,
    EndpointProfileProjection,
    ModelProfileProjection
  }

  @source_statuses [:live, :mock, :self_hosted]
  @operation_classes [
    :propose,
    :evaluate,
    :route,
    :verify,
    :embed,
    :rerank,
    :summarize,
    :reflect,
    :tool_call
  ]
  @raw_keys [
    :api_key,
    :auth_header,
    :body,
    :model_output,
    :provider_payload,
    :raw_body,
    :raw_payload,
    :secret,
    :token,
    "api_key",
    "auth_header",
    "body",
    "model_output",
    "provider_payload",
    "raw_body",
    "raw_payload",
    "secret",
    "token"
  ]

  @spec model_profile(map()) :: {:ok, ModelProfileProjection.t()} | {:error, term()}
  def model_profile(attrs) when is_map(attrs) do
    with :ok <- reject_raw(attrs),
         :ok <-
           required_strings(attrs, [
             :model_profile_ref,
             :provider_ref,
             :readiness_ref,
             :cost_posture_ref,
             :operation_policy_ref
           ]),
         {:ok, capability_refs} <- string_list(attrs, :capability_refs, []),
         {:ok, operation_classes} <- operation_classes(attrs),
         {:ok, source_status} <- source_status(attrs) do
      {:ok,
       %ModelProfileProjection{
         model_profile_ref: fetch!(attrs, :model_profile_ref),
         provider_ref: fetch!(attrs, :provider_ref),
         capability_refs: capability_refs,
         readiness_ref: fetch!(attrs, :readiness_ref),
         operation_classes: operation_classes,
         cost_posture_ref: fetch!(attrs, :cost_posture_ref),
         source_status: source_status,
         operation_policy_ref: fetch!(attrs, :operation_policy_ref)
       }}
    end
  end

  def model_profile(_attrs), do: {:error, :invalid_model_profile_projection}

  @spec endpoint_profile(map()) :: {:ok, EndpointProfileProjection.t()} | {:error, term()}
  def endpoint_profile(attrs) when is_map(attrs) do
    with :ok <- reject_raw(attrs),
         :ok <-
           required_strings(attrs, [
             :endpoint_profile_ref,
             :endpoint_ref,
             :endpoint_identity_ref,
             :provider_credential_ref,
             :readiness_ref
           ]),
         :ok <- separated_endpoint_identity(attrs),
         {:ok, source_status} <- source_status(attrs),
         {:ok, model_profile_refs} <- string_list(attrs, :model_profile_refs, []) do
      {:ok,
       %EndpointProfileProjection{
         endpoint_profile_ref: fetch!(attrs, :endpoint_profile_ref),
         endpoint_ref: fetch!(attrs, :endpoint_ref),
         endpoint_identity_ref: fetch!(attrs, :endpoint_identity_ref),
         provider_credential_ref: fetch!(attrs, :provider_credential_ref),
         readiness_ref: fetch!(attrs, :readiness_ref),
         source_status: source_status,
         model_profile_refs: model_profile_refs
       }}
    end
  end

  def endpoint_profile(_attrs), do: {:error, :invalid_endpoint_profile_projection}

  @spec catalog_projection(map()) :: {:ok, CatalogProjection.t()} | {:error, term()}
  def catalog_projection(attrs) when is_map(attrs) do
    with :ok <- reject_raw(attrs),
         :ok <- required_strings(attrs, [:tenant_ref, :authority_ref]),
         {:ok, model_profiles} <- map_each(attrs, :model_profiles, &model_profile/1),
         {:ok, endpoint_profiles} <- map_each(attrs, :endpoint_profiles, &endpoint_profile/1),
         {:ok, trace_refs} <- string_list(attrs, :trace_refs, []) do
      {:ok,
       %CatalogProjection{
         tenant_ref: fetch!(attrs, :tenant_ref),
         authority_ref: fetch!(attrs, :authority_ref),
         model_profiles: model_profiles,
         endpoint_profiles: endpoint_profiles,
         trace_refs: trace_refs,
         redaction_posture: :refs_only
       }}
    end
  end

  def catalog_projection(_attrs), do: {:error, :invalid_model_catalog_projection}

  @spec admission_request(map()) :: {:ok, AdmissionRequest.t()} | {:error, term()}
  def admission_request(attrs) when is_map(attrs) do
    with :ok <- reject_raw(attrs),
         :ok <-
           required_strings(attrs, [
             :request_ref,
             :tenant_ref,
             :authority_ref,
             :model_profile_ref,
             :endpoint_profile_ref,
             :operation_policy_ref
           ]),
         {:ok, trace_refs} <- string_list(attrs, :trace_refs, []) do
      {:ok,
       %AdmissionRequest{
         request_ref: fetch!(attrs, :request_ref),
         tenant_ref: fetch!(attrs, :tenant_ref),
         authority_ref: fetch!(attrs, :authority_ref),
         model_profile_ref: fetch!(attrs, :model_profile_ref),
         endpoint_profile_ref: fetch!(attrs, :endpoint_profile_ref),
         operation_policy_ref: fetch!(attrs, :operation_policy_ref),
         trace_refs: trace_refs
       }}
    end
  end

  def admission_request(_attrs), do: {:error, :invalid_model_admission_request}

  defp map_each(attrs, field, fun) do
    attrs
    |> fetch(field, [])
    |> List.wrap()
    |> Enum.reduce_while({:ok, []}, fn item, {:ok, acc} ->
      case fun.(item) do
        {:ok, projected} -> {:cont, {:ok, [projected | acc]}}
        {:error, reason} -> {:halt, {:error, {field, reason}}}
      end
    end)
    |> case do
      {:ok, []} -> {:error, {:missing_model_surface_items, field}}
      {:ok, values} -> {:ok, Enum.reverse(values)}
      error -> error
    end
  end

  defp operation_classes(attrs) do
    values = fetch(attrs, :operation_classes, [])

    if is_list(values) and values != [] and Enum.all?(values, &(&1 in @operation_classes)) do
      {:ok, values}
    else
      {:error, :invalid_operation_classes}
    end
  end

  defp source_status(attrs) do
    value = fetch(attrs, :source_status)
    if value in @source_statuses, do: {:ok, value}, else: {:error, :invalid_source_status}
  end

  defp separated_endpoint_identity(attrs) do
    if fetch!(attrs, :endpoint_identity_ref) == fetch!(attrs, :provider_credential_ref) do
      {:error, :endpoint_identity_must_not_equal_provider_credential}
    else
      :ok
    end
  end

  defp required_strings(attrs, fields) do
    case Enum.find(fields, &(present_string?(fetch(attrs, &1)) == false)) do
      nil -> :ok
      field -> {:error, {:missing_required_ref, field}}
    end
  end

  defp string_list(attrs, field, default) do
    values = fetch(attrs, field, default)

    if is_list(values) and Enum.all?(values, &present_string?/1) do
      {:ok, values}
    else
      {:error, {:invalid_ref_list, field}}
    end
  end

  defp reject_raw(value) do
    case raw_key(value) do
      nil -> :ok
      key -> {:error, {:raw_model_surface_payload_forbidden, key}}
    end
  end

  defp raw_key(%_struct{} = value), do: value |> Map.from_struct() |> raw_key()

  defp raw_key(value) when is_map(value) do
    Enum.find_value(value, fn {key, nested} ->
      if key in @raw_keys, do: key, else: raw_key(nested)
    end)
  end

  defp raw_key(value) when is_list(value), do: Enum.find_value(value, &raw_key/1)
  defp raw_key(_value), do: nil

  defp fetch!(attrs, field), do: fetch(attrs, field)

  defp fetch(attrs, field, default \\ nil) do
    string_field = Atom.to_string(field)

    cond do
      Map.has_key?(attrs, field) -> Map.fetch!(attrs, field)
      Map.has_key?(attrs, string_field) -> Map.fetch!(attrs, string_field)
      true -> default
    end
  end

  defp present_string?(value), do: is_binary(value) and String.trim(value) != ""
end
