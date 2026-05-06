defmodule AppKitCostDashboard.MixProject do
  use Mix.Project

  def project do
    [
      app: :app_kit_cost_dashboard,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: [main: "readme", extras: ["README.md"]],
      dialyzer: [plt_add_deps: :apps_tree],
      name: "AppKit Cost Dashboard",
      description: "DTO-only cost and budget dashboard render contracts"
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
      {:app_kit_cost_surface, path: "../../core/cost_surface"},
      {:app_kit_budget_surface, path: "../../core/budget_surface"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.40.1", only: :dev, runtime: false}
    ]
  end
end
