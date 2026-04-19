defmodule AppKit.Workspace.SchemaRegistry do
  @moduledoc """
  Phase 4 AppKit schema registry for generated DTO and SDK boundary contracts.

  The registry is workspace-owned tooling. It records contract ownership,
  producer/consumer repos, required envelope fields, proof hooks, and
  release-manifest linkage for generated AppKit BFF/SDK shapes.
  """

  @enterprise_fields [
    "tenant_ref",
    "installation_ref",
    "principal_ref",
    "system_actor_ref",
    "resource_ref",
    "authority_packet_ref",
    "permission_decision_ref",
    "idempotency_key",
    "trace_id",
    "correlation_id",
    "release_manifest_ref"
  ]

  @required_entry_keys [
    :contract_name,
    :contract_version,
    :owner_repo,
    :boundary_owner,
    :producer_repos,
    :consumer_repos,
    :dto_packet_table_resource_names,
    :required_fields,
    :optional_fields,
    :generator_command,
    :runbook_path,
    :proof_artifact_path,
    :release_manifest_key,
    :replacement_version_policy
  ]

  @entries [
    %{
      contract_name: "AppKit.ProductBootstrap.v1",
      contract_version: "1.0.0",
      owner_repo: "app_kit",
      boundary_owner: "AppKit SDK and BFF product boundary",
      producer_repos: ["app_kit"],
      consumer_repos: ["extravaganza", "stack_lab", "jido_brainstorm"],
      dto_packet_table_resource_names: [
        "AppKit.ProductBootstrapRequest",
        "AppKit.ProductBootstrapResponse",
        "generated SDK package manifest",
        "BFF schema registry entry"
      ],
      required_fields:
        @enterprise_fields ++
          [
            "product_ref",
            "product_kind",
            "sdk_version",
            "bff_schema_version",
            "contract_manifest_ref",
            "allowed_capabilities",
            "generated_package_ref"
          ],
      optional_fields: ["review_ref", "semantic_context_ref"],
      generator_command: "mix app_kit.gen.boundary product_bootstrap",
      runbook_path: "runbooks/appkit_sdk_contract_failure.md",
      proof_artifact_path: "stack_lab/proofs/scenario_045_appkit_sdk_contract_failure.md",
      release_manifest_key: "contracts.AppKit.ProductBootstrap.v1",
      replacement_version_policy: "big_bang_no_legacy"
    },
    %{
      contract_name: "AppKit.SchemaRegistryEntry.v1",
      contract_version: "1.0.0",
      owner_repo: "app_kit",
      boundary_owner: "BFF schema registry and generated DTO boundary",
      producer_repos: ["app_kit"],
      consumer_repos: ["extravaganza", "stack_lab", "jido_brainstorm"],
      dto_packet_table_resource_names: [
        "schema_registry.entries",
        "generated DTO checksum",
        "GraphQL/gRPC schema artifact",
        "release_manifest.generated_artifacts entry"
      ],
      required_fields:
        @enterprise_fields ++
          [
            "schema_name",
            "schema_version",
            "dto_module",
            "generated_artifact_hash",
            "producer_commit_sha",
            "consumer_package_ref"
          ],
      optional_fields: ["semantic_normalization_ref"],
      generator_command: "mix app_kit.gen.boundary <schema_name>",
      runbook_path: "runbooks/schema_registry_dto_drift.md",
      proof_artifact_path: "stack_lab/proofs/scenario_046_schema_registry_dto_drift.md",
      release_manifest_key: "contracts.AppKit.SchemaRegistryEntry.v1",
      replacement_version_policy: "big_bang_no_legacy"
    },
    %{
      contract_name: "Platform.GeneratedArtifactOwnership.v1",
      contract_version: "1.0.0",
      owner_repo: "app_kit",
      boundary_owner: "generated AppKit DTO artifact ownership boundary",
      producer_repos: ["app_kit"],
      consumer_repos: ["extravaganza", "stack_lab", "jido_brainstorm"],
      dto_packet_table_resource_names: [
        "generated_artifact_manifest",
        "generated DTO source",
        "generated mapper source",
        "generated mapper test"
      ],
      required_fields:
        @enterprise_fields ++
          [
            "artifact_ref",
            "artifact_hash",
            "generator_command",
            "owner_repo",
            "producer_commit_sha",
            "consumer_package_ref"
          ],
      optional_fields: ["source_projection_ref"],
      generator_command: "mix app_kit.gen.boundary <schema_name>",
      runbook_path: "runbooks/generated_artifact_law.md",
      proof_artifact_path: "stack_lab/proofs/scenario_081_generated_artifact_law.md",
      release_manifest_key: "contracts.Platform.GeneratedArtifactOwnership.v1",
      replacement_version_policy: "big_bang_no_legacy"
    }
  ]

  @spec entries() :: [map()]
  def entries, do: @entries

  @spec enterprise_fields() :: [String.t()]
  def enterprise_fields, do: @enterprise_fields

  @spec fetch(String.t()) :: {:ok, map()} | {:error, :unknown_schema_contract}
  def fetch(contract_name) when is_binary(contract_name) do
    case Enum.find(@entries, &(&1.contract_name == contract_name)) do
      nil -> {:error, :unknown_schema_contract}
      entry -> {:ok, entry}
    end
  end

  @spec validate_all() :: :ok | {:error, term()}
  def validate_all do
    @entries
    |> Enum.reduce_while(:ok, fn entry, :ok ->
      case validate_entry(entry) do
        :ok -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, {entry.contract_name, reason}}}
      end
    end)
  end

  @spec validate_all!() :: :ok
  def validate_all! do
    case validate_all() do
      :ok ->
        :ok

      {:error, reason} ->
        raise ArgumentError, "invalid AppKit schema registry: #{inspect(reason)}"
    end
  end

  @spec validate_entry(map()) :: :ok | {:error, term()}
  def validate_entry(entry) when is_map(entry) do
    with :ok <- require_keys(entry),
         :ok <- require_non_empty_lists(entry),
         :ok <- require_enterprise_fields(entry) do
      require_big_bang(entry)
    end
  end

  def validate_entry(_entry), do: {:error, :invalid_registry_entry}

  defp require_keys(entry) do
    missing_keys = Enum.reject(@required_entry_keys, &Map.has_key?(entry, &1))

    case missing_keys do
      [] -> :ok
      _ -> {:error, {:missing_keys, missing_keys}}
    end
  end

  defp require_non_empty_lists(entry) do
    list_keys = [
      :producer_repos,
      :consumer_repos,
      :dto_packet_table_resource_names,
      :required_fields
    ]

    empty_keys =
      Enum.reject(list_keys, fn key ->
        values = Map.fetch!(entry, key)
        is_list(values) and values != []
      end)

    case empty_keys do
      [] -> :ok
      _ -> {:error, {:empty_required_lists, empty_keys}}
    end
  end

  defp require_enterprise_fields(entry) do
    missing_fields = @enterprise_fields -- entry.required_fields

    case missing_fields do
      [] -> :ok
      _ -> {:error, {:missing_required_fields, missing_fields}}
    end
  end

  defp require_big_bang(%{replacement_version_policy: "big_bang_no_legacy"}), do: :ok
  defp require_big_bang(_entry), do: {:error, :legacy_replacement_policy_not_allowed}
end
