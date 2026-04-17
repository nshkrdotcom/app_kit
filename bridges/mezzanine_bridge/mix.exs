defmodule AppKitMezzanineBridge.MixProject do
  use Mix.Project

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
    [extra_applications: [:logger]]
  end

  def cli do
    [preferred_envs: [test: :test, ci: :test]]
  end

  defp dialyzer do
    [plt_add_deps: :apps_tree, plt_core_path: Path.expand("_build/dialyzer_core", __DIR__)]
  end

  defp aliases do
    [
      test: ["ash.setup --quiet", "test"],
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
      {:mezzanine_ops_domain, path: "../../../mezzanine/core/ops_domain"},
      {:mezzanine_audit_engine, path: "../../../mezzanine/core/audit_engine"},
      {:mezzanine_execution_engine, path: "../../../mezzanine/core/execution_engine"},
      {:mezzanine_decision_engine, path: "../../../mezzanine/core/decision_engine"},
      {:mezzanine_evidence_engine, path: "../../../mezzanine/core/evidence_engine"},
      {:mezzanine_config_registry, path: "../../../mezzanine/core/config_registry"},
      {:mezzanine_pack_model, path: "../../../mezzanine/core/pack_model"},
      {:mezzanine_pack_compiler, path: "../../../mezzanine/core/pack_compiler"},
      {:mezzanine_core, path: "../../../mezzanine/core/mezzanine_core"},
      {:mezzanine_integration_bridge, path: "../../../mezzanine/bridges/integration_bridge"},
      {:ash, "~> 3.24"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.40.1", only: :dev, runtime: false}
    ]
  end
end
