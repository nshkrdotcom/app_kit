defmodule AppKit.Core.InstallTemplate do
  @moduledoc """
  Stable northbound installation template envelope.
  """

  alias AppKit.Core.Support

  @enforce_keys [:template_key, :pack_slug, :pack_version]
  defstruct [:template_key, :pack_slug, :pack_version, default_bindings: %{}, metadata: %{}]

  @type t :: %__MODULE__{
          template_key: String.t(),
          pack_slug: String.t(),
          pack_version: String.t(),
          default_bindings: map(),
          metadata: map()
        }

  @spec new(map() | keyword()) :: {:ok, t()} | {:error, :invalid_install_template}
  def new(attrs) do
    with {:ok, attrs} <- Support.normalize_attrs(attrs),
         template_key <- Map.get(attrs, :template_key),
         true <- Support.present_binary?(template_key),
         pack_slug <- Map.get(attrs, :pack_slug),
         true <- Support.present_binary?(pack_slug),
         pack_version <- Map.get(attrs, :pack_version),
         true <- Support.present_binary?(pack_version),
         default_bindings <- Map.get(attrs, :default_bindings, %{}),
         true <- is_map(default_bindings),
         metadata <- Map.get(attrs, :metadata, %{}),
         true <- is_map(metadata) do
      {:ok,
       %__MODULE__{
         template_key: template_key,
         pack_slug: pack_slug,
         pack_version: pack_version,
         default_bindings: default_bindings,
         metadata: metadata
       }}
    else
      _ -> {:error, :invalid_install_template}
    end
  end
end

defmodule AppKit.Core.AuthoringBundleImport do
  @moduledoc """
  Operator-only authoring bundle import envelope.

  This DTO is intentionally separate from normal installation templates so pack
  registration, descriptor validation, and activation payloads cannot be
  smuggled through product install flows.
  """

  alias AppKit.Core.Support

  @platform_migration_keys [:platform_migrations, :schema_migrations, :migrations]

  @enforce_keys [
    :bundle_id,
    :tenant_id,
    :installation_id,
    :pack_manifest,
    :lifecycle_specs,
    :decision_specs,
    :binding_descriptors,
    :observer_descriptors,
    :context_adapter_descriptors,
    :checksum,
    :authored_by
  ]
  defstruct [
    :bundle_id,
    :tenant_id,
    :installation_id,
    :pack_manifest,
    :checksum,
    :signature,
    :authored_by,
    lifecycle_specs: [],
    decision_specs: [],
    binding_descriptors: %{},
    observer_descriptors: [],
    context_adapter_descriptors: [],
    policy_refs: [],
    expected_installation_revision: nil,
    metadata: %{}
  ]

  @type t :: %__MODULE__{
          bundle_id: String.t(),
          tenant_id: String.t(),
          installation_id: String.t(),
          pack_manifest: map(),
          lifecycle_specs: [map()],
          decision_specs: [map()],
          binding_descriptors: map(),
          observer_descriptors: [map()],
          context_adapter_descriptors: [map()],
          policy_refs: [String.t()],
          expected_installation_revision: non_neg_integer() | nil,
          checksum: String.t(),
          signature: String.t() | nil,
          authored_by: String.t(),
          metadata: map()
        }

  @spec new(map() | keyword()) :: {:ok, t()} | {:error, :invalid_authoring_bundle_import}
  def new(attrs) do
    with {:ok, attrs} <- Support.normalize_attrs(attrs),
         :ok <- reject_platform_migrations(attrs),
         bundle_id <- value(attrs, :bundle_id),
         true <- Support.present_binary?(bundle_id),
         tenant_id <- value(attrs, :tenant_id),
         true <- Support.present_binary?(tenant_id),
         installation_id <- value(attrs, :installation_id),
         true <- Support.present_binary?(installation_id),
         pack_manifest <- value(attrs, :pack_manifest),
         true <- is_map(pack_manifest),
         lifecycle_specs <- value(attrs, :lifecycle_specs, []),
         true <- list_of_maps?(lifecycle_specs),
         decision_specs <- value(attrs, :decision_specs, []),
         true <- list_of_maps?(decision_specs),
         binding_descriptors <- value(attrs, :binding_descriptors, %{}),
         true <- is_map(binding_descriptors),
         observer_descriptors <- value(attrs, :observer_descriptors, []),
         true <- list_of_maps?(observer_descriptors),
         context_adapter_descriptors <- value(attrs, :context_adapter_descriptors, []),
         true <- list_of_maps?(context_adapter_descriptors),
         policy_refs <- value(attrs, :policy_refs, []),
         true <- string_list?(policy_refs),
         expected_installation_revision <- value(attrs, :expected_installation_revision),
         true <- Support.optional_non_neg_integer?(expected_installation_revision),
         checksum <- value(attrs, :checksum),
         true <- Support.present_binary?(checksum),
         signature <- value(attrs, :signature),
         true <- Support.optional_binary?(signature),
         authored_by <- value(attrs, :authored_by),
         true <- Support.present_binary?(authored_by),
         metadata <- value(attrs, :metadata, %{}),
         true <- is_map(metadata) do
      {:ok,
       %__MODULE__{
         bundle_id: bundle_id,
         tenant_id: tenant_id,
         installation_id: installation_id,
         pack_manifest: pack_manifest,
         lifecycle_specs: lifecycle_specs,
         decision_specs: decision_specs,
         binding_descriptors: binding_descriptors,
         observer_descriptors: observer_descriptors,
         context_adapter_descriptors: context_adapter_descriptors,
         policy_refs: policy_refs,
         expected_installation_revision: expected_installation_revision,
         checksum: checksum,
         signature: signature,
         authored_by: authored_by,
         metadata: metadata
       }}
    else
      _ -> {:error, :invalid_authoring_bundle_import}
    end
  end

  defp reject_platform_migrations(attrs) do
    if Enum.any?(@platform_migration_keys, &has_key?(attrs, &1)) do
      {:error, :pack_authored_platform_migration}
    else
      :ok
    end
  end

  defp has_key?(attrs, key),
    do: Map.has_key?(attrs, key) or Map.has_key?(attrs, Atom.to_string(key))

  defp value(attrs, key, default \\ nil) do
    case Map.fetch(attrs, key) do
      {:ok, value} -> value
      :error -> Map.get(attrs, Atom.to_string(key), default)
    end
  end

  defp list_of_maps?(values) when is_list(values), do: Enum.all?(values, &is_map/1)
  defp list_of_maps?(_values), do: false

  defp string_list?(values) when is_list(values),
    do: Enum.all?(values, &Support.present_binary?/1)

  defp string_list?(_values), do: false
end

defmodule AppKit.Core.InstallationBinding do
  @moduledoc """
  Stable northbound installation binding envelope.
  """

  alias AppKit.Core.{BindingDescriptor, Support}

  @binding_kinds [:execution, :connector, :evidence, :actor, :context, :subject, :observer]
  @attachment_by_binding_kind %{
    execution: "mezzanine.execution_recipe",
    context: "outer_brain.context_adapter",
    subject: "mezzanine.subject_kind",
    observer: "jido_integration.audit_subscriber"
  }

  @enforce_keys [:binding_key, :binding_kind]
  defstruct [
    :binding_key,
    :binding_kind,
    :descriptor,
    config: %{},
    credential_ref: nil,
    metadata: %{}
  ]

  @type binding_kind ::
          :execution | :connector | :evidence | :actor | :context | :subject | :observer

  @type t :: %__MODULE__{
          binding_key: String.t(),
          binding_kind: binding_kind(),
          descriptor: BindingDescriptor.t() | nil,
          config: map(),
          credential_ref: String.t() | nil,
          metadata: map()
        }

  @spec new(map() | keyword()) :: {:ok, t()} | {:error, :invalid_installation_binding}
  def new(attrs) do
    with {:ok, attrs} <- Support.normalize_attrs(attrs),
         binding_key <- Map.get(attrs, :binding_key),
         true <- Support.present_binary?(binding_key),
         binding_kind <- Map.get(attrs, :binding_kind),
         true <- Support.enum?(binding_kind, @binding_kinds),
         {:ok, descriptor} <-
           Support.nested_struct(Map.get(attrs, :descriptor), BindingDescriptor),
         :ok <- descriptor_requirement(binding_kind, descriptor),
         config <- Map.get(attrs, :config, %{}),
         true <- is_map(config),
         :ok <- binding_config_requirement(binding_kind, config),
         credential_ref <- Map.get(attrs, :credential_ref),
         true <- Support.optional_binary?(credential_ref),
         metadata <- Map.get(attrs, :metadata, %{}),
         true <- is_map(metadata) do
      {:ok,
       %__MODULE__{
         binding_key: binding_key,
         binding_kind: binding_kind,
         descriptor: descriptor,
         config: config,
         credential_ref: credential_ref,
         metadata: metadata
       }}
    else
      _ -> {:error, :invalid_installation_binding}
    end
  end

  defp descriptor_requirement(binding_kind, nil)
       when binding_kind in [:context, :subject, :observer],
       do: {:error, :missing_descriptor}

  defp descriptor_requirement(binding_kind, %BindingDescriptor{} = descriptor) do
    case Map.get(@attachment_by_binding_kind, binding_kind) do
      nil ->
        :ok

      attachment when descriptor.attachment == attachment ->
        :ok

      _attachment ->
        {:error, :binding_descriptor_attachment_mismatch}
    end
  end

  defp descriptor_requirement(_binding_kind, _descriptor), do: :ok

  defp binding_config_requirement(:context, config) do
    adapter_key = Map.get(config, :adapter_key) || Map.get(config, "adapter_key")
    timeout_ms = Map.get(config, :timeout_ms) || Map.get(config, "timeout_ms")
    adapter_config = Map.get(config, :config, %{}) || Map.get(config, "config", %{})

    cond do
      not Support.present_binary?(adapter_key) ->
        {:error, :invalid_context_binding_config}

      not is_map(adapter_config) ->
        {:error, :invalid_context_binding_config}

      not is_nil(timeout_ms) and not Support.positive_integer?(timeout_ms) ->
        {:error, :invalid_context_binding_config}

      true ->
        :ok
    end
  end

  defp binding_config_requirement(:subject, config) do
    subject_kind = Map.get(config, :subject_kind) || Map.get(config, "subject_kind")
    recipe_refs = Map.get(config, :recipe_refs) || Map.get(config, "recipe_refs")

    cond do
      not Support.present_binary?(subject_kind) ->
        {:error, :invalid_subject_binding_config}

      not valid_string_list?(recipe_refs) ->
        {:error, :invalid_subject_binding_config}

      true ->
        :ok
    end
  end

  defp binding_config_requirement(:observer, config) do
    subscriber_key = Map.get(config, :subscriber_key) || Map.get(config, "subscriber_key")
    event_types = Map.get(config, :event_types) || Map.get(config, "event_types", [])

    cond do
      not Support.present_binary?(subscriber_key) ->
        {:error, :invalid_observer_binding_config}

      not valid_optional_string_list?(event_types) ->
        {:error, :invalid_observer_binding_config}

      true ->
        :ok
    end
  end

  defp binding_config_requirement(_binding_kind, _config), do: :ok

  defp valid_string_list?(values) when is_list(values) do
    values != [] and Enum.all?(values, &Support.present_binary?/1)
  end

  defp valid_string_list?(_values), do: false

  defp valid_optional_string_list?(values) when is_list(values) do
    Enum.all?(values, &Support.present_binary?/1)
  end

  defp valid_optional_string_list?(_values), do: false
end

defmodule AppKit.Core.InstallResult do
  @moduledoc """
  Stable northbound installation result envelope.
  """

  alias AppKit.Core.{InstallationRef, Support}

  @statuses [:created, :updated, :reused]

  @enforce_keys [:installation_ref, :status]
  defstruct [:installation_ref, :status, message: nil, metadata: %{}]

  @type status :: :created | :updated | :reused

  @type t :: %__MODULE__{
          installation_ref: InstallationRef.t(),
          status: status(),
          message: String.t() | nil,
          metadata: map()
        }

  @spec new(map() | keyword()) :: {:ok, t()} | {:error, :invalid_install_result}
  def new(attrs) do
    with {:ok, attrs} <- Support.normalize_attrs(attrs),
         {:ok, installation_ref} <-
           Support.nested_struct(Map.get(attrs, :installation_ref), InstallationRef),
         false <- is_nil(installation_ref),
         status <- Map.get(attrs, :status),
         true <- Support.enum?(status, @statuses),
         message <- Map.get(attrs, :message),
         true <- Support.optional_binary?(message),
         metadata <- Map.get(attrs, :metadata, %{}),
         true <- is_map(metadata) do
      {:ok,
       %__MODULE__{
         installation_ref: installation_ref,
         status: status,
         message: message,
         metadata: metadata
       }}
    else
      _ -> {:error, :invalid_install_result}
    end
  end
end
