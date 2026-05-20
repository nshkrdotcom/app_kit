%{
  deps: %{
    mezzanine_decision_engine: %{
      path: "../mezzanine/core/decision_engine",
      hex: "~> 0.1.0",
      github: %{
        repo: "nshkrdotcom/mezzanine",
        subdir: "core/decision_engine",
        branch: "main"
      },
      default_order: [:path, :github, :hex],
      publish_order: [:hex]
    },
    mezzanine_governed_effects: %{
      path: "../mezzanine/core/governed_effects",
      hex: "~> 0.1.0",
      github: %{
        repo: "nshkrdotcom/mezzanine",
        subdir: "core/governed_effects",
        branch: "main"
      },
      default_order: [:path, :github, :hex],
      publish_order: [:hex]
    },
    mezzanine_projection_engine: %{
      path: "../mezzanine/core/projection_engine",
      hex: "~> 0.1.0",
      github: %{
        repo: "nshkrdotcom/mezzanine",
        subdir: "core/projection_engine",
        branch: "main"
      },
      default_order: [:path, :github, :hex],
      publish_order: [:hex]
    },
    mezzanine_m1_m2_runtime: %{
      path: "../mezzanine/core/m1_m2_runtime",
      hex: "~> 0.1.0",
      github: %{
        repo: "nshkrdotcom/mezzanine",
        subdir: "core/m1_m2_runtime",
        branch: "main"
      },
      default_order: [:path, :github, :hex],
      publish_order: [:hex]
    },
    mezzanine_source_engine: %{
      path: "../mezzanine/core/source_engine",
      hex: "~> 0.1.0",
      github: %{
        repo: "nshkrdotcom/mezzanine",
        subdir: "core/source_engine",
        branch: "main"
      },
      default_order: [:path, :github, :hex],
      publish_order: [:hex]
    },
    ground_plane_contracts: %{
      path: "../ground_plane/core/ground_plane_contracts",
      hex: "~> 0.1.0",
      github: %{
        repo: "nshkrdotcom/ground_plane",
        subdir: "core/ground_plane_contracts",
        branch: "main"
      },
      default_order: [:path, :github, :hex],
      publish_order: [:hex]
    },
    jido_hive_inter_agent_messaging: %{
      path: "../jido_hive/core/inter_agent_messaging",
      hex: "~> 0.1.0",
      github: %{
        repo: "nshkrdotcom/jido_hive",
        subdir: "core/inter_agent_messaging",
        branch: "main"
      },
      default_order: [:path, :github, :hex],
      publish_order: [:hex]
    },
    mezzanine_core: %{
      path: "../mezzanine/core/mezzanine_core",
      hex: "~> 0.1.0",
      github: %{
        repo: "nshkrdotcom/mezzanine",
        subdir: "core/mezzanine_core",
        branch: "main"
      },
      default_order: [:path, :github, :hex],
      publish_order: [:hex]
    },
    jido_integration_contracts: %{
      path: "../jido_integration/core/contracts",
      hex: "~> 0.1.0",
      github: %{
        repo: "nshkrdotcom/jido_integration",
        subdir: "core/contracts",
        branch: "main"
      },
      default_order: [:path, :github, :hex],
      publish_order: [:hex]
    },
    mezzanine_pack_compiler: %{
      path: "../mezzanine/core/pack_compiler",
      hex: "~> 0.1.0",
      github: %{
        repo: "nshkrdotcom/mezzanine",
        subdir: "core/pack_compiler",
        branch: "main"
      },
      default_order: [:path, :github, :hex],
      publish_order: [:hex]
    },
    outer_brain_domain_bridge: %{
      path: "../outer_brain/bridges/domain_bridge",
      hex: "~> 0.1.0",
      github: %{
        repo: "nshkrdotcom/outer_brain",
        subdir: "bridges/domain_bridge",
        branch: "main"
      },
      default_order: [:path, :github, :hex],
      publish_order: [:hex]
    },
    mezzanine_evidence_engine: %{
      path: "../mezzanine/core/evidence_engine",
      hex: "~> 0.1.0",
      github: %{
        repo: "nshkrdotcom/mezzanine",
        subdir: "core/evidence_engine",
        branch: "main"
      },
      default_order: [:path, :github, :hex],
      publish_order: [:hex]
    },
    mezzanine_headless_coding_ops: %{
      path: "../mezzanine/core/headless_coding_ops",
      hex: "~> 0.1.0",
      github: %{
        repo: "nshkrdotcom/mezzanine",
        subdir: "core/headless_coding_ops",
        branch: "main"
      },
      default_order: [:path, :github, :hex],
      publish_order: [:hex]
    },
    mezzanine_leasing: %{
      path: "../mezzanine/core/leasing",
      hex: "~> 0.1.0",
      github: %{
        repo: "nshkrdotcom/mezzanine",
        subdir: "core/leasing",
        branch: "main"
      },
      default_order: [:path, :github, :hex],
      publish_order: [:hex]
    },
    citadel_domain_surface: %{
      path: "../citadel/surfaces/citadel_domain_surface",
      hex: "~> 0.1.0",
      github: %{
        repo: "nshkrdotcom/citadel",
        subdir: "surfaces/citadel_domain_surface",
        branch: "main"
      },
      default_order: [:path, :github, :hex],
      publish_order: [:hex]
    },
    mezzanine_operator_engine: %{
      path: "../mezzanine/core/operator_engine",
      hex: "~> 0.1.0",
      github: %{
        repo: "nshkrdotcom/mezzanine",
        subdir: "core/operator_engine",
        branch: "main"
      },
      default_order: [:path, :github, :hex],
      publish_order: [:hex]
    },
    jido_hive_skill_contracts: %{
      path: "../jido_hive/core/skill_contracts",
      hex: "~> 0.1.0",
      github: %{
        repo: "nshkrdotcom/jido_hive",
        subdir: "core/skill_contracts",
        branch: "main"
      },
      default_order: [:path, :github, :hex],
      publish_order: [:hex]
    },
    execution_plane: %{
      path: "../execution_plane/core/execution_plane",
      hex: "~> 0.1.0",
      github: %{
        repo: "nshkrdotcom/execution_plane",
        subdir: "core/execution_plane",
        branch: "main"
      },
      default_order: [:github, :hex, :path],
      publish_order: [:hex]
    },
    outer_brain_contracts: %{
      path: "../outer_brain/core/outer_brain_contracts",
      hex: "~> 0.1.0",
      github: %{
        repo: "nshkrdotcom/outer_brain",
        subdir: "core/outer_brain_contracts",
        branch: "main"
      },
      default_order: [:path, :github, :hex],
      publish_order: [:hex]
    },
    ground_plane_persistence_policy: %{
      path: "../ground_plane/core/persistence_policy",
      hex: "~> 0.1.0",
      github: %{
        repo: "nshkrdotcom/ground_plane",
        subdir: "core/persistence_policy",
        branch: "main"
      },
      default_order: [:path, :github, :hex],
      publish_order: [:hex]
    },
    outer_brain_prompt_fabric: %{
      path: "../outer_brain/core/prompt_fabric",
      hex: "~> 0.1.0",
      github: %{
        repo: "nshkrdotcom/outer_brain",
        subdir: "core/prompt_fabric",
        branch: "main"
      },
      default_order: [:path, :github, :hex],
      publish_order: [:hex]
    },
    mezzanine_audit_engine: %{
      path: "../mezzanine/core/audit_engine",
      hex: "~> 0.1.0",
      github: %{
        repo: "nshkrdotcom/mezzanine",
        subdir: "core/audit_engine",
        branch: "main"
      },
      default_order: [:path, :github, :hex],
      publish_order: [:hex]
    },
    jido_hive_coordination_patterns: %{
      path: "../jido_hive/core/coordination_patterns",
      hex: "~> 0.1.0",
      github: %{
        repo: "nshkrdotcom/jido_hive",
        subdir: "core/coordination_patterns",
        branch: "main"
      },
      default_order: [:path, :github, :hex],
      publish_order: [:hex]
    },
    mezzanine_pack_model: %{
      path: "../mezzanine/core/pack_model",
      hex: "~> 0.1.0",
      github: %{
        repo: "nshkrdotcom/mezzanine",
        subdir: "core/pack_model",
        branch: "main"
      },
      default_order: [:path, :github, :hex],
      publish_order: [:hex]
    },
    outer_brain_memory_contracts: %{
      path: "../outer_brain/core/memory_contracts",
      hex: "~> 0.1.0",
      github: %{
        repo: "nshkrdotcom/outer_brain",
        subdir: "core/memory_contracts",
        branch: "main"
      },
      default_order: [:path, :github, :hex],
      publish_order: [:hex]
    },
    jido_hive_shared_memory_facade: %{
      path: "../jido_hive/core/shared_memory_facade",
      hex: "~> 0.1.0",
      github: %{
        repo: "nshkrdotcom/jido_hive",
        subdir: "core/shared_memory_facade",
        branch: "main"
      },
      default_order: [:path, :github, :hex],
      publish_order: [:hex]
    },
    mezzanine_config_registry: %{
      path: "../mezzanine/core/config_registry",
      hex: "~> 0.1.0",
      github: %{
        repo: "nshkrdotcom/mezzanine",
        subdir: "core/config_registry",
        branch: "main"
      },
      default_order: [:path, :github, :hex],
      publish_order: [:hex]
    },
    outer_brain_guardrail_contracts: %{
      path: "../outer_brain/core/guardrail_contracts",
      hex: "~> 0.1.0",
      github: %{
        repo: "nshkrdotcom/outer_brain",
        subdir: "core/guardrail_contracts",
        branch: "main"
      },
      default_order: [:path, :github, :hex],
      publish_order: [:hex]
    },
    jido_hive_agent_coordinator: %{
      path: "../jido_hive/core/agent_coordinator",
      hex: "~> 0.1.0",
      github: %{
        repo: "nshkrdotcom/jido_hive",
        subdir: "core/agent_coordinator",
        branch: "main"
      },
      default_order: [:path, :github, :hex],
      publish_order: [:hex]
    },
    outer_brain_prompting: %{
      path: "../outer_brain/core/outer_brain_prompting",
      hex: "~> 0.1.0",
      github: %{
        repo: "nshkrdotcom/outer_brain",
        subdir: "core/outer_brain_prompting",
        branch: "main"
      },
      default_order: [:path, :github, :hex],
      publish_order: [:hex]
    },
    ai_trace_replay_contracts: %{
      path: "../AITrace/core/replay_contracts",
      hex: "~> 0.1.0",
      github: %{
        repo: "nshkrdotcom/AITrace",
        subdir: "core/replay_contracts",
        branch: "main"
      },
      default_order: [:path, :github, :hex],
      publish_order: [:hex]
    },
    mezzanine_execution_engine: %{
      path: "../mezzanine/core/execution_engine",
      hex: "~> 0.1.0",
      github: %{
        repo: "nshkrdotcom/mezzanine",
        subdir: "core/execution_engine",
        branch: "main"
      },
      default_order: [:path, :github, :hex],
      publish_order: [:hex]
    },
    mezzanine_integration_bridge: %{
      path: "../mezzanine/bridges/integration_bridge",
      hex: "~> 0.1.0",
      github: %{
        repo: "nshkrdotcom/mezzanine",
        subdir: "bridges/integration_bridge",
        branch: "main"
      },
      default_order: [:path, :github, :hex],
      publish_order: [:hex]
    },
    mezzanine_archival_engine: %{
      path: "../mezzanine/core/archival_engine",
      hex: "~> 0.1.0",
      github: %{
        repo: "nshkrdotcom/mezzanine",
        subdir: "core/archival_engine",
        branch: "main"
      },
      default_order: [:path, :github, :hex],
      publish_order: [:hex]
    }
  }
}
