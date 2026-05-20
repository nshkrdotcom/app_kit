unless Code.ensure_loaded?(DependencySources) do
  Code.require_file("../../build_support/dependency_sources.exs", __DIR__)
end

defmodule AppKitMezzanineBridge.MixProject do
  use Mix.Project

  @repo_root Path.expand("../..", __DIR__)

  def project do
    [
      app: :app_kit_mezzanine_bridge,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      dialyzer: dialyzer(),
      description: "Internal AppKit bridge over lower-backed Mezzanine service modules",
      docs: [main: "readme", extras: ["README.md"]],
      name: "AppKit Mezzanine Bridge"
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {AppKit.Bridges.MezzanineBridge.Application, []}
    ]
  end

  def cli do
    [preferred_envs: [test: :test, ci: :test]]
  end

  defp dialyzer do
    [plt_add_deps: :apps_tree, plt_core_path: Path.expand("_build/dialyzer_core", __DIR__)]
  end

  defp aliases do
    [
      test: ["ash.setup --quiet", "leasing.migrate", "test"],
      "leasing.migrate": [
        "ecto.migrate -r Mezzanine.Execution.Repo --migrations-path ../../../mezzanine/core/leasing/priv/repo/migrations"
      ],
      ci: [
        "format --check-formatted",
        "compile --warnings-as-errors",
        "cmd env MIX_ENV=test mix test",
        "credo --strict",
        "cmd env MIX_ENV=dev mix dialyzer --force-check",
        "cmd env MIX_ENV=dev mix docs --warnings-as-errors"
      ]
    ]
  end

  defp deps do
    [
      {:app_kit_core, path: "../../core/app_kit_core"},
      {:app_kit_run_governance, path: "../../core/run_governance"},
      DependencySources.dep(:execution_plane, @repo_root, override: true),
      DependencySources.dep(:ground_plane_contracts, @repo_root, override: true),
      DependencySources.dep(:ground_plane_persistence_policy, @repo_root, override: true),
      DependencySources.dep(:jido_integration_contracts, @repo_root, override: true),
      DependencySources.dep(:mezzanine_audit_engine, @repo_root),
      DependencySources.dep(:mezzanine_execution_engine, @repo_root),
      DependencySources.dep(:mezzanine_leasing, @repo_root),
      DependencySources.dep(:mezzanine_m1_m2_runtime, @repo_root),
      DependencySources.dep(:mezzanine_operator_engine, @repo_root),
      DependencySources.dep(:mezzanine_projection_engine, @repo_root),
      DependencySources.dep(:mezzanine_source_engine, @repo_root),
      DependencySources.dep(:mezzanine_decision_engine, @repo_root),
      DependencySources.dep(:mezzanine_governed_effects, @repo_root),
      DependencySources.dep(:mezzanine_evidence_engine, @repo_root),
      DependencySources.dep(:mezzanine_archival_engine, @repo_root),
      DependencySources.dep(:mezzanine_config_registry, @repo_root),
      DependencySources.dep(:mezzanine_pack_model, @repo_root),
      DependencySources.dep(:mezzanine_pack_compiler, @repo_root),
      DependencySources.dep(:mezzanine_core, @repo_root),
      DependencySources.dep(:mezzanine_integration_bridge, @repo_root),
      {:ash, "~> 3.24"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.40.1", only: :dev, runtime: false}
    ]
  end
end
