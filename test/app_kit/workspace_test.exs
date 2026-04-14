defmodule AppKit.WorkspaceTest do
  use ExUnit.Case, async: true

  alias AppKit.Workspace
  alias AppKit.Workspace.MixProject

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

  test "uses the released Weld 0.7.0 line directly" do
    assert {:weld, "~> 0.7.0", runtime: false} in MixProject.project()[:deps]
  end

  test "exposes the release aliases for projection tracking" do
    aliases = MixProject.project()[:aliases]

    assert Keyword.fetch!(aliases, :"release.prepare") == ["weld.release.prepare"]
    assert Keyword.fetch!(aliases, :"release.track") == ["weld.release.track"]
    assert Keyword.fetch!(aliases, :"release.archive") == ["weld.release.archive"]
  end

  test "child packages do not hard-code sibling repo paths" do
    for path <- [
          "bridges/domain_bridge/mix.exs",
          "bridges/outer_brain_bridge/mix.exs",
          "core/domain_surface/mix.exs",
          "examples/reference_host/mix.exs"
        ] do
      refute File.read!(path) =~ "/home/home/p/g/n/"
    end
  end
end
