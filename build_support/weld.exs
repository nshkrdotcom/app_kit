Code.require_file("workspace_contract.exs", __DIR__)

defmodule AppKit.Build.WeldContract do
  @moduledoc false

  @repo_root Path.expand("..", __DIR__)
  @jido_integration_repo_path Path.expand("../jido_integration", @repo_root)
  @mezzanine_repo_path Path.expand("../mezzanine", @repo_root)

  @mezzanine_dependencies [
    mezzanine_archival_engine: "core/archival_engine",
    mezzanine_audit_engine: "core/audit_engine",
    mezzanine_barriers: "core/barriers",
    mezzanine_config_registry: "core/config_registry",
    mezzanine_core: "core/mezzanine_core",
    mezzanine_decision_engine: "core/decision_engine",
    mezzanine_evidence_engine: "core/evidence_engine",
    mezzanine_execution_engine: "core/execution_engine",
    mezzanine_integration_bridge: "bridges/integration_bridge",
    mezzanine_leasing: "core/leasing",
    mezzanine_lifecycle_engine: "core/lifecycle_engine",
    mezzanine_m1_m2_runtime: "core/m1_m2_runtime",
    mezzanine_object_engine: "core/object_engine",
    mezzanine_operator_engine: "core/operator_engine",
    mezzanine_ops_domain: "core/ops_domain",
    mezzanine_ops_model: "core/ops_model",
    mezzanine_pack_compiler: "core/pack_compiler",
    mezzanine_pack_model: "core/pack_model",
    mezzanine_projection_engine: "core/projection_engine",
    mezzanine_runtime_scheduler: "core/runtime_scheduler",
    mezzanine_source_engine: "core/source_engine",
    mezzanine_workflow_runtime: "core/workflow_runtime",
    mezzanine_workspace_build_model: "core/workspace_build_model"
  ]

  @dependencies [
                  jido_integration_contracts: [
                    opts:
                      if File.dir?(@jido_integration_repo_path) do
                        [git: @jido_integration_repo_path, subdir: "core/contracts"]
                      else
                        [
                          github: "nshkrdotcom/jido_integration",
                          branch: "main",
                          subdir: "core/contracts"
                        ]
                      end
                  ],
                  mezzanine_headless_coding_ops: [
                    opts:
                      if File.dir?(@mezzanine_repo_path) do
                        [
                          git: @mezzanine_repo_path,
                          subdir: "core/headless_coding_ops",
                          override: true
                        ]
                      else
                        [
                          github: "nshkrdotcom/mezzanine",
                          branch: "main",
                          subdir: "core/headless_coding_ops",
                          override: true
                        ]
                      end
                  ]
                ] ++
                  Enum.map(@mezzanine_dependencies, fn {app, subdir} ->
                    {app,
                     [
                       opts:
                         if File.dir?(@mezzanine_repo_path) do
                           [git: @mezzanine_repo_path, subdir: subdir, override: true]
                         else
                           [
                             github: "nshkrdotcom/mezzanine",
                             branch: "main",
                             subdir: subdir,
                             override: true
                           ]
                         end
                     ]}
                  end)

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
        internal_only: [".", "examples/reference_host"]
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
