defmodule AppKit.ChassisBridgeTest do
  use ExUnit.Case, async: false

  alias AppKit.SpatialGateway

  defmodule InjectedBackend do
    @behaviour AppKit.SpatialGateway.Backend

    def handle(%AppKit.SpatialGateway.Request.GetActiveProfile{}, opts) do
      send(Keyword.fetch!(opts, :test_pid), :injected_backend_used)
      {:ok, "profile:injected"}
    end

    def handle(_request, _opts), do: {:error, :unexpected_request}
  end

  defmodule RecordingBoundary do
    def dispatch(%Chassis.Boundary.Envelope{} = envelope, opts) do
      send(
        Keyword.fetch!(opts, :test_pid),
        {:boundary_dispatch, envelope.protocol_ref, envelope.payload}
      )

      projection =
        Chassis.AppKit.Surface.Projection.new!(%{
          deployment_ref: "deployment:boundary",
          app_ref: "app:demo:installation:acme:demo:tenant:dev",
          app_atom: :demo,
          tenant_ref: "tenant:dev",
          installation_ref: "installation:acme:demo",
          active_profile: "profile:boundary",
          health_status: :healthy,
          receipt_ref: "receipt:deployment:boundary",
          status: :active
        })

      {:ok,
       %Chassis.Boundary.Envelope{
         envelope
         | status: :ok,
           payload: %Chassis.Boundary.ReadDeploymentProjection.Response{
             deployment_ref: projection.deployment_ref,
             projection: projection,
             status: :ok
           }
       }}
    end
  end

  setup do
    {:ok, registry} = Chassis.AppRegistry.start_link(name: nil)
    %{registry: registry}
  end

  test "local backend registers an app and reads the active profile", %{registry: registry} do
    assert {:ok, receipt_ref} =
             SpatialGateway.register_deployed_app(:extravaganza, "abc123",
               spatial_gateway_backend: SpatialGateway.Backend.Local,
               registry: registry,
               tenant_ref: "tenant:dev",
               installation_ref: "installation:acme:demo",
               profile_ref: "profile:monolith"
             )

    assert receipt_ref =~ "receipt:appkit:"

    assert {:ok, "profile:monolith"} =
             SpatialGateway.get_active_profile(
               spatial_gateway_backend: SpatialGateway.Backend.Local,
               registry: registry,
               app_atom: :extravaganza,
               tenant_ref: "tenant:dev",
               installation_ref: "installation:acme:demo"
             )
  end

  test "boundary backend dispatches readback through Chassis.Boundary-compatible dispatcher" do
    assert {:ok, "profile:boundary"} =
             SpatialGateway.get_active_profile(
               spatial_gateway_backend: SpatialGateway.Backend.Boundary,
               boundary_dispatcher: RecordingBoundary,
               test_pid: self(),
               tenant_ref: "tenant:dev",
               installation_ref: "installation:acme:demo"
             )

    assert_receive {:boundary_dispatch, "boundary:appkit.chassis.read_deployment_projection:v1",
                    %Chassis.Boundary.ReadDeploymentProjection.Request{}}
  end

  test "standalone backend uses only CHASSIS_DEPLOYMENT_PROFILE fallback" do
    original = System.get_env("CHASSIS_DEPLOYMENT_PROFILE")
    System.put_env("CHASSIS_DEPLOYMENT_PROFILE", "profile:standalone")

    on_exit(fn ->
      if original,
        do: System.put_env("CHASSIS_DEPLOYMENT_PROFILE", original),
        else: System.delete_env("CHASSIS_DEPLOYMENT_PROFILE")
    end)

    assert {:ok, "profile:standalone"} =
             SpatialGateway.get_active_profile(
               spatial_gateway_backend: SpatialGateway.Backend.Standalone
             )
  end

  test "BackendConfig explicit option injects the selected backend" do
    assert {:ok, "profile:injected"} =
             SpatialGateway.get_active_profile(
               spatial_gateway_backend: InjectedBackend,
               test_pid: self()
             )

    assert_receive :injected_backend_used
  end

  test "server caches active profile through the gateway API" do
    {:ok, server} =
      SpatialGateway.Server.start_link(
        name: nil,
        spatial_gateway_backend: InjectedBackend,
        test_pid: self()
      )

    assert {:ok, "profile:injected"} = SpatialGateway.Server.get_active_profile(server)
    assert_receive :injected_backend_used
  end

  test "future evolution surface placeholders fail closed" do
    assert {:error, {:not_implemented, AppKit.EvolutionSurface}} =
             AppKit.EvolutionSurface.get_evolution_status(%{}, %{})
  end
end
