Code.require_file("workspace_contract.exs", __DIR__)

defmodule AppKit.Build.WeldContract do
  @moduledoc false

  @repo_root Path.expand("..", __DIR__)
  @jido_integration_repo_path Path.expand("../jido_integration", @repo_root)
  @mezzanine_repo_path Path.expand("../mezzanine", @repo_root)

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
