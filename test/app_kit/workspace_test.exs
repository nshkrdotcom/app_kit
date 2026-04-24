defmodule AppKit.WorkspaceTest do
  use ExUnit.Case, async: true

  alias AppKit.Workspace
  alias AppKit.Workspace.BoundaryGenerator
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

  test "uses the released Weld 0.7.2 line directly" do
    assert {:weld, "~> 0.7.2", runtime: false} in MixProject.project()[:deps]
  end

  test "uses Weld task autodiscovery instead of local release aliases" do
    aliases = MixProject.project()[:aliases]

    for alias_name <- [
          :"weld.inspect",
          :"weld.graph",
          :"weld.project",
          :"weld.verify",
          :"weld.release.prepare",
          :"weld.release.track",
          :"weld.release.archive",
          :"release.prepare",
          :"release.track",
          :"release.archive"
        ] do
      refute Keyword.has_key?(aliases, alias_name)
    end
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

  test "boundary generator produces opaque-envelope dto and bridge mapper scaffolding" do
    output_root =
      Path.join(
        System.tmp_dir!(),
        "app_kit_boundary_generator_#{System.unique_integer([:positive])}"
      )

    on_exit(fn -> File.rm_rf(output_root) end)

    assert :ok =
             BoundaryGenerator.generate("operator_projection", output_root,
               module_namespace: "AppKit.Generated"
             )

    dto_path =
      Path.join(output_root, "core/app_kit_core/lib/app_kit/generated/operator_projection.ex")

    mapper_path =
      Path.join(
        output_root,
        "bridges/mezzanine_bridge/lib/app_kit/bridges/mezzanine_bridge/operator_projection_mapper.ex"
      )

    mapper_test_path =
      Path.join(
        output_root,
        "bridges/mezzanine_bridge/test/app_kit/bridges/mezzanine_bridge/operator_projection_mapper_test.exs"
      )

    assert File.exists?(dto_path)
    assert File.exists?(mapper_path)
    assert File.exists?(mapper_test_path)

    assert File.read!(dto_path) =~ "schema_ref"
    assert File.read!(dto_path) =~ "schema_version"
    assert File.read!(dto_path) =~ "payload"
    assert File.read!(mapper_path) =~ "Map.get(payload, :payload, %{})"
    assert File.read!(mapper_test_path) =~ "opaque payload envelope"
  end
end
