defmodule Mezzanine.AppKitBridge.InstallationService do
  @moduledoc """
  Backend-oriented tenant installation lifecycle for AppKit consumers.

  Installation semantics stay strictly installation-scoped: the service binds a
  tenant/environment to an already activated pack registration and refuses to
  absorb deployment or pack-registration responsibilities by stealth.
  """

  require Ash.Query

  alias Mezzanine.AppKitBridge.{AdapterSupport, RuntimeProfileService}
  alias Mezzanine.ConfigRegistry.{Installation, PackRegistration}

  @deployment_keys [
    :compiled_manifest,
    :serializer_version,
    :migration_strategy,
    :canonical_subject_kinds,
    :register_pack,
    :activate_pack,
    :deployment
  ]

  @spec create_installation(map(), keyword()) :: {:ok, map()} | {:error, term()}
  def create_installation(attrs, opts \\ []) when is_map(attrs) and is_list(opts) do
    attrs = Map.new(attrs)

    with :ok <- reject_deployment_fields(attrs),
         {:ok, tenant_id} <- fetch_string(attrs, opts, :tenant_id),
         {:ok, runtime_profile_status} <- ensure_runtime_profile(tenant_id, attrs, opts),
         {:ok, pack_slug} <- fetch_string(attrs, opts, :pack_slug),
         {:ok, pack_version} <- fetch_string(attrs, opts, :pack_version),
         environment <- optional_string(attrs, opts, :environment, "default"),
         {:ok, pack_registration} <- fetch_active_pack_registration(pack_slug, pack_version),
         {:ok, existing_installation} <- find_installation(tenant_id, environment, pack_slug) do
      binding_config = binding_config(attrs)
      metadata = installation_metadata(attrs)

      case existing_installation do
        nil ->
          create_active_installation(
            tenant_id,
            environment,
            pack_registration,
            binding_config,
            metadata
          )

        %Installation{} = installation ->
          reuse_or_update_installation(
            installation,
            pack_registration,
            binding_config,
            runtime_profile_status
          )
      end
    else
      {:error, reason} -> {:error, normalize_error(reason)}
    end
  end

  @spec import_authoring_bundle(map(), keyword()) :: {:ok, map()} | {:error, term()}
  def import_authoring_bundle(attrs, opts \\ []) when is_map(attrs) and is_list(opts) do
    attrs = Map.new(attrs)

    with {:ok, import_result} <- MezzanineConfigRegistry.import_authoring_bundle(attrs, opts),
         {:ok, detail} <- installation_detail(import_result.installation) do
      {:ok,
       %{
         installation_ref: detail.installation_ref,
         status: :created,
         message: "Authoring bundle imported",
         metadata: %{
           bundle: bundle_summary(import_result.bundle),
           installation: detail,
           pack_registration: pack_registration_summary(import_result.pack_registration)
         }
       }}
    else
      {:error, reason} -> {:error, normalize_error(reason)}
    end
  end

  @spec get_installation(Ecto.UUID.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def get_installation(installation_id, _opts \\ []) when is_binary(installation_id) do
    case fetch_installation(installation_id) do
      {:ok, installation} -> installation_detail(installation)
      {:error, reason} -> {:error, normalize_error(reason)}
    end
  end

  @spec list_installations(String.t(), map(), keyword()) :: {:ok, [map()]} | {:error, term()}
  def list_installations(tenant_id, filters \\ %{}, _opts \\ [])
      when is_binary(tenant_id) and is_map(filters) do
    case list_tenant_installations(tenant_id) do
      {:ok, installations} ->
        {:ok,
         installations
         |> Enum.filter(&matches_filters?(&1, filters))
         |> Enum.map(&installation_detail!/1)
         |> Enum.sort_by(&{&1.environment, &1.installation_ref.id})}

      {:error, reason} ->
        {:error, normalize_error(reason)}
    end
  end

  @spec update_bindings(Ecto.UUID.t(), map(), keyword()) :: {:ok, map()} | {:error, term()}
  def update_bindings(installation_id, binding_config, _opts \\ [])
      when is_binary(installation_id) and is_map(binding_config) do
    with {:ok, installation} <- fetch_installation(installation_id),
         {:ok, updated_installation} <-
           MezzanineConfigRegistry.update_bindings(installation, binding_config),
         {:ok, detail} <- installation_detail(updated_installation) do
      {:ok, action_result(detail, :update_bindings, "Bindings updated")}
    else
      {:error, reason} -> {:error, normalize_error(reason)}
    end
  end

  @spec suspend_installation(Ecto.UUID.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def suspend_installation(installation_id, _opts \\ []) when is_binary(installation_id) do
    with {:ok, installation} <- fetch_installation(installation_id),
         {:ok, suspended_installation} <-
           MezzanineConfigRegistry.suspend_installation(installation),
         {:ok, detail} <- installation_detail(suspended_installation) do
      {:ok, action_result(detail, :suspend_installation, "Installation suspended")}
    else
      {:error, reason} -> {:error, normalize_error(reason)}
    end
  end

  @spec reactivate_installation(Ecto.UUID.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def reactivate_installation(installation_id, _opts \\ []) when is_binary(installation_id) do
    with {:ok, installation} <- fetch_installation(installation_id),
         {:ok, active_installation} <- ensure_active(installation),
         {:ok, detail} <- installation_detail(active_installation) do
      {:ok, action_result(detail, :reactivate_installation, "Installation active")}
    else
      {:error, reason} -> {:error, normalize_error(reason)}
    end
  end

  defp create_active_installation(
         tenant_id,
         environment,
         pack_registration,
         binding_config,
         metadata
       ) do
    with {:ok, installation} <-
           MezzanineConfigRegistry.create_installation(%{
             tenant_id: tenant_id,
             environment: environment,
             pack_registration_id: pack_registration.id,
             binding_config: binding_config,
             metadata: metadata
           }),
         {:ok, active_installation} <- MezzanineConfigRegistry.activate_installation(installation),
         {:ok, detail} <- installation_detail(active_installation) do
      {:ok,
       %{
         installation_ref: detail.installation_ref,
         status: :created,
         message: "Installation created",
         metadata: %{installation: detail}
       }}
    end
  end

  defp reuse_or_update_installation(
         installation,
         pack_registration,
         binding_config,
         runtime_profile_status
       ) do
    if installation.pack_registration_id != pack_registration.id do
      {:error, :installation_pack_conflict}
    else
      with {:ok, installation} <- maybe_update_bindings(installation, binding_config),
           {:ok, active_installation} <- ensure_active(installation),
           {:ok, detail} <- installation_detail(active_installation) do
        status =
          result_status(
            installation,
            active_installation,
            binding_config,
            runtime_profile_status
          )

        {:ok,
         %{
           installation_ref: detail.installation_ref,
           status: status,
           message: reuse_message(status),
           metadata: %{installation: detail}
         }}
      end
    end
  end

  defp maybe_update_bindings(%Installation{} = installation, binding_config) do
    if installation.binding_config == binding_config do
      {:ok, installation}
    else
      MezzanineConfigRegistry.update_bindings(installation, binding_config)
    end
  end

  defp ensure_active(%Installation{status: :active} = installation), do: {:ok, installation}

  defp ensure_active(%Installation{status: :inactive} = installation),
    do: MezzanineConfigRegistry.activate_installation(installation)

  defp ensure_active(%Installation{} = installation),
    do: MezzanineConfigRegistry.reactivate_installation(installation)

  defp result_status(
         original_installation,
         active_installation,
         desired_bindings,
         runtime_profile_status
       ) do
    runtime_profile_changed? = runtime_profile_status == :updated

    if original_installation.status == :active and
         original_installation.binding_config == desired_bindings and
         active_installation.compiled_pack_revision ==
           original_installation.compiled_pack_revision and
         not runtime_profile_changed? do
      :reused
    else
      :updated
    end
  end

  defp reuse_message(:reused), do: "Installation already active"
  defp reuse_message(:updated), do: "Installation updated"

  defp fetch_installation(installation_id) do
    case Ash.get(Installation, installation_id) do
      {:ok, %Installation{} = installation} -> load_installation(installation)
      {:error, %Ash.Error.Invalid{}} -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  defp list_tenant_installations(tenant_id) do
    Installation
    |> Ash.Query.filter(tenant_id == ^tenant_id)
    |> Ash.read(domain: Mezzanine.ConfigRegistry)
    |> case do
      {:ok, installations} -> {:ok, Enum.map(installations, &load_installation!/1)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp find_installation(tenant_id, environment, pack_slug) do
    Installation
    |> Ash.Query.filter(
      tenant_id == ^tenant_id and environment == ^environment and pack_slug == ^pack_slug
    )
    |> Ash.read(domain: Mezzanine.ConfigRegistry)
    |> case do
      {:ok, [installation | _]} -> {:ok, load_installation!(installation)}
      {:ok, []} -> {:ok, nil}
      {:error, reason} -> {:error, reason}
    end
  end

  defp fetch_active_pack_registration(pack_slug, pack_version) do
    case PackRegistration.by_slug_version(pack_slug, pack_version) do
      {:ok, %PackRegistration{status: :active} = registration} -> {:ok, registration}
      {:ok, %PackRegistration{}} -> {:error, :pack_registration_not_active}
      {:error, _reason} -> {:error, :pack_registration_not_found}
    end
  end

  defp installation_detail(%Installation{} = installation) do
    {:ok, installation_detail!(installation)}
  end

  defp installation_detail!(%Installation{} = installation) do
    installation = load_installation!(installation)

    %{
      installation_ref: installation_ref(installation),
      tenant_id: installation.tenant_id,
      environment: installation.environment,
      bindings: installation.binding_config,
      external_systems: external_system_groups(installation.binding_config),
      metadata: installation.metadata,
      pack_registration_id: installation.pack_registration_id
    }
  end

  defp installation_ref(%Installation{} = installation) do
    %{
      id: installation.id,
      pack_slug: installation.pack_slug,
      pack_version: installation.pack_registration.version,
      compiled_pack_revision: installation.compiled_pack_revision,
      status: installation.status
    }
  end

  defp action_result(detail, action, message) do
    %{
      status: :completed,
      action_ref: %{
        id: "#{detail.installation_ref.id}:#{action}",
        action_kind: Atom.to_string(action),
        installation_ref: detail.installation_ref
      },
      message: message,
      metadata: %{installation: detail}
    }
  end

  defp bundle_summary(bundle) do
    %{
      bundle_id: bundle.bundle_id,
      tenant_id: bundle.tenant_id,
      installation_id: bundle.installation_id,
      pack_slug: bundle.compiled_pack.pack_slug,
      pack_version: bundle.compiled_pack.version,
      checksum: bundle.checksum,
      signature: bundle.signature,
      authored_by: bundle.authored_by,
      policy_refs: bundle.policy_refs
    }
  end

  defp pack_registration_summary(%PackRegistration{} = registration) do
    %{
      id: registration.id,
      pack_slug: registration.pack_slug,
      version: registration.version,
      status: registration.status,
      canonical_subject_kinds: registration.canonical_subject_kinds,
      serializer_version: registration.serializer_version
    }
  end

  defp matches_filters?(installation, filters) do
    status = map_value(filters, :status)
    environment = map_value(filters, :environment)
    pack_slug = map_value(filters, :pack_slug)

    (is_nil(status) or installation.installation_ref.status == normalize_status(status)) and
      (is_nil(environment) or installation.environment == environment) and
      (is_nil(pack_slug) or installation.installation_ref.pack_slug == pack_slug)
  end

  defp load_installation(%Installation{} = installation) do
    installation
    |> Ash.load([:pack_registration], domain: Mezzanine.ConfigRegistry)
    |> case do
      {:ok, loaded_installation} -> {:ok, loaded_installation}
      {:error, reason} -> {:error, reason}
    end
  end

  defp load_installation!(%Installation{} = installation) do
    case load_installation(installation) do
      {:ok, loaded_installation} -> loaded_installation
      {:error, reason} -> raise "failed to load installation: #{inspect(reason)}"
    end
  end

  defp binding_config(attrs),
    do: map_value(attrs, :default_bindings) || map_value(attrs, :bindings) || %{}

  defp external_system_groups(binding_config) when is_map(binding_config) do
    binding_config
    |> Enum.flat_map(&binding_entries/1)
    |> Enum.group_by(& &1.external_system_ref)
    |> Enum.map(fn {external_system_ref, entries} ->
      first = hd(entries)

      %{
        external_system_ref: external_system_ref,
        external_system: first.external_system,
        operator_owner: first.operator_owner,
        binding_count: length(entries),
        credential_refs:
          entries
          |> Enum.map(& &1.credential_ref)
          |> Enum.reject(&is_nil/1)
          |> Enum.uniq()
          |> Enum.sort(),
        bindings:
          entries
          |> Enum.map(fn entry ->
            %{
              binding_key: entry.binding_key,
              attachment: entry.attachment,
              contract: entry.contract,
              runbook_ref: entry.runbook_ref,
              staleness_class: entry.staleness_class,
              on_unavailable: entry.on_unavailable,
              on_timeout: entry.on_timeout,
              credential_ref: entry.credential_ref
            }
          end)
          |> Enum.sort_by(& &1.binding_key)
      }
    end)
    |> Enum.sort_by(& &1.external_system_ref)
  end

  defp external_system_groups(_binding_config), do: []

  defp binding_entries({group_key, bindings}) when is_map(bindings) do
    if String.ends_with?(to_string(group_key), "_bindings") do
      bindings
      |> Enum.map(fn {binding_key, binding} -> binding_entry(binding_key, binding) end)
      |> Enum.reject(&is_nil/1)
    else
      []
    end
  end

  defp binding_entries(_entry), do: []

  defp binding_entry(binding_key, binding) do
    descriptor = descriptor_map(binding)
    ownership = map_value(descriptor, :ownership) || %{}
    external_system_ref = map_value(ownership, :external_system_ref)

    if is_binary(external_system_ref) do
      envelope = map_value(descriptor, :envelope) || %{}
      failure = map_value(descriptor, :failure) || %{}

      %{
        binding_key: to_string(binding_key),
        external_system: map_value(ownership, :external_system),
        external_system_ref: external_system_ref,
        operator_owner: map_value(ownership, :operator_owner),
        attachment: map_value(descriptor, :attachment),
        contract: map_value(descriptor, :contract),
        runbook_ref: map_value(envelope, :runbook_ref),
        staleness_class: map_value(envelope, :staleness_class),
        on_unavailable: map_value(failure, :on_unavailable),
        on_timeout: map_value(failure, :on_timeout),
        credential_ref: map_value(binding, :credential_ref)
      }
    end
  end

  defp descriptor_map(binding) do
    map_value(binding, :descriptor) || %{}
  end

  defp installation_metadata(attrs) do
    metadata = map_value(attrs, :metadata) || %{}
    template_key = map_value(attrs, :template_key)

    if is_binary(template_key) do
      Map.put(metadata, "template_key", template_key)
    else
      metadata
    end
  end

  defp ensure_runtime_profile(tenant_id, attrs, opts) do
    RuntimeProfileService.ensure(tenant_id, runtime_profile(attrs, opts))
  end

  defp runtime_profile(attrs, opts) do
    Keyword.get(opts, :runtime_profile) || map_value(attrs, :runtime_profile)
  end

  defp reject_deployment_fields(attrs) do
    if Enum.any?(@deployment_keys, &Map.has_key?(attrs, &1)) or
         Enum.any?(@deployment_keys, &Map.has_key?(attrs, Atom.to_string(&1))) do
      {:error, :installation_payload_contains_deployment_fields}
    else
      :ok
    end
  end

  defp fetch_string(attrs, opts, key), do: AdapterSupport.fetch_string(attrs, opts, key)

  defp optional_string(attrs, opts, key, default),
    do: AdapterSupport.optional_string(attrs, opts, key, default)

  defp map_value(attrs, key), do: AdapterSupport.map_value(attrs, key)

  defp normalize_status(status) when status in [:inactive, :active, :suspended, :degraded],
    do: status

  defp normalize_status(status) when is_binary(status) do
    case status do
      "inactive" -> :inactive
      "active" -> :active
      "suspended" -> :suspended
      "degraded" -> :degraded
      _ -> status
    end
  end

  defp normalize_error(reason), do: AdapterSupport.normalize_error(reason)
end
