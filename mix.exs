defmodule AppKitCore.MixProject do
  use Mix.Project

  def project do
    [
      app: :app_kit_core,
      version: "0.1.0",
      build_path: "_build",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      erlc_paths: ["components/core/app_kit_core/src"],
      deps: deps(),
      description: "Projected northbound surface-core package from the AppKit workspace",
      package: package(),
      docs: docs()
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  def elixirc_paths(:test) do
    base = ["config", "components/core/app_kit_core/lib"]

    if File.dir?("test/support") do
      base ++ ["test/support"]
    else
      base
    end
  end

  def elixirc_paths(_env), do: ["config", "components/core/app_kit_core/lib"]

  defp deps do
    [
      {:ex_doc, "~> 0.40", [only: :dev, runtime: false]}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      maintainers: [],
      links: %{"Source" => "https://github.com/nshkrdotcom/app_kit"},
      files: [
        ".formatter.exs",
        "CHANGELOG.md",
        "LICENSE",
        "README.md",
        "components/core/app_kit_core",
        "config",
        "docs/composition.md",
        "docs/layout.md",
        "docs/overview.md",
        "docs/surfaces.md",
        "mix.exs",
        "projection.lock.json"
      ]
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: [
        "README.md",
        "docs/composition.md",
        "docs/layout.md",
        "docs/overview.md",
        "docs/surfaces.md"
      ]
    ]
  end
end
