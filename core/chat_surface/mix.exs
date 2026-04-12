defmodule AppKitChatSurface.MixProject do
  use Mix.Project

  def project do
    [
      app: :app_kit_chat_surface,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "Host-facing chat entrypoints for the AppKit workspace",
      docs: [main: "readme", extras: ["README.md"]],
      name: "AppKit Chat Surface"
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
      {:app_kit_conversation_bridge, path: "../conversation_bridge"},
      {:app_kit_scope_objects, path: "../scope_objects"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.40.1", only: :dev, runtime: false}
    ]
  end
end
