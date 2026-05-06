defmodule AppKitEvalStudio.MixProject do
  use Mix.Project

  def project do
    [
      app: :app_kit_eval_studio,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: [main: "readme", extras: ["README.md"]],
      dialyzer: [plt_add_deps: :apps_tree],
      name: "AppKit Eval Studio",
      description: "DTO-only eval suite, run, regression, replay, and drift studio"
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
      {:app_kit_eval_surface, path: "../../core/eval_surface"},
      {:app_kit_replay_surface, path: "../../core/replay_surface"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.40.1", only: :dev, runtime: false}
    ]
  end
end
