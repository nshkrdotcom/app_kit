defmodule AppKitOperatorConsole.MixProject do
  use Mix.Project

  def project do
    [
      app: :app_kit_operator_console,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: [main: "readme", extras: ["README.md"]],
      dialyzer: [plt_add_deps: :apps_tree],
      name: "AppKit Operator Console",
      description: "DTO-only operator console shell and authorization render contracts"
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  def cli do
    [preferred_envs: [ci: :test]]
  end

  defp deps do
    [
      {:app_kit_web_components, path: "../components"},
      {:app_kit_replay_viewer, path: "../replay_viewer"},
      {:app_kit_policy_authoring, path: "../policy_authoring"},
      {:app_kit_cost_dashboard, path: "../cost_dashboard"},
      {:app_kit_eval_studio, path: "../eval_studio"},
      {:app_kit_app_config, path: "../../core/app_config"},
      {:app_kit_memory_surface, path: "../../core/memory_surface"},
      {:app_kit_prompt_surface, path: "../../core/prompt_surface"},
      {:app_kit_guardrail_surface, path: "../../core/guardrail_surface"},
      {:app_kit_replay_surface, path: "../../core/replay_surface"},
      {:app_kit_cost_surface, path: "../../core/cost_surface"},
      {:app_kit_budget_surface, path: "../../core/budget_surface"},
      {:app_kit_eval_surface, path: "../../core/eval_surface"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.40.1", only: :dev, runtime: false}
    ]
  end
end
