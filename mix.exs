defmodule AppKit.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/nshkrdotcom/app_kit"
  @description "Shared app-facing surface monorepo for composition, wiring, host-facing surfaces, and reusable entrypoints across the nshkr platform core."

  def project do
    [
      app: :app_kit,
      version: @version,
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      description: @description,
      package: package(),
      docs: docs(),
      source_url: @source_url,
      homepage_url: @source_url,
      name: "AppKit"
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {AppKit.Application, []}
    ]
  end

  def cli do
    [
      preferred_envs: [
        ci: :test
      ]
    ]
  end

  defp deps do
    [
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.38", only: :dev, runtime: false}
    ]
  end

  defp aliases do
    [
      ci: [
        "format --check-formatted",
        "compile --warnings-as-errors",
        "test"
      ]
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      maintainers: ["nshkrdotcom"],
      links: %{
        "GitHub" => @source_url
      },
      files: ~w(.formatter.exs CHANGELOG.md LICENSE README.md assets docs lib mix.exs test)
    ]
  end

  defp docs do
    [
      main: "readme",
      name: "AppKit",
      logo: "assets/app_kit.svg",
      assets: %{"assets" => "assets"},
      source_ref: "main",
      source_url: @source_url,
      homepage_url: @source_url,
      extras: [
        "README.md",
        "docs/overview.md",
        "docs/surfaces.md",
        "docs/composition.md",
        "CHANGELOG.md",
        "LICENSE"
      ],
      groups_for_extras: [
        Overview: ["README.md", "docs/overview.md"],
        Surfaces: ["docs/surfaces.md", "docs/composition.md"],
        Project: ["CHANGELOG.md", "LICENSE"]
      ]
    ]
  end
end
