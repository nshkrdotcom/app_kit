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

  test "product profile allows approved AppKit product-safe surfaces" do
    root =
      write_product_file!("""
      alias AppKit.WorkSurface
      alias AppKit.WorkControl
      alias AppKit.OperatorSurface
      alias AppKit.ReviewSurface
      alias AppKit.RuntimeGateway
      alias AppKit.DomainSurface
      alias AppKit.AdaptiveControlSurface
      """)

    assert {:ok, report} =
             NoBypass.scan(
               root: root,
               profiles: [:product, :hazmat],
               include: ["lib/**/*.ex"]
             )

    assert report.checked_files == 1
  end

  test "product profile rejects direct adaptive lower and provider imports" do
    root =
      write_product_file!("""
      alias GepaFramework.Runner
      alias TrinityFramework.Router
      alias Pristine.Client
      alias Prismatic.Client
      alias GitHubEx.Client
      alias GroundPlane.LeaseFence
      alias OuterBrain.Persistence.Store
      alias AITrace.Event
      alias Product.Repo
      """)

    assert {:error, report} =
             NoBypass.scan(
               root: root,
               profiles: [:product],
               include: ["lib/**/*.ex"]
             )

    assert Enum.map(report.violations, & &1.forbidden) == [
             "GepaFramework",
             "TrinityFramework",
             "Pristine",
             "Prismatic",
             "GitHubEx",
             "GroundPlane",
             "OuterBrain",
             "AITrace",
             "Repo"
           ]
  end

  test "product profile rejects direct trinity runtime and model primitive imports" do
    root =
      write_product_file!("""
      alias SelfHostedInferenceCore.InstanceSpec
      alias SelfHostedInferenceBumblebee.Router
      alias Crucible.Safetensors.Reader
      alias Crucible.Factorization.SVD
      alias Crucible.TensorPatch.Apply
      alias Crucible.ModelRegistry.ArtifactPins
      alias Trinity.Coordinator.RouteLogits
      """)

    assert {:error, report} =
             NoBypass.scan(
               root: root,
               profiles: [:product],
               include: ["lib/**/*.ex"]
             )

    assert Enum.map(report.violations, & &1.forbidden) == [
             "SelfHostedInferenceCore",
             "SelfHostedInferenceBumblebee",
             "CrucibleSafetensors",
             "CrucibleFactorization",
             "CrucibleTensorPatch",
             "CrucibleModelRegistry",
             "Trinity.Coordinator"
           ]
  end

  test "product profile allows public trinity and AppKit coordination surfaces" do
    root =
      write_product_file!("""
      alias Trinity.Router
      alias AppKit.CoordinationSurface.RouterDecisionProjection

      defmodule ProductRouterSurface do
        def project(decision), do: RouterDecisionProjection.from_router_decision(decision)
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

  test "product profile rejects direct lower persistence imports" do
    root =
      write_product_file!("""
      alias Ecto.Repo
      alias AshPostgres.DataLayer
      alias Postgrex
      alias Temporalex.Client
      alias Oban.Job
      """)

    assert {:error, report} =
             NoBypass.scan(
               root: root,
               profiles: [:product],
               include: ["lib/**/*.ex"]
             )

    assert Enum.map(report.violations, & &1.forbidden) == [
             "Ecto",
             "Repo",
             "AshPostgres",
             "Postgrex",
             "Temporalex",
             "Oban"
           ]
  end

  test "product profile rejects direct AppKit bridge imports" do
    root = write_product_file!("alias AppKit.Bridges.MezzanineBridge\n")

    assert {:error, report} =
             NoBypass.scan(
               root: root,
               profiles: [:product],
               include: ["lib/**/*.ex"]
             )

    assert [%NoBypass.Violation{profile: :product, forbidden: "AppKit.Bridges"}] =
             report.violations
  end

  test "product profile rejects AX and A2A runtime vocabulary" do
    root =
      write_product_file!("""
      alias AxRuntime.Session
      alias AxSidecar.Supervisor
      alias AxGrpc.Controller
      alias AXGrpc.Generated.ControllerService
      alias A2ABridge.Server
      alias A2A.Protocol.Message
      ControllerService.Exec.call(%{})
      System.cmd("ax", ["serve"])
      "ax serve"
      "generated A2A"
      "generated AX proto"
      alias AgentInterop.Descriptor
      alias AgentRuntimeReceipt.Event
      alias AgentTurnLedger.Row
      """)

    assert {:error, report} =
             NoBypass.scan(
               root: root,
               profiles: [:product],
               include: ["lib/**/*.ex"]
             )

    forbidden = Enum.map(report.violations, & &1.forbidden)

    assert "AxRuntime" in forbidden
    assert "AxSidecar" in forbidden
    assert "AxGrpc" in forbidden
    assert "AXGrpc" in forbidden
    assert "ControllerService.Exec" in forbidden
    assert "System.cmd(\"ax\"" in forbidden
    assert "ax serve" in forbidden
    assert "A2ABridge" in forbidden
    assert "A2A." in forbidden
    assert "generated A2A" in forbidden
    assert "generated AX proto" in forbidden
    assert "AgentInterop" in forbidden
    assert "AgentRuntimeReceipt" in forbidden
    assert "AgentTurnLedger" in forbidden
  end

  test "product profile rejects direct script execution and arbitrary skill paths" do
    root =
      write_product_file!("""
      System.cmd("bash", ["run-skill.sh"])
      Port.open({:spawn_executable, "/bin/sh"}, [])
      %{script_path: "/tmp/skill/run.sh"}
      %{skill_path: "../skills/private"}
      """)

    assert {:error, report} =
             NoBypass.scan(
               root: root,
               profiles: [:product],
               include: ["lib/**/*.ex"]
             )

    forbidden = Enum.map(report.violations, & &1.forbidden)

    assert "System.cmd" in forbidden
    assert "Port.open" in forbidden
    assert "script_path" in forbidden
    assert "skill_path" in forbidden
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

  test "default scan skips the scanner implementation rule table" do
    root = unique_root!()
    scanner_path = Path.join(root, "lib/app_kit/boundary/no_bypass.ex")
    product_path = Path.join(root, "lib/product.ex")

    File.mkdir_p!(Path.dirname(scanner_path))

    File.write!(
      scanner_path,
      "defmodule AppKit.Boundary.NoBypass do\n  @rules [ExecutionPlane]\nend\n"
    )

    File.write!(product_path, "defmodule Product do\nend\n")

    on_exit(fn -> File.rm_rf(root) end)

    assert {:ok, report} =
             NoBypass.scan(
               root: root,
               profiles: [:hazmat],
               include: ["lib/**/*.ex"]
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
