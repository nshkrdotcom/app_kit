repo_root = Path.expand("..", __DIR__)
siblings_root = Path.expand("..", repo_root)

dep = fn repo, subdir, hex ->
  %{
    path: Path.join(siblings_root, "#{repo}/#{subdir}"),
    github: %{repo: "nshkrdotcom/#{repo}", branch: "main", subdir: subdir},
    hex: hex,
    default_order: [:path, :github, :hex],
    publish_order: [:hex]
  }
end

%{
  deps: %{
    ai_trace_replay_contracts: dep.("AITrace", "core/replay_contracts", "~> 0.1.0"),
    citadel_domain_surface: dep.("citadel", "surfaces/citadel_domain_surface", "~> 0.1.0"),
    execution_plane: %{
      path: Path.join(siblings_root, "execution_plane/core/execution_plane"),
      github: %{
        repo: "nshkrdotcom/execution_plane",
        branch: "main",
        subdir: "core/execution_plane"
      },
      hex: "~> 0.1.0",
      default_order: [:github, :hex, :path],
      publish_order: [:hex]
    },
    ground_plane_contracts: dep.("ground_plane", "core/ground_plane_contracts", "~> 0.1.0"),
    ground_plane_persistence_policy: dep.("ground_plane", "core/persistence_policy", "~> 0.1.0"),
    jido_hive_agent_coordinator: dep.("jido_hive", "core/agent_coordinator", "~> 0.1.0"),
    jido_hive_coordination_patterns: dep.("jido_hive", "core/coordination_patterns", "~> 0.1.0"),
    jido_hive_inter_agent_messaging: dep.("jido_hive", "core/inter_agent_messaging", "~> 0.1.0"),
    jido_hive_shared_memory_facade: dep.("jido_hive", "core/shared_memory_facade", "~> 0.1.0"),
    jido_hive_skill_contracts: dep.("jido_hive", "core/skill_contracts", "~> 0.1.0"),
    jido_integration_contracts: dep.("jido_integration", "core/contracts", "~> 0.1.0"),
    mezzanine_archival_engine: dep.("mezzanine", "core/archival_engine", "~> 0.1.0"),
    mezzanine_audit_engine: dep.("mezzanine", "core/audit_engine", "~> 0.1.0"),
    mezzanine_config_registry: dep.("mezzanine", "core/config_registry", "~> 0.1.0"),
    mezzanine_core: dep.("mezzanine", "core/mezzanine_core", "~> 0.1.0"),
    mezzanine_decision_engine: dep.("mezzanine", "core/decision_engine", "~> 0.1.0"),
    mezzanine_evidence_engine: dep.("mezzanine", "core/evidence_engine", "~> 0.1.0"),
    mezzanine_execution_engine: dep.("mezzanine", "core/execution_engine", "~> 0.1.0"),
    mezzanine_headless_coding_ops: dep.("mezzanine", "core/headless_coding_ops", "~> 0.1.0"),
    mezzanine_integration_bridge: dep.("mezzanine", "bridges/integration_bridge", "~> 0.1.0"),
    mezzanine_leasing: dep.("mezzanine", "core/leasing", "~> 0.1.0"),
    mezzanine_m1_m2_runtime: dep.("mezzanine", "core/m1_m2_runtime", "~> 0.1.0"),
    mezzanine_operator_engine: dep.("mezzanine", "core/operator_engine", "~> 0.1.0"),
    mezzanine_pack_compiler: dep.("mezzanine", "core/pack_compiler", "~> 0.1.0"),
    mezzanine_pack_model: dep.("mezzanine", "core/pack_model", "~> 0.1.0"),
    mezzanine_projection_engine: dep.("mezzanine", "core/projection_engine", "~> 0.1.0"),
    mezzanine_source_engine: dep.("mezzanine", "core/source_engine", "~> 0.1.0"),
    outer_brain_contracts: dep.("outer_brain", "core/outer_brain_contracts", "~> 0.1.0"),
    outer_brain_domain_bridge: dep.("outer_brain", "bridges/domain_bridge", "~> 0.1.0"),
    outer_brain_guardrail_contracts: dep.("outer_brain", "core/guardrail_contracts", "~> 0.1.0"),
    outer_brain_memory_contracts: dep.("outer_brain", "core/memory_contracts", "~> 0.1.0"),
    outer_brain_prompting: dep.("outer_brain", "core/outer_brain_prompting", "~> 0.1.0"),
    outer_brain_prompt_fabric: dep.("outer_brain", "core/prompt_fabric", "~> 0.1.0")
  }
}
