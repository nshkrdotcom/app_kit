defmodule AppKit.WorkspaceTest do
  use ExUnit.Case, async: true

  alias AppKit.Workspace

  test "lists workspace packages" do
    assert "core/app_kit_core" in Workspace.package_paths()
    assert "bridges/domain_bridge" in Workspace.package_paths()
    assert "examples/reference_host" in Workspace.package_paths()
  end

  test "lists active project globs" do
    assert Workspace.active_project_globs() == [
             ".",
             "core/*",
             "bridges/*",
             "examples/*"
           ]
  end
end
