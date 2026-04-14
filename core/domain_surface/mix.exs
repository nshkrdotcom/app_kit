defmodule AppKitDomainSurface.MixProject do
  use Mix.Project

  @default_jido_domain_path Path.expand("../../../jido_domain", __DIR__)
  @jido_domain_path_env "APP_KIT_JIDO_DOMAIN_PATH"

  def project do
    [
      app: :app_kit_domain_surface,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "Typed app-facing composition above jido_domain",
      docs: [main: "readme", extras: ["README.md"]],
      name: "AppKit Domain Surface"
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
      {:app_kit_core, path: "../app_kit_core"},
      {:app_kit_app_config, path: "../app_config"},
      {:app_kit_domain_bridge, path: "../../bridges/domain_bridge"},
      {:app_kit_work_control, path: "../work_control"},
      {:app_kit_scope_objects, path: "../scope_objects"},
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
