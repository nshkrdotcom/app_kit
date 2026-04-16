defmodule AppKitMezzanineBridge.MixProject do
  use Mix.Project

  @default_mezzanine_app_kit_bridge_path Path.expand(
                                           "../../../mezzanine/bridges/app_kit_bridge",
                                           __DIR__
                                         )
  @mezzanine_app_kit_bridge_path_env "APP_KIT_MEZZANINE_APP_KIT_BRIDGE_PATH"

  def project do
    [
      app: :app_kit_mezzanine_bridge,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      dialyzer: dialyzer(),
      description: "Internal AppKit bridge over the mezzanine_app_kit_bridge service seam",
      docs: [main: "readme", extras: ["README.md"]],
      name: "AppKit Mezzanine Bridge"
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
      {:app_kit_core, path: "../../core/app_kit_core"},
      {:mezzanine_app_kit_bridge,
       path: mezzanine_app_kit_bridge_path(), runtime: Mix.env() != :test},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.40.1", only: :dev, runtime: false}
    ]
  end

  defp mezzanine_app_kit_bridge_path do
    System.get_env(
      @mezzanine_app_kit_bridge_path_env,
      @default_mezzanine_app_kit_bridge_path
    )
  end
end
