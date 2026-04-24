defmodule AppKit.NoBypassTest do
  use ExUnit.Case, async: true

  alias AppKit.Boundary.NoBypass

  test "product profile rejects direct lower write imports" do
    root = write_product_file!("alias Mezzanine.Execution.RuntimeStack\n")

    assert {:error, report} =
             NoBypass.scan(
               root: root,
               profiles: [:product],
               include: ["lib/**/*.ex"]
             )

    assert [%NoBypass.Violation{profile: :product, forbidden: "Mezzanine"}] =
             report.violations
  end

  test "product profile allows the pure Mezzanine pack model contract" do
    root =
      write_product_file!("""
      defmodule ProductPack do
        @behaviour Mezzanine.Pack
        alias Mezzanine.Pack.Manifest
      end
      """)

    assert {:ok, report} =
             NoBypass.scan(
               root: root,
               profiles: [:product],
               include: ["lib/**/*.ex"]
             )

    assert report.checked_files == 1
  end

  test "hazmat profile rejects direct execution plane use" do
    root = write_product_file!("ExecutionPlane.Contracts.dispatch(%{})\n")

    assert {:error, report} =
             NoBypass.scan(
               root: root,
               profiles: [:hazmat],
               include: ["lib/**/*.ex"]
             )

    assert [%NoBypass.Violation{profile: :hazmat, forbidden: "ExecutionPlane"}] =
             report.violations
  end

  test "scans multiple profiles and reports checked files when clean" do
    root = write_product_file!("alias AppKit.WorkSurface\n")

    assert {:ok, report} =
             NoBypass.scan(
               root: root,
               profiles: [:product, :hazmat],
               include: ["lib/**/*.ex"]
             )

    assert report.profiles == [:product, :hazmat]
    assert report.checked_files == 1
  end

  test "defaults to the product profile" do
    root = write_product_file!("alias Jido.Integration.V2.BrainIngress\n")

    assert {:error, report} = NoBypass.scan(root: root, include: ["lib/**/*.ex"])

    assert [%NoBypass.Violation{profile: :product, forbidden: "Jido.Integration"}] =
             report.violations
  end

  test "excludes dependency and build output by default" do
    root = unique_root!()
    owned_path = Path.join(root, "lib/product.ex")
    dep_path = Path.join(root, "deps/lower/lib/runtime.ex")
    build_path = Path.join(root, "_build/test/lib/lower/runtime.ex")

    File.mkdir_p!(Path.dirname(owned_path))
    File.mkdir_p!(Path.dirname(dep_path))
    File.mkdir_p!(Path.dirname(build_path))
    File.write!(owned_path, "defmodule Product do\nend\n")
    File.write!(dep_path, "ExecutionPlane.Contracts.dispatch(%{})\n")
    File.write!(build_path, "ExecutionPlane.Contracts.dispatch(%{})\n")

    on_exit(fn -> File.rm_rf(root) end)

    assert {:ok, report} =
             NoBypass.scan(
               root: root,
               profiles: [:hazmat],
               include: ["**/*.ex"]
             )

    assert report.checked_files == 1
  end

  test "honors explicit excludes after collecting included source files" do
    root = unique_root!()
    owned_path = Path.join(root, "lib/product.ex")
    generated_path = Path.join(root, "generated/lower.ex")

    File.mkdir_p!(Path.dirname(owned_path))
    File.mkdir_p!(Path.dirname(generated_path))
    File.write!(owned_path, "defmodule Product do\nend\n")
    File.write!(generated_path, "ExecutionPlane.Contracts.dispatch(%{})\n")

    on_exit(fn -> File.rm_rf(root) end)

    assert {:ok, report} =
             NoBypass.scan(
               root: root,
               profiles: [:hazmat],
               include: ["**/*.ex"],
               exclude: ["generated/**"]
             )

    assert report.checked_files == 1
  end

  defp write_product_file!(contents) do
    root = unique_root!()
    path = Path.join(root, "lib/product.ex")

    File.mkdir_p!(Path.dirname(path))
    File.write!(path, contents)

    on_exit(fn -> File.rm_rf(root) end)

    root
  end

  defp unique_root! do
    Path.join(System.tmp_dir!(), "app_kit_no_bypass_#{System.unique_integer([:positive])}")
  end
end
