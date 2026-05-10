unless Code.ensure_loaded?(DependencySources) do
  Code.require_file("../../build_support/dependency_sources.exs", __DIR__)
end

defmodule AppKitOuterBrainBridge.MixProject do
  use Mix.Project

  @repo_root Path.expand("../..", __DIR__)

  def project do
    [
      app: :app_kit_outer_brain_bridge,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "App-facing bridge over the outer_brain seam",
      docs: [main: "readme", extras: ["README.md"]],
      name: "AppKit Outer Brain Bridge"
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
      {:app_kit_memory_surface, path: "../../core/memory_surface"},
      {:app_kit_scope_objects, path: "../../core/scope_objects"},
      DependencySources.dep(:outer_brain_contracts, @repo_root),
      DependencySources.dep(:outer_brain_domain_bridge, @repo_root),
      DependencySources.dep(:outer_brain_prompting, @repo_root),
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.40.1", only: :dev, runtime: false}
    ]
  end
end
