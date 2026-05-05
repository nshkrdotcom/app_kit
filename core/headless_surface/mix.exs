defmodule AppKitHeadlessSurface.MixProject do
  use Mix.Project

  def project do
    [
      app: :app_kit_headless_surface,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "HTTP-safe headless surface contracts over governed coding ops",
      docs: [main: "readme", extras: ["README.md"]],
      name: "AppKit Headless Surface"
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
      {:app_kit_core, path: "../app_kit_core", runtime: false},
      {:app_kit_scope_objects, path: "../scope_objects", runtime: false},
      {:app_kit_run_governance, path: "../run_governance", runtime: false},
      {:app_kit_runtime_gateway, path: "../runtime_gateway", runtime: false},
      {:app_kit_authority_projections, path: "../authority_projections", runtime: false},
      {:mezzanine_headless_coding_ops,
       path: "../../../mezzanine/core/headless_coding_ops", runtime: false},
      {:jido_integration_contracts,
       path: "../../../jido_integration/core/contracts", override: true, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.40.1", only: :dev, runtime: false}
    ]
  end
end
