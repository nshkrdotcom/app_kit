defmodule AppKitDomainBridge.MixProject do
  use Mix.Project

  @default_jido_domain_path "/home/home/p/g/n/jido_domain"
  @jido_domain_path_env "APP_KIT_JIDO_DOMAIN_PATH"

  def project do
    [
      app: :app_kit_domain_bridge,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "App-facing bridge over the jido_domain seam",
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
      {:jido_domain, path: jido_domain_path()},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.40.1", only: :dev, runtime: false}
    ]
  end

  defp jido_domain_path do
    System.get_env(@jido_domain_path_env, @default_jido_domain_path)
  end
end
