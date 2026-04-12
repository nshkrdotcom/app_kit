defmodule AppKit.Build.WeldContract do
  @moduledoc false

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
      artifacts: [
        app_kit_core: artifact()
      ]
    ]
  end

  def artifact do
    [
      roots: ["core/app_kit_core"],
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
