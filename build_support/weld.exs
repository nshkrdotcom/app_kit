unless Code.ensure_loaded?(DependencySources) do
  Code.require_file("dependency_sources.exs", __DIR__)
end

Code.require_file("workspace_contract.exs", __DIR__)

defmodule AppKit.Build.WeldContract do
  @moduledoc false

  alias AppKit.Build.WorkspaceContract

  @repo_root Path.expand("..", __DIR__)

  @manifest_dependencies [
    :jido_integration_contracts,
    :jido_integration_v2_tool_contracts,
    :jido_hive_agent_coordinator,
    :jido_hive_inter_agent_messaging,
    :jido_hive_shared_memory_facade,
    :jido_hive_coordination_patterns,
    :mezzanine_headless_coding_ops,
    :outer_brain_memory_contracts,
    :outer_brain_prompt_fabric,
    :outer_brain_guardrail_contracts,
    :ai_trace_replay_contracts
  ]

  @runtime_false_override [
    runtime: false,
    override: true
  ]

  @manifest_dependency_opts %{
    jido_integration_contracts: @runtime_false_override,
    jido_integration_v2_tool_contracts: @runtime_false_override,
    jido_hive_agent_coordinator: @runtime_false_override,
    jido_hive_inter_agent_messaging: @runtime_false_override,
    jido_hive_shared_memory_facade: @runtime_false_override,
    jido_hive_coordination_patterns: @runtime_false_override,
    mezzanine_headless_coding_ops: @runtime_false_override
  }

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
        project_globs: WorkspaceContract.active_project_globs()
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
          "core/model_surface",
          "core/optimization_surface",
          "core/coordination_surface",
          "core/adaptive_control_surface",
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
      dependencies: dependencies(),
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

  defp dependencies do
    Enum.map(@manifest_dependencies, fn app ->
      {app, manifest_dependency(app)}
    end)
  end

  defp manifest_dependency(app) do
    config = Map.fetch!(dependency_configs(), app)
    github = Map.fetch!(config, :github)
    extra_opts = Map.get(@manifest_dependency_opts, app, [])

    [opts: Keyword.merge(github_opts(github), extra_opts)]
  end

  defp dependency_configs do
    config = DependencySources.config!(@repo_root)
    Map.new(config[:deps], fn {app, dep_config} -> {app, Map.new(dep_config)} end)
  end

  defp github_opts(github) do
    github = Map.new(github)
    repo = Map.fetch!(github, :repo)

    opts =
      github
      |> Map.take([:branch, :ref, :tag, :subdir])
      |> Enum.sort_by(fn {key, _value} -> key end)

    Keyword.merge([github: repo], opts)
  end
end

AppKit.Build.WeldContract.manifest()
