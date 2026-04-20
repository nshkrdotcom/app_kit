defmodule Mix.Tasks.AppKit.SchemaRegistry.Verify do
  @shortdoc "Verify the Phase 4 AppKit schema registry"

  @moduledoc """
  Verifies the AppKit schema registry used by generated SDK/BFF boundary
  artifacts.

      mix app_kit.schema_registry.verify
  """

  use Mix.Task

  alias AppKit.Workspace.SchemaRegistry

  @impl true
  def run(_args) do
    SchemaRegistry.validate_all!()
    SchemaRegistry.validate_core_dto_surface!()
    Mix.shell().info("app_kit.schema_registry.verify passed")
  end
end
