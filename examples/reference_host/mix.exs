defmodule AppKitReferenceHost.MixProject do
  use Mix.Project

  @citadel_domain_surface_path Path.expand(
                                 "../../../citadel/surfaces/citadel_domain_surface",
                                 __DIR__
                               )

  def project do
    [
      app: :app_kit_reference_host,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "Reference host proving the AppKit northbound composition path",
      docs: [main: "readme", extras: ["README.md"]],
      name: "AppKit Reference Host"
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
      {:app_kit_chat_surface, path: "../../core/chat_surface"},
      {:app_kit_domain_surface, path: "../../core/domain_surface"},
      {:app_kit_operator_surface, path: "../../core/operator_surface"},
      {:app_kit_runtime_gateway, path: "../../core/runtime_gateway"},
      {:app_kit_scope_objects, path: "../../core/scope_objects"},
      {:app_kit_core, path: "../../core/app_kit_core"},
      {:citadel_domain_surface, path: @citadel_domain_surface_path},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.40.1", only: :dev, runtime: false}
    ]
  end
end
