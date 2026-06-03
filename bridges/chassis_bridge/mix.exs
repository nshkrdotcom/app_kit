defmodule AppKit.ChassisBridge.MixProject do
  use Mix.Project

  def project do
    [
      app: :app_kit_chassis_bridge,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "AppKit SpatialGateway and EvolutionSurface bridge for Chassis"
    ]
  end

  def application do
    [
      mod: {AppKit.SpatialGateway.Application, []},
      extra_applications: [:logger]
    ]
  end

  def cli do
    [preferred_envs: [ci: :test]]
  end

  defp deps do
    [
      {:app_kit_core, path: "../../core/app_kit_core"},
      {:chassis_appkit_surface, path: "../../../chassis/governance/chassis_appkit_surface"},
      {:chassis_boundary, path: "../../../chassis/core/chassis_boundary"},
      {:chassis_releases, path: "../../../chassis/core/chassis_releases"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.40.1", only: :dev, runtime: false}
    ]
  end
end
