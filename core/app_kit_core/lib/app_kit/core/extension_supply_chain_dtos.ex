defmodule AppKit.Core.ExtensionSupplyChainSupport do
  @moduledoc false

  alias AppKit.Core.{ArchivalRestoreSupport, RevisionEpochSupport}

  @spec base_binary_fields() :: [atom()]
  def base_binary_fields, do: RevisionEpochSupport.base_binary_fields()

  @spec optional_actor_fields() :: [atom()]
  def optional_actor_fields, do: RevisionEpochSupport.optional_actor_fields()

  @spec normalize_attrs(map() | keyword() | struct()) :: {:ok, map()} | {:error, :invalid_attrs}
  def normalize_attrs(attrs), do: RevisionEpochSupport.normalize_attrs(attrs)

  @spec missing_required_fields(map(), [atom()], [atom()]) :: [atom()]
  def missing_required_fields(attrs, required_binary, required_non_neg_integer),
    do:
      RevisionEpochSupport.missing_required_fields(
        attrs,
        required_binary,
        required_non_neg_integer
      )

  @spec optional_binary_fields?(map(), [atom()]) :: boolean()
  def optional_binary_fields?(attrs, fields),
    do: RevisionEpochSupport.optional_binary_fields?(attrs, fields)

  @spec present_binary?(term()) :: boolean()
  def present_binary?(value), do: RevisionEpochSupport.present_binary?(value)

  @spec sha256?(term()) :: boolean()
  def sha256?(value), do: ArchivalRestoreSupport.sha256?(value)

  @spec non_empty_binary_list?(term()) :: boolean()
  def non_empty_binary_list?(values) when is_list(values) do
    values != [] and Enum.all?(values, &present_binary?/1)
  end

  def non_empty_binary_list?(_values), do: false

  @spec binary_list?(term()) :: boolean()
  def binary_list?(values) when is_list(values), do: Enum.all?(values, &present_binary?/1)
  def binary_list?(_values), do: false
end

defmodule AppKit.Core.ExtensionPackSignatureProjection do
  @moduledoc """
  Northbound DTO for extension pack signature verification evidence.

  Contract: `AppKit.ExtensionPackSignatureProjection.v1`.
  """

  alias AppKit.Core.ExtensionSupplyChainSupport

  @contract_name "AppKit.ExtensionPackSignatureProjection.v1"
  @source_contract_name "Platform.ExtensionPackSignature.v1"
  @algorithms ["hmac-sha256", "ed25519"]
  @required_binary_fields ExtensionSupplyChainSupport.base_binary_fields() ++
                            [
                              :pack_ref,
                              :signature_ref,
                              :signing_key_ref,
                              :signature_algorithm,
                              :verification_hash,
                              :rejection_ref,
                              :source_contract_name
                            ]
  @optional_binary_fields ExtensionSupplyChainSupport.optional_actor_fields() ++
                            [:signing_key_rotation_ref]

  defstruct [
    :contract_name,
    :tenant_ref,
    :installation_ref,
    :workspace_ref,
    :project_ref,
    :environment_ref,
    :principal_ref,
    :system_actor_ref,
    :resource_ref,
    :authority_packet_ref,
    :permission_decision_ref,
    :idempotency_key,
    :trace_id,
    :correlation_id,
    :release_manifest_ref,
    :pack_ref,
    :signature_ref,
    :signing_key_ref,
    :signature_algorithm,
    :verification_hash,
    :rejection_ref,
    :signing_key_rotation_ref,
    :source_contract_name
  ]

  @type t :: %__MODULE__{}

  @spec contract_name() :: String.t()
  def contract_name, do: @contract_name

  @spec new(map() | keyword()) ::
          {:ok, t()}
          | {:error, {:missing_required_fields, [atom()]}}
          | {:error, :invalid_extension_pack_signature_projection}
  def new(attrs) do
    with {:ok, attrs} <- ExtensionSupplyChainSupport.normalize_attrs(attrs),
         [] <-
           ExtensionSupplyChainSupport.missing_required_fields(attrs, @required_binary_fields, []),
         true <-
           ExtensionSupplyChainSupport.optional_binary_fields?(attrs, @optional_binary_fields),
         true <- Map.fetch!(attrs, :signature_algorithm) in @algorithms,
         true <- ExtensionSupplyChainSupport.sha256?(Map.fetch!(attrs, :verification_hash)),
         true <- Map.fetch!(attrs, :source_contract_name) == @source_contract_name do
      {:ok, struct!(__MODULE__, Map.put(attrs, :contract_name, @contract_name))}
    else
      fields when is_list(fields) -> {:error, {:missing_required_fields, fields}}
      _error -> {:error, :invalid_extension_pack_signature_projection}
    end
  end
end

defmodule AppKit.Core.ExtensionPackBundleProjection do
  @moduledoc """
  Northbound DTO for extension pack bundle schema evidence.

  Contract: `AppKit.ExtensionPackBundleProjection.v1`.
  """

  alias AppKit.Core.ExtensionSupplyChainSupport

  @contract_name "AppKit.ExtensionPackBundleProjection.v1"
  @source_contract_name "Platform.ExtensionPackBundle.v1"
  @required_binary_fields ExtensionSupplyChainSupport.base_binary_fields() ++
                            [
                              :pack_ref,
                              :bundle_schema_version,
                              :schema_hash,
                              :validation_error_ref,
                              :source_contract_name
                            ]
  @optional_binary_fields ExtensionSupplyChainSupport.optional_actor_fields() ++ [:capability_ref]

  defstruct [
    :contract_name,
    :tenant_ref,
    :installation_ref,
    :workspace_ref,
    :project_ref,
    :environment_ref,
    :principal_ref,
    :system_actor_ref,
    :resource_ref,
    :authority_packet_ref,
    :permission_decision_ref,
    :idempotency_key,
    :trace_id,
    :correlation_id,
    :release_manifest_ref,
    :pack_ref,
    :bundle_schema_version,
    :declared_resources,
    :schema_hash,
    :validation_error_ref,
    :capability_ref,
    :source_contract_name
  ]

  @type t :: %__MODULE__{}

  @spec contract_name() :: String.t()
  def contract_name, do: @contract_name

  @spec new(map() | keyword()) ::
          {:ok, t()}
          | {:error, {:missing_required_fields, [atom()]}}
          | {:error, :invalid_extension_pack_bundle_projection}
  def new(attrs) do
    with {:ok, attrs} <- ExtensionSupplyChainSupport.normalize_attrs(attrs),
         [] <- missing_required_fields(attrs),
         true <-
           ExtensionSupplyChainSupport.optional_binary_fields?(attrs, @optional_binary_fields),
         true <- ExtensionSupplyChainSupport.sha256?(Map.fetch!(attrs, :schema_hash)),
         true <- Map.fetch!(attrs, :source_contract_name) == @source_contract_name do
      {:ok, struct!(__MODULE__, Map.put(attrs, :contract_name, @contract_name))}
    else
      fields when is_list(fields) -> {:error, {:missing_required_fields, fields}}
      _error -> {:error, :invalid_extension_pack_bundle_projection}
    end
  end

  defp missing_required_fields(attrs) do
    ExtensionSupplyChainSupport.missing_required_fields(attrs, @required_binary_fields, []) ++
      if ExtensionSupplyChainSupport.non_empty_binary_list?(Map.get(attrs, :declared_resources)) do
        []
      else
        [:declared_resources]
      end
  end
end

defmodule AppKit.Core.ConnectorAdmissionProjection do
  @moduledoc """
  Northbound DTO for connector admission and duplicate-detection evidence.

  Contract: `AppKit.ConnectorAdmissionProjection.v1`.
  """

  alias AppKit.Core.ExtensionSupplyChainSupport

  @contract_name "AppKit.ConnectorAdmissionProjection.v1"
  @source_contract_name "Platform.ConnectorAdmission.v1"
  @statuses [
    "admitted",
    "rejected_manifest_collision",
    "rejected_duplicate_capability",
    "rejected_unsafe_scope",
    "rejected_unsupported_auth_profile",
    "rejected_missing_conformance",
    "rejected_contract_mismatch",
    "rejected_tenant_mismatch",
    "rejected_durable_adapter"
  ]
  @conformance_statuses ["passed", "missing", "failed", "contract_mismatch"]
  @required_binary_fields ExtensionSupplyChainSupport.base_binary_fields() ++
                            [
                              :connector_ref,
                              :manifest_hash,
                              :contract_version,
                              :admission_idempotency_key,
                              :conformance_status,
                              :admission_status,
                              :persistence_profile,
                              :trace_ref,
                              :app_config_ref,
                              :source_contract_name
                            ]
  @required_non_neg_integer_fields [:operation_count, :trigger_count]
  @optional_binary_fields ExtensionSupplyChainSupport.optional_actor_fields() ++
                            [
                              :duplicate_of_ref
                            ]
  @forbidden_fields [
    :provider_account_id,
    "provider_account_id",
    :secret_metadata,
    "secret_metadata",
    :authorization_header,
    "authorization_header",
    :auth_header,
    "auth_header",
    :raw_secret,
    "raw_secret",
    :raw_token,
    "raw_token"
  ]

  defstruct [
    :contract_name,
    :tenant_ref,
    :installation_ref,
    :workspace_ref,
    :project_ref,
    :environment_ref,
    :principal_ref,
    :system_actor_ref,
    :resource_ref,
    :authority_packet_ref,
    :permission_decision_ref,
    :idempotency_key,
    :trace_id,
    :correlation_id,
    :release_manifest_ref,
    :connector_ref,
    :manifest_hash,
    :contract_version,
    :operation_count,
    :trigger_count,
    :auth_profiles,
    :scopes,
    :duplicate_capabilities,
    :conformance_status,
    :admission_status,
    :persistence_profile,
    :trace_ref,
    :app_config_ref,
    :admission_idempotency_key,
    :duplicate_of_ref,
    :source_contract_name
  ]

  @type t :: %__MODULE__{}

  @spec contract_name() :: String.t()
  def contract_name, do: @contract_name

  @spec new(map() | keyword()) ::
          {:ok, t()}
          | {:error, {:missing_required_fields, [atom()]}}
          | {:error, :invalid_connector_admission_projection}
  def new(attrs) do
    with true <- no_forbidden_fields?(attrs),
         {:ok, attrs} <- ExtensionSupplyChainSupport.normalize_attrs(attrs),
         [] <-
           ExtensionSupplyChainSupport.missing_required_fields(
             attrs,
             @required_binary_fields,
             @required_non_neg_integer_fields
           ),
         true <-
           ExtensionSupplyChainSupport.optional_binary_fields?(attrs, @optional_binary_fields),
         true <- Map.fetch!(attrs, :admission_status) in @statuses,
         true <- Map.fetch!(attrs, :conformance_status) in @conformance_statuses,
         true <- ExtensionSupplyChainSupport.sha256?(Map.fetch!(attrs, :manifest_hash)),
         true <- safe_lists?(attrs),
         true <- duplicate_ref_valid?(attrs),
         true <- Map.fetch!(attrs, :source_contract_name) == @source_contract_name do
      {:ok, struct!(__MODULE__, Map.put(attrs, :contract_name, @contract_name))}
    else
      fields when is_list(fields) -> {:error, {:missing_required_fields, fields}}
      _error -> {:error, :invalid_connector_admission_projection}
    end
  end

  defp duplicate_ref_valid?(%{admission_status: "rejected_duplicate_capability"} = attrs) do
    ExtensionSupplyChainSupport.present_binary?(Map.get(attrs, :duplicate_of_ref))
  end

  defp duplicate_ref_valid?(_attrs), do: true

  defp safe_lists?(attrs) do
    ExtensionSupplyChainSupport.binary_list?(Map.get(attrs, :auth_profiles)) and
      ExtensionSupplyChainSupport.binary_list?(Map.get(attrs, :scopes)) and
      ExtensionSupplyChainSupport.binary_list?(Map.get(attrs, :duplicate_capabilities))
  end

  defp no_forbidden_fields?(attrs) when is_list(attrs),
    do: attrs |> Map.new() |> no_forbidden_fields?()

  defp no_forbidden_fields?(attrs) when is_map(attrs) do
    Enum.all?(@forbidden_fields, fn field -> not Map.has_key?(attrs, field) end)
  end

  defp no_forbidden_fields?(_attrs), do: false
end
