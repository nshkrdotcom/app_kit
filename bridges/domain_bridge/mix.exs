defmodule AppKitDomainBridge.MixProject do
  use Mix.Project

  @citadel_domain_surface_path Path.expand(
                                 "../../../citadel/surfaces/citadel_domain_surface",
                                 __DIR__
                               )

  def project do
    [
      app: :app_kit_domain_bridge,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "App-facing bridge over the citadel_domain_surface seam",
      docs: [main: "readme", extras: ["README.md"]],
      name: "AppKit Domain Bridge"
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
      {:app_kit_core, path: "../../core/app_kit_core"},
      {:app_kit_scope_objects, path: "../../core/scope_objects"},
      {:citadel_domain_surface, path: @citadel_domain_surface_path},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.40.1", only: :dev, runtime: false}
    ]
  end
end
