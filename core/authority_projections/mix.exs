defmodule AppKitAuthorityProjections.MixProject do
  use Mix.Project

  def project do
    [
      app: :app_kit_authority_projections,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "Ref-only authority projection DTOs for AppKit surfaces",
      docs: [main: "readme", extras: ["README.md"]],
      name: "AppKit Authority Projections"
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
      {:app_kit_app_config, path: "../app_config"},
      {:app_kit_run_governance, path: "../run_governance"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.40.1", only: :dev, runtime: false}
    ]
  end
end
