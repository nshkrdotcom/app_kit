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

  @allowed_core_modules [
    "AppKit.Core.ActionResult",
    "AppKit.Core.ActorRef",
    "AppKit.Core.ArchivalConflictProjection",
    "AppKit.Core.ArchivalRestoreSupport",
    "AppKit.Core.ArchivalSweepProjection",
    "AppKit.Core.AttachGrantRef",
    "AppKit.Core.AuditHashChainProjection",
    "AppKit.Core.AuthoringBundleImport",
    "AppKit.Core.BindingDescriptor",
    "AppKit.Core.BindingEnvelope",
    "AppKit.Core.BindingFailurePosture",
    "AppKit.Core.BindingOwnership",
    "AppKit.Core.BlockingCondition",
    "AppKit.Core.ColdRestoreArtifactProjection",
    "AppKit.Core.ColdRestoreTraceProjection",
    "AppKit.Core.CommandEnvelope",
    "AppKit.Core.CommandResult",
    "AppKit.Core.ConnectorAdmissionProjection",
    "AppKit.Core.DecisionRef",
    "AppKit.Core.DecisionSummary",
    "AppKit.Core.EnterprisePrecutSupport",
    "AppKit.Core.EnvironmentRef",
    "AppKit.Core.ErrorTaxonomyProjection",
    "AppKit.Core.EvidenceAuditSupport",
    "AppKit.Core.ExecutionRef",
    "AppKit.Core.ExtensionPackBundleProjection",
    "AppKit.Core.ExtensionPackSignatureProjection",
    "AppKit.Core.ExtensionSupplyChainSupport",
    "AppKit.Core.FilterSet",
    "AppKit.Core.FullProductFabricSmoke",
    "AppKit.Core.InstallResult",
    "AppKit.Core.InstallTemplate",
    "AppKit.Core.InstallationBinding",
    "AppKit.Core.InstallationRef",
    "AppKit.Core.InstallationRevisionEpochFence",
    "AppKit.Core.LeaseRevocationEvidence",
    "AppKit.Core.LowerScopeRef",
    "AppKit.Core.NextStepPreview",
    "AppKit.Core.ObserverDescriptor",
    "AppKit.Core.OperatorAction",
    "AppKit.Core.OperatorActionRef",
    "AppKit.Core.OperatorActionRequest",
    "AppKit.Core.OperatorProjection",
    "AppKit.Core.OperatorSignalResult",
    "AppKit.Core.OperatorSurfaceProjection",
    "AppKit.Core.PageRequest",
    "AppKit.Core.PageResult",
    "AppKit.Core.PendingObligation",
    "AppKit.Core.PrincipalRef",
    "AppKit.Core.ProductBoundaryNoBypassScan",
    "AppKit.Core.ProductCertification",
    "AppKit.Core.ProductFabricSupport",
    "AppKit.Core.ProductTenantContext",
    "AppKit.Core.ProjectRef",
    "AppKit.Core.ProjectionRef",
    "AppKit.Core.QueuePressureProjection",
    "AppKit.Core.ReadLease",
    "AppKit.Core.ReadLeaseRef",
    "AppKit.Core.Rejection",
    "AppKit.Core.RequestContext",
    "AppKit.Core.ResourcePath",
    "AppKit.Core.ResourceRef",
    "AppKit.Core.Result",
    "AppKit.Core.RetryPostureProjection",
    "AppKit.Core.ReviewTaskRef",
    "AppKit.Core.RevisionEpochSupport",
    "AppKit.Core.RunRef",
    "AppKit.Core.RunRequest",
    "AppKit.Core.SortSpec",
    "AppKit.Core.StreamAttachLease",
    "AppKit.Core.StreamAttachLeaseRef",
    "AppKit.Core.SubjectDetail",
    "AppKit.Core.SubjectRef",
    "AppKit.Core.SubjectSummary",
    "AppKit.Core.Support",
    "AppKit.Core.SuppressionVisibilityProjection",
    "AppKit.Core.SurfaceError",
    "AppKit.Core.SystemActorRef",
    "AppKit.Core.Telemetry",
    "AppKit.Core.TenantRef",
    "AppKit.Core.TimelineEvent",
    "AppKit.Core.TraceIdentity",
    "AppKit.Core.UnifiedTrace",
    "AppKit.Core.UnifiedTraceStep",
    "AppKit.Core.WorkflowQueryRequest",
    "AppKit.Core.WorkflowRef",
    "AppKit.Core.WorkflowSignalRequest",
    "AppKit.Core.WorkflowStartRequest",
    "AppKit.Core.WorkspaceRef"
  ]

  @core_module_pattern ~r/^defmodule\s+(AppKit\.Core\.[\w.]+)\s+do/m

  @spec entries() :: [map()]
  def entries, do: @entries

  @spec enterprise_fields() :: [String.t()]
  def enterprise_fields, do: @enterprise_fields

  @spec allowed_core_modules() :: [String.t()]
  def allowed_core_modules, do: @allowed_core_modules

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

  @spec validate_core_dto_surface(Path.t()) :: :ok | {:error, term()}
  def validate_core_dto_surface(root \\ default_core_dto_surface_root()) when is_binary(root) do
    with :ok <- require_surface_root(root) do
      unexpected_modules =
        root
        |> discover_core_modules()
        |> Enum.reject(&(&1 in @allowed_core_modules))

      case unexpected_modules do
        [] -> :ok
        _ -> {:error, {:unexpected_appkit_core_modules, unexpected_modules}}
      end
    end
  end

  @spec validate_core_dto_surface!(Path.t()) :: :ok
  def validate_core_dto_surface!(root \\ default_core_dto_surface_root()) when is_binary(root) do
    case validate_core_dto_surface(root) do
      :ok ->
        :ok

      {:error, reason} ->
        raise ArgumentError, "invalid AppKit Core DTO surface: #{inspect(reason)}"
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

  defp default_core_dto_surface_root do
    Path.expand("../../../core/app_kit_core/lib/app_kit/core", __DIR__)
  end

  defp require_surface_root(root) do
    if File.dir?(root) do
      :ok
    else
      {:error, {:missing_core_dto_surface_root, root}}
    end
  end

  defp discover_core_modules(root) do
    root
    |> Path.join("*.ex")
    |> Path.wildcard()
    |> Enum.flat_map(fn path ->
      @core_module_pattern
      |> Regex.scan(File.read!(path), capture: :all_but_first)
      |> List.flatten()
    end)
    |> Enum.uniq()
    |> Enum.sort()
  end
end
