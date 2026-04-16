defmodule AppKitReviewSurface.MixProject do
  use Mix.Project

  def project do
    [
      app: :app_kit_review_surface,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      dialyzer: dialyzer(),
      description: "Typed review-queue and decision surface for the AppKit workspace",
      docs: [main: "readme", extras: ["README.md"]],
      name: "AppKit Review Surface"
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  def cli do
    [preferred_envs: [ci: :test]]
  end

  defp dialyzer do
    [plt_add_deps: :apps_tree, plt_core_path: Path.expand("_build/dialyzer_core", __DIR__)]
  end

  defp deps do
    [
      {:app_kit_core, path: "../app_kit_core"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.40.1", only: :dev, runtime: false}
    ]
  end
end
