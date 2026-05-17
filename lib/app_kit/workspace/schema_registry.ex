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
    },
    %{
      contract_name: "AppKit.ModelSurface.v1",
      contract_version: "1.0.0",
      owner_repo: "app_kit",
      boundary_owner: "governed model inventory projection boundary",
      producer_repos: ["app_kit", "jido_integration"],
      consumer_repos: ["extravaganza", "stack_lab", "jido_brainstorm"],
      dto_packet_table_resource_names: [
        "AppKit.ModelSurface.ModelProfileProjection",
        "AppKit.ModelSurface.EndpointProfileProjection",
        "AppKit.ModelSurface.CatalogProjection",
        "AppKit.ModelSurface.AdmissionRequest"
      ],
      required_fields:
        @enterprise_fields ++
          [
            "model_profile_ref",
            "endpoint_profile_ref",
            "capability_refs",
            "readiness_ref",
            "operation_policy_ref",
            "cost_posture_ref"
          ],
      optional_fields: ["admission_ref"],
      generator_command: "manual AppKit model surface DTO package",
      runbook_path: "runbooks/appkit_model_surface_contract_failure.md",
      proof_artifact_path: "stack_lab/proofs/scenario_aoc_034_model_surface.md",
      release_manifest_key: "contracts.AppKit.ModelSurface.v1",
      replacement_version_policy: "big_bang_no_legacy"
    },
    %{
      contract_name: "AppKit.OptimizationSurface.v1",
      contract_version: "1.0.0",
      owner_repo: "app_kit",
      boundary_owner: "governed optimization command and projection boundary",
      producer_repos: ["app_kit", "mezzanine"],
      consumer_repos: ["extravaganza", "stack_lab", "jido_brainstorm"],
      dto_packet_table_resource_names: [
        "AppKit.OptimizationSurface.RunCreateRequest",
        "AppKit.OptimizationSurface.CandidateProjection",
        "AppKit.OptimizationSurface.CandidateComparison",
        "AppKit.OptimizationSurface.PromotionDecisionProjection",
        "AppKit.OptimizationSurface.LineageProjection"
      ],
      required_fields:
        @enterprise_fields ++
          [
            "optimization_run_ref",
            "candidate_ref",
            "eval_ref",
            "replay_ref",
            "budget_ref",
            "promotion_ref",
            "rollback_ref"
          ],
      optional_fields: ["shadow_ref", "canary_ref"],
      generator_command: "manual AppKit optimization surface DTO package",
      runbook_path: "runbooks/appkit_optimization_surface_contract_failure.md",
      proof_artifact_path: "stack_lab/proofs/scenario_aoc_035_optimization_surface.md",
      release_manifest_key: "contracts.AppKit.OptimizationSurface.v1",
      replacement_version_policy: "big_bang_no_legacy"
    },
    %{
      contract_name: "AppKit.CoordinationSurface.v1",
      contract_version: "1.0.0",
      owner_repo: "app_kit",
      boundary_owner: "governed TRINITY coordination command and projection boundary",
      producer_repos: ["app_kit", "mezzanine", "trinity_framework"],
      consumer_repos: ["extravaganza", "stack_lab", "jido_brainstorm"],
      dto_packet_table_resource_names: [
        "AppKit.CoordinationSurface.RunCreateRequest",
        "AppKit.CoordinationSurface.CoordinationProjection",
        "AppKit.CoordinationSurface.RouterDecisionProjection",
        "AppKit.CoordinationSurface.ProviderPoolProjection",
        "AppKit.CoordinationSurface.ReplayBundleProjection"
      ],
      required_fields:
        @enterprise_fields ++
          [
            "coordination_run_ref",
            "router_decision_ref",
            "role_selection_ref",
            "provider_pool_ref",
            "verifier_state_ref",
            "turn_timeline_ref",
            "memory_context_ref",
            "context_budget_ref",
            "replay_bundle_ref"
          ],
      optional_fields: ["human_intervention_ref", "retry_turn_ref"],
      generator_command: "manual AppKit coordination surface DTO package",
      runbook_path: "runbooks/appkit_coordination_surface_contract_failure.md",
      proof_artifact_path: "stack_lab/proofs/scenario_aoc_036_coordination_surface.md",
      release_manifest_key: "contracts.AppKit.CoordinationSurface.v1",
      replacement_version_policy: "big_bang_no_legacy"
    },
    %{
      contract_name: "AppKit.AdaptiveControlSurface.v1",
      contract_version: "1.0.0",
      owner_repo: "app_kit",
      boundary_owner: "governed adaptive-control operator projection boundary",
      producer_repos: ["app_kit", "mezzanine", "ground_plane"],
      consumer_repos: ["extravaganza", "stack_lab", "jido_brainstorm"],
      dto_packet_table_resource_names: [
        "AppKit.AdaptiveControlSurface.OperatorProjection",
        "AppKit.AdaptiveControlSurface.ShadowComparisonProjection",
        "AppKit.AdaptiveControlSurface.CanaryStateProjection",
        "AppKit.AdaptiveControlSurface.PromotionReadinessProjection",
        "AppKit.AdaptiveControlSurface.RollbackProjection"
      ],
      required_fields:
        @enterprise_fields ++
          [
            "adaptive_control_run_ref",
            "shadow_comparison_ref",
            "canary_state_ref",
            "threshold_status_ref",
            "budget_impact_ref",
            "approval_decision_ref",
            "promotion_readiness_ref",
            "rollback_ref",
            "artifact_lock_ref",
            "stale_artifact_rejection_ref",
            "audit_ref"
          ],
      optional_fields: ["operator_review_ref"],
      generator_command: "manual AppKit adaptive-control surface DTO package",
      runbook_path: "runbooks/appkit_adaptive_control_surface_contract_failure.md",
      proof_artifact_path: "stack_lab/proofs/scenario_aoc_037_adaptive_control_surface.md",
      release_manifest_key: "contracts.AppKit.AdaptiveControlSurface.v1",
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
    "AppKit.Core.AuthorityContextExt",
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
    "AppKit.Core.Context",
    "AppKit.Core.DecisionRef",
    "AppKit.Core.DecisionSummary",
    "AppKit.Core.EnterprisePrecutSupport",
    "AppKit.Core.EnvironmentRef",
    "AppKit.Core.ErrorTaxonomyProjection",
    "AppKit.Core.EvidenceCollectionRequest",
    "AppKit.Core.EvidenceAuditSupport",
    "AppKit.Core.EvidenceProjection",
    "AppKit.Core.ExecutionRef",
    "AppKit.Core.ExecutionStateProjection",
    "AppKit.Core.ExtensionPackBundleProjection",
    "AppKit.Core.ExtensionPackSignatureProjection",
    "AppKit.Core.ExtensionSupplyChainSupport",
    "AppKit.Core.FilterSet",
    "AppKit.Core.FullProductFabricSmoke",
    "AppKit.Core.GenericBuilder",
    "AppKit.Core.GenericStruct",
    "AppKit.Core.InstallResult",
    "AppKit.Core.InstallTemplate",
    "AppKit.Core.InstallationBinding",
    "AppKit.Core.InstallationRef",
    "AppKit.Core.InstallationRevisionEpochFence",
    "AppKit.Core.LeaseRequest",
    "AppKit.Core.LeaseRevocationEvidence",
    "AppKit.Core.LowerReceiptSummary",
    "AppKit.Core.LowerScopeRef",
    "AppKit.Core.MemoryControlSupport",
    "AppKit.Core.MemoryFragmentListRequest",
    "AppKit.Core.MemoryFragmentProjection",
    "AppKit.Core.MemoryFragmentProvenance",
    "AppKit.Core.MemoryInvalidationRequest",
    "AppKit.Core.MemoryPromotionRequest",
    "AppKit.Core.MemoryProofTokenLookup",
    "AppKit.Core.MemoryShareUpRequest",
    "AppKit.Core.NextStepPreview",
    "AppKit.Core.ObserverDescriptor",
    "AppKit.Core.OperatorAction",
    "AppKit.Core.OperatorActionRef",
    "AppKit.Core.OperatorActionRequest",
    "AppKit.Core.OperatorCommandProjection",
    "AppKit.Core.OperatorProjection",
    "AppKit.Core.OperatorSignalResult",
    "AppKit.Core.OperatorSurfaceProjection",
    "AppKit.Core.PageRequest",
    "AppKit.Core.PageResult",
    "AppKit.Core.PendingObligation",
    "AppKit.Core.PersistencePosture",
    "AppKit.Core.PrincipalRef",
    "AppKit.Core.ProductBoundaryNoBypassScan",
    "AppKit.Core.ProductCertification",
    "AppKit.Core.ProductFabricSupport",
    "AppKit.Core.ProductTenantContext",
    "AppKit.Core.ProjectRef",
    "AppKit.Core.ProjectionRequest",
    "AppKit.Core.ProjectionRef",
    "AppKit.Core.QueuePressureProjection",
    "AppKit.Core.ReadLease",
    "AppKit.Core.ReadLeaseRef",
    "AppKit.Core.Rejection",
    "AppKit.Core.RequestContext",
    "AppKit.Core.ResourceEffectInvocationRequest",
    "AppKit.Core.ResourcePath",
    "AppKit.Core.ResourceRef",
    "AppKit.Core.Result",
    "AppKit.Core.ReviewRequest",
    "AppKit.Core.RetryPostureProjection",
    "AppKit.Core.ReviewProjection",
    "AppKit.Core.ReviewTaskRef",
    "AppKit.Core.RevisionEpochSupport",
    "AppKit.Core.RunRef",
    "AppKit.Core.RunRequest",
    "AppKit.Core.RuntimeEventSummary",
    "AppKit.Core.RuntimeOperationRequest",
    "AppKit.Core.RuntimeFactsProjection",
    "AppKit.Core.RuntimeProjectionSupport",
    "AppKit.Core.RuntimeSurface.LiveEffectReceipt",
    "AppKit.Core.RuntimeSurface.RuntimeLogPage",
    "AppKit.Core.RuntimeSurface.RuntimeLogRow",
    "AppKit.Core.RuntimeSurface.RuntimeProfileApplyResult",
    "AppKit.Core.RuntimeSurface.RuntimeStatusSnapshot",
    "AppKit.Core.RuntimeSurface.Support",
    "AppKit.Core.SemanticContextExt",
    "AppKit.Core.SortSpec",
    "AppKit.Core.SourceCandidateRequest",
    "AppKit.Core.SourceCurrentStateRequest",
    "AppKit.Core.SourcePublicationRequest",
    "AppKit.Core.SourceSyncRequest",
    "AppKit.Core.SourceBindingProjection",
    "AppKit.Core.StreamAttachLease",
    "AppKit.Core.StreamAttachLeaseRef",
    "AppKit.Core.SubjectDetail",
    "AppKit.Core.SubjectRef",
    "AppKit.Core.SubjectRuntimeProjection",
    "AppKit.Core.SubjectSummary",
    "AppKit.Core.Support",
    "AppKit.Core.SuppressionVisibilityProjection",
    "AppKit.Core.SurfaceError",
    "AppKit.Core.SystemActorRef",
    "AppKit.Core.Telemetry",
    "AppKit.Core.TenantRef",
    "AppKit.Core.TimelineEvent",
    "AppKit.Core.ToolInvocationRequest",
    "AppKit.Core.TraceRequest",
    "AppKit.Core.TraceIdentity",
    "AppKit.Core.UnifiedTrace",
    "AppKit.Core.UnifiedTraceStep",
    "AppKit.Core.WorkflowContextExt",
    "AppKit.Core.WorkflowQueryRequest",
    "AppKit.Core.WorkflowRef",
    "AppKit.Core.WorkflowSignalRequest",
    "AppKit.Core.WorkflowStartRequest",
    "AppKit.Core.WorkspaceRef",
    "AppKit.Core.WorkSubmitRequest"
  ]

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
      path
      |> File.read!()
      |> String.split("\n")
      |> Enum.flat_map(&core_module_from_line/1)
    end)
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp core_module_from_line(line) do
    line = String.trim_leading(line)

    with true <- String.starts_with?(line, "defmodule "),
         [module, rest] <-
           line
           |> String.replace_prefix("defmodule ", "")
           |> String.split(" ", parts: 2),
         module = String.trim_trailing(module, ","),
         true <- core_module_line?(module, rest) do
      [module]
    else
      _other -> []
    end
  end

  defp core_module_line?(module, rest) do
    String.starts_with?(module, "AppKit.Core.") and String.contains?(rest, "do")
  end
end
