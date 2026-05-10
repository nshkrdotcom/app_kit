unless Code.ensure_loaded?(DependencySources) do
  Code.require_file("build_support/dependency_sources.exs", __DIR__)
end

Code.require_file("build_support/workspace_contract.exs", __DIR__)

defmodule AppKit.Workspace.MixProject do
  use Mix.Project

  alias AppKit.Build.WorkspaceContract

  @version "0.1.0"
  @source_url "https://github.com/nshkrdotcom/app_kit"

  def project do
    [
      app: :app_kit_workspace,
      version: @version,
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      consolidate_protocols: false,
      deps: deps(),
      aliases: aliases(),
      blitz_workspace: blitz_workspace(),
      dialyzer: dialyzer(),
      docs: docs(),
      source_url: @source_url,
      homepage_url: @source_url,
      name: "AppKit Workspace",
      description: "Workspace root for the AppKit northbound application-surface monorepo"
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  def cli do
    [
      preferred_envs: [
        ci: :test,
        "monorepo.test": :test,
        "monorepo.credo": :test,
        "monorepo.dialyzer": :test,
        "monorepo.docs": :dev
      ]
    ]
  end

  defp deps do
    [
      {:blitz, "~> 0.3.0", runtime: false},
      {:weld, "~> 0.8.2", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.40.1", only: :dev, runtime: false}
    ]
  end

  defp aliases do
    monorepo_aliases = [
      "monorepo.deps.get": ["blitz.workspace.impact deps_get --"],
      "monorepo.format": ["blitz.workspace.impact format --"],
      "monorepo.compile": ["blitz.workspace.impact compile --"],
      "monorepo.test": ["blitz.workspace.impact test --"],
      "monorepo.credo": ["blitz.workspace.impact credo --"],
      "monorepo.dialyzer": ["blitz.workspace.impact dialyzer --"],
      "monorepo.docs": ["blitz.workspace.impact docs --"]
    ]

    [
      ci: [
        "deps.get",
        "monorepo.deps.get",
        "monorepo.format --check-formatted",
        "app_kit.schema_registry.verify",
        "app_kit.no_bypass.scan --profile hazmat --include core/**/*.ex --include bridges/**/*.ex --include web/**/*.ex --include examples/**/*.ex",
        "test",
        "monorepo.compile",
        "monorepo.test",
        "monorepo.credo --strict",
        "monorepo.dialyzer",
        "monorepo.docs",
        "weld.verify"
      ],
      "docs.root": ["docs"]
    ] ++ monorepo_aliases
  end

  defp dialyzer do
    [
      plt_add_deps: :apps_direct,
      plt_add_apps: [:mix, :blitz, :weld]
    ]
  end

  defp blitz_workspace do
    [
      root: __DIR__,
      projects: WorkspaceContract.active_project_globs(),
      isolation: [
        deps_path: true,
        build_path: true,
        lockfile: true,
        hex_home: "_build/hex"
      ],
      parallelism: [
        env: "APP_KIT_MONOREPO_MAX_CONCURRENCY",
        max_concurrency: nil,
        multiplier: :auto,
        base: [
          deps_get: 4,
          format: 4,
          compile: 4,
          test: 4,
          credo: 2,
          dialyzer: 4,
          docs: 4
        ],
        overrides: []
      ],
      tasks: [
        deps_get: [args: ["deps.get"], preflight?: false],
        format: [args: ["format"]],
        compile: [args: ["compile", "--warnings-as-errors"]],
        test: [args: ["test"], mix_env: "test", color: true],
        credo: [args: ["credo"]],
        dialyzer: [args: ["dialyzer", "--force-check"], mix_env: "test"],
        docs: [args: ["docs"]]
      ]
    ]
  end

  defp docs do
    [
      main: "workspace_readme",
      name: "AppKit Workspace",
      logo: "assets/app_kit.svg",
      assets: %{"assets" => "assets"},
      source_ref: "main",
      source_url: @source_url,
      homepage_url: @source_url,
      extras: [
        {"README.md", filename: "workspace_readme"},
        "docs/overview.md",
        "docs/layout.md",
        "docs/surfaces.md",
        "docs/composition.md",
        "CHANGELOG.md",
        "LICENSE"
      ],
      groups_for_extras: [
        Overview: ["README.md", "docs/overview.md"],
        Architecture: ["docs/layout.md", "docs/surfaces.md"],
        Composition: ["docs/composition.md"],
        Project: ["CHANGELOG.md", "LICENSE"]
      ]
    ]
  end
end
