unless Code.ensure_loaded?(DependencySources) do
  Code.require_file("../../build_support/dependency_sources.exs", __DIR__)
end

defmodule AppKit.ChassisBridge.MixProject do
  use Mix.Project

  @repo_root Path.expand("../..", __DIR__)

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
      DependencySources.dep(:chassis_appkit_surface, @repo_root),
      DependencySources.dep(:chassis_boundary, @repo_root),
      DependencySources.dep(:chassis_releases, @repo_root),
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.40.1", only: :dev, runtime: false}
    ]
  end
end
