defmodule AppKit.WorkspaceTest do
  use ExUnit.Case, async: true

  alias AppKit.Build.WeldContract
  alias AppKit.Workspace
  alias AppKit.Workspace.BoundaryGenerator
  alias AppKit.Workspace.MixProject

  @compile {:no_warn_undefined, {WeldContract, :manifest, 0}}

  test "lists workspace packages" do
    assert "core/app_kit_core" in Workspace.package_paths()
    assert "core/authority_projections" in Workspace.package_paths()
    assert "core/model_surface" in Workspace.package_paths()
    assert "core/optimization_surface" in Workspace.package_paths()
    assert "core/coordination_surface" in Workspace.package_paths()
    assert "core/adaptive_control_surface" in Workspace.package_paths()
    assert "core/skill_surface" in Workspace.package_paths()
    assert "core/hive_surface" in Workspace.package_paths()
    assert "web/operator_console" in Workspace.package_paths()
    assert "bridges/domain_bridge" in Workspace.package_paths()
    assert "examples/reference_host" in Workspace.package_paths()
  end

  test "lists active project globs" do
    assert Workspace.active_project_globs() == [
             ".",
             "core/*",
             "bridges/*",
             "web/*",
             "examples/*"
           ]
  end

  test "uses the released Weld line directly" do
    assert {:weld, "~> 0.8.1", only: [:dev, :test], runtime: false} in MixProject.project()[:deps]
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

  test "headless surface projects only DTO contract dependencies" do
    Code.require_file("../../build_support/weld.exs", __DIR__)

    on_exit(fn ->
      :code.purge(WeldContract)
      :code.delete(WeldContract)
    end)

    deps =
      Mix.Project.in_project(
        :app_kit_headless_surface,
        Path.expand("../../core/headless_surface", __DIR__),
        fn _module -> Mix.Project.config()[:deps] end
      )

    manifest_deps = WeldContract.manifest()[:dependencies]

    source_opts_by_app =
      Map.new(deps, fn
        {app, opts} -> {app, opts}
        {app, _requirement, opts} -> {app, opts}
      end)

    manifest_apps = Keyword.keys(manifest_deps)

    lower_runtime_apps = [
      :app_kit_work_surface,
      :citadel_governance,
      :execution_plane,
      :jido_integration_v2,
      :mezzanine_archival_engine,
      :mezzanine_audit_engine,
      :mezzanine_barriers,
      :mezzanine_config_registry,
      :mezzanine_core,
      :mezzanine_decision_engine,
      :mezzanine_evidence_engine,
      :mezzanine_execution_engine,
      :mezzanine_integration_bridge,
      :mezzanine_leasing,
      :mezzanine_lifecycle_engine,
      :mezzanine_m1_m2_runtime,
      :mezzanine_object_engine,
      :mezzanine_operator_engine,
      :mezzanine_ops_domain,
      :mezzanine_ops_model,
      :mezzanine_pack_compiler,
      :mezzanine_pack_model,
      :mezzanine_projection_engine,
      :mezzanine_runtime_scheduler,
      :mezzanine_source_engine,
      :mezzanine_workflow_runtime,
      :mezzanine_workspace_build_model,
      :temporalex
    ]

    for app <- lower_runtime_apps do
      refute Map.has_key?(source_opts_by_app, app)
      refute app in manifest_apps
    end

    assert source_opts_by_app[:mezzanine_headless_coding_ops][:runtime] == false
    assert source_opts_by_app[:jido_integration_contracts][:runtime] == false
    assert source_opts_by_app[:jido_integration_contracts][:override] == true

    for app <- [
          :jido_integration_contracts,
          :jido_hive_skill_contracts,
          :jido_hive_agent_coordinator,
          :jido_hive_inter_agent_messaging,
          :jido_hive_shared_memory_facade,
          :jido_hive_coordination_patterns,
          :mezzanine_headless_coding_ops
        ] do
      manifest_opts = Keyword.fetch!(manifest_deps, app)
      assert manifest_opts[:opts][:override] == true
      assert manifest_opts[:opts][:runtime] == false
    end
  end

  test "child packages do not hard-code sibling repo paths" do
    for path <- [
          "bridges/domain_bridge/mix.exs",
          "bridges/outer_brain_bridge/mix.exs",
          "core/domain_surface/mix.exs",
          "core/model_surface/mix.exs",
          "core/optimization_surface/mix.exs",
          "core/coordination_surface/mix.exs",
          "core/adaptive_control_surface/mix.exs",
          "core/skill_surface/mix.exs",
          "core/hive_surface/mix.exs",
          "web/operator_console/mix.exs",
          "examples/reference_host/mix.exs"
        ] do
      refute String.contains?(File.read!(path), "/home/home/p/g/n/")
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

    assert String.contains?(File.read!(dto_path), "schema_ref")
    assert String.contains?(File.read!(dto_path), "schema_version")
    assert String.contains?(File.read!(dto_path), "payload")
    assert String.contains?(File.read!(mapper_path), "Map.get(payload, :payload, %{})")
    assert String.contains?(File.read!(mapper_test_path), "opaque payload envelope")
  end
end
