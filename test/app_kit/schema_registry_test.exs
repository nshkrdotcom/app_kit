defmodule AppKit.SchemaRegistryTest do
  use ExUnit.Case, async: true

  alias AppKit.Workspace.BoundaryGenerator
  alias AppKit.Workspace.SchemaRegistry

  test "registry declares the Phase 4 AppKit product boundary contracts" do
    contract_names = SchemaRegistry.entries() |> Enum.map(& &1.contract_name)

    assert "AppKit.ProductBootstrap.v1" in contract_names
    assert "AppKit.SchemaRegistryEntry.v1" in contract_names
    assert "Platform.GeneratedArtifactOwnership.v1" in contract_names
    assert "AppKit.ModelSurface.v1" in contract_names
    assert "AppKit.ContextSurface.v1" in contract_names
    assert "AppKit.OptimizationSurface.v1" in contract_names
    assert "AppKit.CoordinationSurface.v1" in contract_names
    assert "AppKit.AdaptiveControlSurface.v1" in contract_names
    assert "AppKit.EffectSurface.v1" in contract_names

    assert {:ok, entry} = SchemaRegistry.fetch("AppKit.ProductBootstrap.v1")
    assert entry.owner_repo == "app_kit"
    assert "extravaganza" in entry.consumer_repos

    assert "stack_lab/proofs/scenario_045_appkit_sdk_contract_failure.md" ==
             entry.proof_artifact_path

    assert {:ok, model_surface} = SchemaRegistry.fetch("AppKit.ModelSurface.v1")
    assert "jido_integration" in model_surface.producer_repos

    assert {:ok, context_surface} = SchemaRegistry.fetch("AppKit.ContextSurface.v1")
    assert "outer_brain" in context_surface.producer_repos
    assert "mezzanine" in context_surface.producer_repos

    assert "AppKit.ContextSurface.ContextPacketProjection" in context_surface.dto_packet_table_resource_names

    assert {:ok, optimization_surface} = SchemaRegistry.fetch("AppKit.OptimizationSurface.v1")
    assert "mezzanine" in optimization_surface.producer_repos

    assert {:ok, coordination_surface} = SchemaRegistry.fetch("AppKit.CoordinationSurface.v1")
    assert "mezzanine" in coordination_surface.producer_repos
    assert "trinity_framework" in coordination_surface.producer_repos

    assert {:ok, adaptive_control_surface} =
             SchemaRegistry.fetch("AppKit.AdaptiveControlSurface.v1")

    assert "mezzanine" in adaptive_control_surface.producer_repos
    assert "ground_plane" in adaptive_control_surface.producer_repos

    assert {:ok, effect_surface} = SchemaRegistry.fetch("AppKit.EffectSurface.v1")
    assert "mezzanine" in effect_surface.producer_repos
    assert "synapse" in effect_surface.consumer_repos
    assert "AppKit.Core.GovernedEffectDTO" in effect_surface.dto_packet_table_resource_names
  end

  test "registry entries require the enterprise pre-cut fields" do
    {:ok, entry} = SchemaRegistry.fetch("AppKit.SchemaRegistryEntry.v1")

    invalid_entry = %{
      entry
      | required_fields: List.delete(entry.required_fields, "trace_id")
    }

    assert {:error, {:missing_required_fields, ["trace_id"]}} =
             SchemaRegistry.validate_entry(invalid_entry)
  end

  test "core DTO surface allows the profiled AppKit.Core modules" do
    assert :ok = SchemaRegistry.validate_core_dto_surface()
  end

  test "core DTO surface rejects new one-off AppKit.Core modules" do
    root =
      Path.join(
        System.tmp_dir!(),
        "app_kit_core_dto_surface_#{System.unique_integer([:positive])}"
      )

    on_exit(fn -> File.rm_rf(root) end)
    File.mkdir_p!(root)

    File.write!(Path.join(root, "surprise_projection.ex"), """
    defmodule AppKit.Core.SurpriseProjection do
    end
    """)

    assert {:error, {:unexpected_appkit_core_modules, ["AppKit.Core.SurpriseProjection"]}} =
             SchemaRegistry.validate_core_dto_surface(root)
  end

  test "boundary generator emits a schema-registry manifest with artifact hashes" do
    output_root =
      Path.join(
        System.tmp_dir!(),
        "app_kit_schema_registry_generator_#{System.unique_integer([:positive])}"
      )

    on_exit(fn -> File.rm_rf(output_root) end)

    assert :ok =
             BoundaryGenerator.generate("operator_projection", output_root,
               module_namespace: "AppKit.Generated"
             )

    manifest_path =
      Path.join(output_root, "generated_artifacts/operator_projection_schema_registry.exs")

    assert File.exists?(manifest_path)

    manifest = manifest_from_file!(manifest_path)

    assert manifest.contract_name == "AppKit.SchemaRegistryEntry.v1"
    assert manifest.schema_name == "operator_projection"
    assert manifest.schema_version == 1
    assert manifest.generator_command == "mix app_kit.gen.boundary operator_projection"
    assert lower_hex_64?(manifest.generated_artifacts.dto_hash)
    assert lower_hex_64?(manifest.generated_artifacts.mapper_hash)
    assert lower_hex_64?(manifest.generated_artifacts.mapper_test_hash)
  end

  test "boundary generator rejects unregistered schema names before writing artifacts" do
    output_root =
      Path.join(
        System.tmp_dir!(),
        "app_kit_unknown_schema_generator_#{System.unique_integer([:positive])}"
      )

    on_exit(fn -> File.rm_rf(output_root) end)

    assert {:error, :unknown_boundary_schema} =
             BoundaryGenerator.generate("operator_projection_runtime_variant", output_root,
               module_namespace: "AppKit.Generated"
             )

    refute File.exists?(output_root)
  end

  test "boundary generator rejects unregistered module namespaces before writing artifacts" do
    output_root =
      Path.join(
        System.tmp_dir!(),
        "app_kit_unknown_namespace_generator_#{System.unique_integer([:positive])}"
      )

    on_exit(fn -> File.rm_rf(output_root) end)

    assert {:error, :invalid_module_namespace} =
             BoundaryGenerator.generate("operator_projection", output_root,
               module_namespace: "AppKit.Generated.Dynamic"
             )

    refute File.exists?(output_root)
  end

  test "boundary generator does not create modules through runtime atom concatenation" do
    source =
      __DIR__
      |> Path.join("../../lib/app_kit/workspace/boundary_generator.ex")
      |> Path.expand()
      |> File.read!()

    refute String.contains?(source, "Module.concat")
  end

  defp lower_hex_64?(value) do
    byte_size(value) == 64 and
      value
      |> :binary.bin_to_list()
      |> Enum.all?(fn byte -> byte in ?a..?f or byte in ?0..?9 end)
  end

  defp manifest_from_file!(path) do
    path
    |> File.read!()
    |> Code.string_to_quoted!()
    |> literal_term!()
  end

  defp literal_term!({:%{}, _metadata, pairs}) do
    Map.new(pairs, fn {key, value} -> {literal_term!(key), literal_term!(value)} end)
  end

  defp literal_term!(value) when is_atom(value) or is_binary(value) or is_integer(value),
    do: value
end
