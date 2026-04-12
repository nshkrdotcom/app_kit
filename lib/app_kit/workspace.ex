defmodule AppKit.Workspace do
  @moduledoc """
  Introspection helpers for the AppKit workspace root.
  """

  @package_paths [
    "core/app_kit_core",
    "core/chat_surface",
    "core/domain_surface",
    "core/operator_surface",
    "core/work_control",
    "core/run_governance",
    "core/runtime_gateway",
    "core/conversation_bridge",
    "core/scope_objects",
    "core/app_config",
    "bridges/outer_brain_bridge",
    "bridges/domain_bridge",
    "bridges/integration_bridge",
    "bridges/projection_bridge",
    "examples/reference_host"
  ]

  @active_project_globs [".", "core/*", "bridges/*", "examples/*"]

  @spec package_paths() :: [String.t()]
  def package_paths, do: @package_paths

  @spec active_project_globs() :: [String.t()]
  def active_project_globs, do: @active_project_globs
end
