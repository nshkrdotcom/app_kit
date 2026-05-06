Code.require_file("workspace_contract.exs", __DIR__)

defmodule AppKit.Build.WeldContract do
  @moduledoc false

  @repo_root Path.expand("..", __DIR__)
  @jido_integration_repo_path Path.expand("../jido_integration", @repo_root)
  @jido_hive_repo_path Path.expand("../jido_hive", @repo_root)
  @mezzanine_repo_path Path.expand("../mezzanine", @repo_root)
  @outer_brain_repo_path Path.expand("../outer_brain", @repo_root)
  @aitrace_repo_path Path.expand("../AITrace", @repo_root)

  @dependencies [
    jido_integration_contracts: [
      opts:
        if File.dir?(@jido_integration_repo_path) do
          [
            git: @jido_integration_repo_path,
            subdir: "core/contracts",
            runtime: false,
            override: true
          ]
        else
          [
            github: "nshkrdotcom/jido_integration",
            branch: "main",
            subdir: "core/contracts",
            runtime: false,
            override: true
          ]
        end
    ],
    jido_hive_skill_contracts: [
      opts:
        if File.dir?(@jido_hive_repo_path) do
          [
            git: @jido_hive_repo_path,
            subdir: "core/skill_contracts",
            runtime: false,
            override: true
          ]
        else
          [
            github: "nshkrdotcom/jido_hive",
            branch: "main",
            subdir: "core/skill_contracts",
            runtime: false,
            override: true
          ]
        end
    ],
    jido_hive_agent_coordinator: [
      opts:
        if File.dir?(@jido_hive_repo_path) do
          [
            git: @jido_hive_repo_path,
            subdir: "core/agent_coordinator",
            runtime: false,
            override: true
          ]
        else
          [
            github: "nshkrdotcom/jido_hive",
            branch: "main",
            subdir: "core/agent_coordinator",
            runtime: false,
            override: true
          ]
        end
    ],
    jido_hive_inter_agent_messaging: [
      opts:
        if File.dir?(@jido_hive_repo_path) do
          [
            git: @jido_hive_repo_path,
            subdir: "core/inter_agent_messaging",
            runtime: false,
            override: true
          ]
        else
          [
            github: "nshkrdotcom/jido_hive",
            branch: "main",
            subdir: "core/inter_agent_messaging",
            runtime: false,
            override: true
          ]
        end
    ],
    jido_hive_shared_memory_facade: [
      opts:
        if File.dir?(@jido_hive_repo_path) do
          [
            git: @jido_hive_repo_path,
            subdir: "core/shared_memory_facade",
            runtime: false,
            override: true
          ]
        else
          [
            github: "nshkrdotcom/jido_hive",
            branch: "main",
            subdir: "core/shared_memory_facade",
            runtime: false,
            override: true
          ]
        end
    ],
    jido_hive_coordination_patterns: [
      opts:
        if File.dir?(@jido_hive_repo_path) do
          [
            git: @jido_hive_repo_path,
            subdir: "core/coordination_patterns",
            runtime: false,
            override: true
          ]
        else
          [
            github: "nshkrdotcom/jido_hive",
            branch: "main",
            subdir: "core/coordination_patterns",
            runtime: false,
            override: true
          ]
        end
    ],
    mezzanine_headless_coding_ops: [
      opts:
        if File.dir?(@mezzanine_repo_path) do
          [
            git: @mezzanine_repo_path,
            subdir: "core/headless_coding_ops",
            runtime: false,
            override: true
          ]
        else
          [
            github: "nshkrdotcom/mezzanine",
            branch: "main",
            subdir: "core/headless_coding_ops",
            runtime: false,
            override: true
          ]
        end
    ],
    outer_brain_memory_contracts: [
      opts:
        if File.dir?(@outer_brain_repo_path) do
          [
            git: @outer_brain_repo_path,
            sparse: "core/memory_contracts"
          ]
        else
          [
            github: "nshkrdotcom/outer_brain",
            branch: "main",
            sparse: "core/memory_contracts"
          ]
        end
    ],
    outer_brain_prompt_fabric: [
      opts:
        if File.dir?(@outer_brain_repo_path) do
          [
            git: @outer_brain_repo_path,
            sparse: "core/prompt_fabric"
          ]
        else
          [
            github: "nshkrdotcom/outer_brain",
            branch: "main",
            sparse: "core/prompt_fabric"
          ]
        end
    ],
    outer_brain_guardrail_contracts: [
      opts:
        if File.dir?(@outer_brain_repo_path) do
          [
            git: @outer_brain_repo_path,
            sparse: "core/guardrail_contracts"
          ]
        else
          [
            github: "nshkrdotcom/outer_brain",
            branch: "main",
            sparse: "core/guardrail_contracts"
          ]
        end
    ],
    ai_trace_replay_contracts: [
      opts:
        if File.dir?(@aitrace_repo_path) do
          [
            git: @aitrace_repo_path,
            sparse: "core/replay_contracts"
          ]
        else
          [
            github: "nshkrdotcom/AITrace",
            branch: "main",
            sparse: "core/replay_contracts"
          ]
        end
    ]
  ]

  @artifact_docs [
    "README.md",
    "docs/overview.md",
    "docs/layout.md",
    "docs/surfaces.md",
    "docs/composition.md"
  ]

  def manifest do
    [
      workspace: [
        root: "..",
        project_globs: AppKit.Build.WorkspaceContract.active_project_globs()
      ],
      classify: [
        tooling: ["."],
        proofs: ["examples/reference_host"]
      ],
      publication: [
        internal_only: [
          ".",
          "core/memory_surface",
          "core/context_budget_surface",
          "core/prompt_surface",
          "core/guardrail_surface",
          "core/eval_surface",
          "core/replay_surface",
          "core/cost_surface",
          "core/budget_surface",
          "core/skill_surface",
          "core/hive_surface",
          "web/components",
          "web/operator_console",
          "web/replay_viewer",
          "web/policy_authoring",
          "web/cost_dashboard",
          "web/eval_studio",
          "examples/reference_host"
        ]
      ],
      dependencies: @dependencies,
      artifacts: [
        app_kit_core: artifact()
      ]
    ]
  end

  def artifact do
    [
      roots: ["core/app_kit_core", "core/authority_projections", "core/headless_surface"],
      package: [
        name: "app_kit_core",
        otp_app: :app_kit_core,
        version: "0.1.0",
        description: "Projected northbound surface-core package from the AppKit workspace"
      ],
      output: [
        docs: @artifact_docs,
        assets: ["CHANGELOG.md", "LICENSE"]
      ],
      verify: [
        artifact_tests: ["packaging/weld/app_kit_core/test"],
        hex_build: false,
        hex_publish: false
      ]
    ]
  end
end

AppKit.Build.WeldContract.manifest()
