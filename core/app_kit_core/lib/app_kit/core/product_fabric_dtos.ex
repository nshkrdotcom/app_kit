defmodule AppKit.Core.ProductFabricSupport do
  @moduledoc false

  @base_binary_fields [
    :tenant_ref,
    :installation_ref,
    :workspace_ref,
    :project_ref,
    :environment_ref,
    :resource_ref,
    :authority_packet_ref,
    :permission_decision_ref,
    :idempotency_key,
    :trace_id,
    :correlation_id,
    :release_manifest_ref
  ]

  @optional_actor_fields [:principal_ref, :system_actor_ref]

  def base_binary_fields, do: @base_binary_fields
  def optional_actor_fields, do: @optional_actor_fields

  def normalize_attrs(attrs) when is_list(attrs), do: {:ok, Map.new(attrs)}

  def normalize_attrs(attrs) when is_map(attrs) do
    if Map.has_key?(attrs, :__struct__) do
      {:ok, Map.from_struct(attrs)}
    else
      {:ok, attrs}
    end
  end

  def normalize_attrs(_attrs), do: {:error, :invalid_attrs}

  def missing_required_fields(attrs, required_binary, required_lists, required_positive_integers) do
    binary_missing =
      required_binary
      |> Enum.reject(fn field -> present_binary?(Map.get(attrs, field)) end)

    list_missing =
      required_lists
      |> Enum.reject(fn field -> non_empty_string_list?(Map.get(attrs, field)) end)

    integer_missing =
      required_positive_integers
      |> Enum.reject(fn field -> positive_integer?(Map.get(attrs, field)) end)

    actor_missing =
      if present_binary?(Map.get(attrs, :principal_ref)) or
           present_binary?(Map.get(attrs, :system_actor_ref)) do
        []
      else
        [:principal_ref_or_system_actor_ref]
      end

    binary_missing ++ actor_missing ++ list_missing ++ integer_missing
  end

  def present_binary?(value), do: is_binary(value) and byte_size(value) > 0
  def optional_binary?(nil), do: true
  def optional_binary?(value), do: present_binary?(value)

  def string_list?(values) when is_list(values), do: Enum.all?(values, &present_binary?/1)
  def string_list?(_values), do: false

  def non_empty_string_list?([_ | _] = values), do: string_list?(values)
  def non_empty_string_list?(_values), do: false

  def positive_integer?(value), do: is_integer(value) and value > 0

  def optional_binary_fields?(attrs, fields) do
    Enum.all?(fields, fn field -> optional_binary?(Map.get(attrs, field)) end)
  end

  def optional_string_lists?(attrs, fields) do
    Enum.all?(fields, fn field ->
      value = Map.get(attrs, field, [])
      is_nil(value) or string_list?(value)
    end)
  end
end

defmodule AppKit.Core.ProductTenantContext do
  @moduledoc """
  Product tenant context for atomic multi-product tenant switches.

  `AppKit.ProductTenantContext.v1` requires the product shell to replace tenant,
  authority, trace, schema, session, and capability context together.
  """

  alias AppKit.Core.ProductFabricSupport

  @contract_name "AppKit.ProductTenantContext.v1"
  @required_binary_fields ProductFabricSupport.base_binary_fields() ++
                            [
                              :from_tenant_ref,
                              :to_tenant_ref,
                              :product_ref,
                              :session_ref
                            ]
  @required_list_fields [:allowed_product_capabilities]
  @required_positive_integer_fields [:context_revision]
  @optional_binary_fields ProductFabricSupport.optional_actor_fields() ++
                            [:feature_flag_set_ref, :product_display_metadata_ref]

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
    :from_tenant_ref,
    :to_tenant_ref,
    :product_ref,
    :session_ref,
    :context_revision,
    :allowed_product_capabilities,
    :feature_flag_set_ref,
    :product_display_metadata_ref
  ]

  @type t :: %__MODULE__{}

  @spec new(map() | keyword()) ::
          {:ok, t()}
          | {:error, {:missing_required_fields, [atom()]}}
          | {:error, :invalid_product_tenant_context}
  def new(attrs) do
    with {:ok, attrs} <- ProductFabricSupport.normalize_attrs(attrs),
         [] <-
           ProductFabricSupport.missing_required_fields(
             attrs,
             @required_binary_fields,
             @required_list_fields,
             @required_positive_integer_fields
           ),
         true <- ProductFabricSupport.optional_binary_fields?(attrs, @optional_binary_fields) do
      {:ok, build(attrs)}
    else
      fields when is_list(fields) -> {:error, {:missing_required_fields, fields}}
      _error -> {:error, :invalid_product_tenant_context}
    end
  end

  defp build(attrs) do
    %__MODULE__{
      contract_name: @contract_name,
      tenant_ref: Map.fetch!(attrs, :tenant_ref),
      installation_ref: Map.fetch!(attrs, :installation_ref),
      workspace_ref: Map.fetch!(attrs, :workspace_ref),
      project_ref: Map.fetch!(attrs, :project_ref),
      environment_ref: Map.fetch!(attrs, :environment_ref),
      principal_ref: Map.get(attrs, :principal_ref),
      system_actor_ref: Map.get(attrs, :system_actor_ref),
      resource_ref: Map.fetch!(attrs, :resource_ref),
      authority_packet_ref: Map.fetch!(attrs, :authority_packet_ref),
      permission_decision_ref: Map.fetch!(attrs, :permission_decision_ref),
      idempotency_key: Map.fetch!(attrs, :idempotency_key),
      trace_id: Map.fetch!(attrs, :trace_id),
      correlation_id: Map.fetch!(attrs, :correlation_id),
      release_manifest_ref: Map.fetch!(attrs, :release_manifest_ref),
      from_tenant_ref: Map.fetch!(attrs, :from_tenant_ref),
      to_tenant_ref: Map.fetch!(attrs, :to_tenant_ref),
      product_ref: Map.fetch!(attrs, :product_ref),
      session_ref: Map.fetch!(attrs, :session_ref),
      context_revision: Map.fetch!(attrs, :context_revision),
      allowed_product_capabilities: Map.fetch!(attrs, :allowed_product_capabilities),
      feature_flag_set_ref: Map.get(attrs, :feature_flag_set_ref),
      product_display_metadata_ref: Map.get(attrs, :product_display_metadata_ref)
    }
  end
end

defmodule AppKit.Core.ProductCertification do
  @moduledoc """
  AppKit-only product certification report.

  `AppKit.ProductCertification.v1` proves a product is certified through AppKit
  DTOs, schema registry entries, no-bypass scans, and Stack Lab scenario sets.
  """

  alias AppKit.Core.ProductFabricSupport

  @contract_name "AppKit.ProductCertification.v1"
  @required_binary_fields ProductFabricSupport.base_binary_fields() ++
                            [
                              :product_ref,
                              :certification_profile,
                              :sdk_version,
                              :no_bypass_scan_ref,
                              :proof_bundle_ref
                            ]
  @required_list_fields [:schema_versions, :scenario_set, :appkit_surface_refs]
  @optional_binary_fields ProductFabricSupport.optional_actor_fields() ++
                            [:feature_flag_set_ref, :product_display_metadata_ref]
  @optional_list_fields [:bypass_import_refs]

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
    :product_ref,
    :certification_profile,
    :sdk_version,
    :schema_versions,
    :scenario_set,
    :no_bypass_scan_ref,
    :proof_bundle_ref,
    :appkit_surface_refs,
    :bypass_import_refs,
    :feature_flag_set_ref,
    :product_display_metadata_ref
  ]

  @type t :: %__MODULE__{}

  @spec new(map() | keyword()) ::
          {:ok, t()}
          | {:error, {:missing_required_fields, [atom()]}}
          | {:error, {:forbidden_bypass_refs, [String.t()]}}
          | {:error, :invalid_product_certification}
  def new(attrs) do
    with {:ok, attrs} <- ProductFabricSupport.normalize_attrs(attrs),
         [] <-
           ProductFabricSupport.missing_required_fields(
             attrs,
             @required_binary_fields,
             @required_list_fields,
             []
           ),
         true <- ProductFabricSupport.optional_binary_fields?(attrs, @optional_binary_fields),
         true <- ProductFabricSupport.optional_string_lists?(attrs, @optional_list_fields),
         :ok <- reject_bypass_refs(attrs) do
      {:ok, build(attrs)}
    else
      fields when is_list(fields) and fields != [] ->
        {:error, {:missing_required_fields, fields}}

      {:error, _reason} = error ->
        error

      _error ->
        {:error, :invalid_product_certification}
    end
  end

  defp reject_bypass_refs(attrs) do
    case Map.get(attrs, :bypass_import_refs, []) do
      [] -> :ok
      bypass_refs when is_list(bypass_refs) -> {:error, {:forbidden_bypass_refs, bypass_refs}}
      _other -> {:error, :invalid_product_certification}
    end
  end

  defp build(attrs) do
    %__MODULE__{
      contract_name: @contract_name,
      tenant_ref: Map.fetch!(attrs, :tenant_ref),
      installation_ref: Map.fetch!(attrs, :installation_ref),
      workspace_ref: Map.fetch!(attrs, :workspace_ref),
      project_ref: Map.fetch!(attrs, :project_ref),
      environment_ref: Map.fetch!(attrs, :environment_ref),
      principal_ref: Map.get(attrs, :principal_ref),
      system_actor_ref: Map.get(attrs, :system_actor_ref),
      resource_ref: Map.fetch!(attrs, :resource_ref),
      authority_packet_ref: Map.fetch!(attrs, :authority_packet_ref),
      permission_decision_ref: Map.fetch!(attrs, :permission_decision_ref),
      idempotency_key: Map.fetch!(attrs, :idempotency_key),
      trace_id: Map.fetch!(attrs, :trace_id),
      correlation_id: Map.fetch!(attrs, :correlation_id),
      release_manifest_ref: Map.fetch!(attrs, :release_manifest_ref),
      product_ref: Map.fetch!(attrs, :product_ref),
      certification_profile: Map.fetch!(attrs, :certification_profile),
      sdk_version: Map.fetch!(attrs, :sdk_version),
      schema_versions: Map.fetch!(attrs, :schema_versions),
      scenario_set: Map.fetch!(attrs, :scenario_set),
      no_bypass_scan_ref: Map.fetch!(attrs, :no_bypass_scan_ref),
      proof_bundle_ref: Map.fetch!(attrs, :proof_bundle_ref),
      appkit_surface_refs: Map.fetch!(attrs, :appkit_surface_refs),
      bypass_import_refs: Map.get(attrs, :bypass_import_refs, []),
      feature_flag_set_ref: Map.get(attrs, :feature_flag_set_ref),
      product_display_metadata_ref: Map.get(attrs, :product_display_metadata_ref)
    }
  end
end

defmodule AppKit.Core.ProductBoundaryNoBypassScan do
  @moduledoc """
  Product boundary no-bypass scan report.

  `AppKit.ProductBoundaryNoBypassScan.v1` is valid only when forbidden imports
  and violation refs are empty. Violations are returned as explicit failures.
  """

  alias AppKit.Core.ProductFabricSupport

  @contract_name "AppKit.ProductBoundaryNoBypassScan.v1"
  @required_binary_fields ProductFabricSupport.base_binary_fields() ++ [:product_ref, :scan_ref]
  @required_list_fields [:allowed_appkit_facades, :source_paths]
  @optional_binary_fields ProductFabricSupport.optional_actor_fields()
  @optional_list_fields [:forbidden_imports, :violation_refs]

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
    :product_ref,
    :scan_ref,
    :forbidden_imports,
    :allowed_appkit_facades,
    :source_paths,
    :violation_refs
  ]

  @type t :: %__MODULE__{}

  @spec new(map() | keyword()) ::
          {:ok, t()}
          | {:error, {:missing_required_fields, [atom()]}}
          | {:error, {:forbidden_imports_present, [String.t()]}}
          | {:error, :invalid_product_boundary_no_bypass_scan}
  def new(attrs) do
    with {:ok, attrs} <- ProductFabricSupport.normalize_attrs(attrs),
         [] <-
           ProductFabricSupport.missing_required_fields(
             attrs,
             @required_binary_fields,
             @required_list_fields,
             []
           ),
         true <- ProductFabricSupport.optional_binary_fields?(attrs, @optional_binary_fields),
         true <- ProductFabricSupport.optional_string_lists?(attrs, @optional_list_fields),
         :ok <- reject_forbidden_imports(attrs) do
      {:ok, build(attrs)}
    else
      fields when is_list(fields) and fields != [] ->
        {:error, {:missing_required_fields, fields}}

      {:error, _reason} = error ->
        error

      _error ->
        {:error, :invalid_product_boundary_no_bypass_scan}
    end
  end

  defp reject_forbidden_imports(attrs) do
    case Map.get(attrs, :forbidden_imports, []) do
      [] ->
        :ok

      forbidden_imports when is_list(forbidden_imports) ->
        {:error, {:forbidden_imports_present, forbidden_imports}}

      _other ->
        {:error, :invalid_product_boundary_no_bypass_scan}
    end
  end

  defp build(attrs) do
    %__MODULE__{
      contract_name: @contract_name,
      tenant_ref: Map.fetch!(attrs, :tenant_ref),
      installation_ref: Map.fetch!(attrs, :installation_ref),
      workspace_ref: Map.fetch!(attrs, :workspace_ref),
      project_ref: Map.fetch!(attrs, :project_ref),
      environment_ref: Map.fetch!(attrs, :environment_ref),
      principal_ref: Map.get(attrs, :principal_ref),
      system_actor_ref: Map.get(attrs, :system_actor_ref),
      resource_ref: Map.fetch!(attrs, :resource_ref),
      authority_packet_ref: Map.fetch!(attrs, :authority_packet_ref),
      permission_decision_ref: Map.fetch!(attrs, :permission_decision_ref),
      idempotency_key: Map.fetch!(attrs, :idempotency_key),
      trace_id: Map.fetch!(attrs, :trace_id),
      correlation_id: Map.fetch!(attrs, :correlation_id),
      release_manifest_ref: Map.fetch!(attrs, :release_manifest_ref),
      product_ref: Map.fetch!(attrs, :product_ref),
      scan_ref: Map.fetch!(attrs, :scan_ref),
      forbidden_imports: Map.get(attrs, :forbidden_imports, []),
      allowed_appkit_facades: Map.fetch!(attrs, :allowed_appkit_facades),
      source_paths: Map.fetch!(attrs, :source_paths),
      violation_refs: Map.get(attrs, :violation_refs, [])
    }
  end
end

defmodule AppKit.Core.FullProductFabricSmoke do
  @moduledoc """
  End-to-end product fabric smoke report.

  `AppKit.FullProductFabricSmoke.v1` proves multiple products can use AppKit
  surfaces across tenants with authority, workflow, schema, and no-bypass
  evidence.
  """

  alias AppKit.Core.ProductFabricSupport

  @contract_name "AppKit.FullProductFabricSmoke.v1"
  @required_binary_fields ProductFabricSupport.base_binary_fields() ++
                            [:proof_bundle_ref, :no_bypass_scan_ref]
  @required_list_fields [
    :product_refs,
    :tenant_refs,
    :scenario_set,
    :sdk_versions,
    :schema_versions,
    :authority_refs,
    :workflow_refs
  ]
  @optional_binary_fields ProductFabricSupport.optional_actor_fields() ++ [:sample_dataset_ref]

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
    :product_refs,
    :tenant_refs,
    :scenario_set,
    :sdk_versions,
    :schema_versions,
    :authority_refs,
    :workflow_refs,
    :proof_bundle_ref,
    :no_bypass_scan_ref,
    :sample_dataset_ref
  ]

  @type t :: %__MODULE__{}

  @spec new(map() | keyword()) ::
          {:ok, t()}
          | {:error, {:missing_required_fields, [atom()]}}
          | {:error, :invalid_full_product_fabric_smoke}
  def new(attrs) do
    with {:ok, attrs} <- ProductFabricSupport.normalize_attrs(attrs),
         [] <-
           ProductFabricSupport.missing_required_fields(
             attrs,
             @required_binary_fields,
             @required_list_fields,
             []
           ),
         true <- ProductFabricSupport.optional_binary_fields?(attrs, @optional_binary_fields) do
      {:ok, build(attrs)}
    else
      fields when is_list(fields) -> {:error, {:missing_required_fields, fields}}
      _error -> {:error, :invalid_full_product_fabric_smoke}
    end
  end

  defp build(attrs) do
    %__MODULE__{
      contract_name: @contract_name,
      tenant_ref: Map.fetch!(attrs, :tenant_ref),
      installation_ref: Map.fetch!(attrs, :installation_ref),
      workspace_ref: Map.fetch!(attrs, :workspace_ref),
      project_ref: Map.fetch!(attrs, :project_ref),
      environment_ref: Map.fetch!(attrs, :environment_ref),
      principal_ref: Map.get(attrs, :principal_ref),
      system_actor_ref: Map.get(attrs, :system_actor_ref),
      resource_ref: Map.fetch!(attrs, :resource_ref),
      authority_packet_ref: Map.fetch!(attrs, :authority_packet_ref),
      permission_decision_ref: Map.fetch!(attrs, :permission_decision_ref),
      idempotency_key: Map.fetch!(attrs, :idempotency_key),
      trace_id: Map.fetch!(attrs, :trace_id),
      correlation_id: Map.fetch!(attrs, :correlation_id),
      release_manifest_ref: Map.fetch!(attrs, :release_manifest_ref),
      product_refs: Map.fetch!(attrs, :product_refs),
      tenant_refs: Map.fetch!(attrs, :tenant_refs),
      scenario_set: Map.fetch!(attrs, :scenario_set),
      sdk_versions: Map.fetch!(attrs, :sdk_versions),
      schema_versions: Map.fetch!(attrs, :schema_versions),
      authority_refs: Map.fetch!(attrs, :authority_refs),
      workflow_refs: Map.fetch!(attrs, :workflow_refs),
      proof_bundle_ref: Map.fetch!(attrs, :proof_bundle_ref),
      no_bypass_scan_ref: Map.fetch!(attrs, :no_bypass_scan_ref),
      sample_dataset_ref: Map.get(attrs, :sample_dataset_ref)
    }
  end
end
