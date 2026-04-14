defmodule AppKitOperatorSurface.MixProject do
  use Mix.Project

  def project do
    [
      app: :app_kit_operator_surface,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      dialyzer: dialyzer(),
      description: "Operator-facing composition around review and projection reads",
      docs: [main: "readme", extras: ["README.md"]],
      name: "AppKit Operator Surface"
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  def cli do
    [preferred_envs: [ci: :test]]
  end

  defp dialyzer do
    [plt_add_deps: :apps_tree]
  end

  defp deps do
    [
      {:app_kit_core, path: "../app_kit_core"},
      {:app_kit_app_config, path: "../app_config"},
      {:app_kit_run_governance, path: "../run_governance"},
      {:app_kit_integration_bridge, path: "../../bridges/integration_bridge"},
      {:app_kit_projection_bridge, path: "../../bridges/projection_bridge"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.40.1", only: :dev, runtime: false}
    ]
  end
end
