defmodule AppKit.Build.WorkspaceContract do
  @moduledoc false

  @package_paths [
    "core/app_kit_core",
    "core/authority_projections",
    "core/chat_surface",
    "core/domain_surface",
    "core/operator_surface",
    "core/review_surface",
    "core/work_control",
    "core/work_surface",
    "core/installation_surface",
    "core/run_governance",
    "core/runtime_gateway",
    "core/headless_surface",
    "core/conversation_bridge",
    "core/scope_objects",
    "core/app_config",
    "core/memory_surface",
    "core/context_budget_surface",
    "core/prompt_surface",
    "core/guardrail_surface",
    "core/eval_surface",
    "core/replay_surface",
    "core/cost_surface",
    "core/budget_surface",
    "core/skill_surface",
    "core/hive_surface",
    "web/components",
    "web/operator_console",
    "web/replay_viewer",
    "web/policy_authoring",
    "web/cost_dashboard",
    "web/eval_studio",
    "bridges/outer_brain_bridge",
    "bridges/domain_bridge",
    "bridges/integration_bridge",
    "bridges/mezzanine_bridge",
    "bridges/projection_bridge",
    "examples/reference_host"
  ]

  @active_project_globs [".", "core/*", "bridges/*", "web/*", "examples/*"]

  def package_paths, do: @package_paths
  def active_project_globs, do: @active_project_globs
end
