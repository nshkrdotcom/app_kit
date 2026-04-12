defmodule AppKitWorkControl.MixProject do
  use Mix.Project

  def project do
    [
      app: :app_kit_work_control,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "Reusable work-control helpers for the AppKit workspace",
      docs: [main: "readme", extras: ["README.md"]],
      name: "AppKit Work Control"
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
      {:app_kit_core, path: "../app_kit_core"},
      {:app_kit_scope_objects, path: "../scope_objects"},
      {:app_kit_run_governance, path: "../run_governance"},
      {:app_kit_integration_bridge, path: "../../bridges/integration_bridge"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.40.1", only: :dev, runtime: false}
    ]
  end
end
