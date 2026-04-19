defmodule AppKit.Bridges.OuterBrainBridgeTest do
  use ExUnit.Case, async: false

  alias AppKit.Bridges.OuterBrainBridge
  alias AppKit.Core.{Telemetry, TraceIdentity}
  alias AppKit.ScopeObjects
  alias Citadel.DomainSurface.Adapters.CitadelAdapter.Accepted

  defmodule TelemetryForwarder do
    def handle_event(event, measurements, metadata, test_pid) do
      send(test_pid, {:telemetry, event, measurements, metadata})
    end
  end

  defmodule FakeKernelRuntime do
    @moduledoc false

    def dispatch_command(command, _opts) do
      {:ok,
       Accepted.new!(%{
         request_id: command.idempotency_key,
         session_id: command.context[:session_id],
         trace_id: command.trace_id,
         ingress_path: :direct_intent_envelope,
         lifecycle_event: :live_owner,
         continuity_revision: 1
       })}
    end
  end

  defmodule SemanticFailureRuntime do
    @moduledoc false

    def submit_turn(_text, _opts) do
      {:semantic_failure,
       %{
         kind: :semantic_insufficient_context,
         provenance: [%{"surface" => "outer_brain.test_runtime"}],
         operator_message: "Need the workspace target before dispatch."
       }}
    end
  end

  test "submits a semantic turn through the outer_brain seam" do
    attach_telemetry(self(), [:trace_minted])

    assert {:ok, scope} =
             ScopeObjects.host_scope(%{
               scope_id: "workspace/main",
               session_id: "sess-outer-brain-bridge",
               tenant_id: "tenant-1",
               actor_id: "user-1",
               environment: "dev",
               metadata: %{workspace_root: "/workspace/main"}
             })

    assert {:ok, turn} =
             OuterBrainBridge.submit_turn(
               scope,
               "compile the workspace",
               idempotency_key: "turn-outer-brain-1",
               domain_module: Citadel.DomainSurface.Examples.ProvingGround,
               route_sources: [
                 Citadel.DomainSurface.Examples.ProvingGround.Routes.CompileWorkspace
               ],
               kernel_runtime: {FakeKernelRuntime, []}
             )

    assert turn.action_request.route == "compile_workspace"
    assert turn.dispatch_result.request_id == "turn-outer-brain-1"
    assert TraceIdentity.valid?(turn.dispatch_result.trace_id)

    assert_event(
      :trace_minted,
      %{count: 1},
      %{
        trace_id: turn.dispatch_result.trace_id,
        tenant_id: "tenant-1",
        source: :request_edge,
        surface: :outer_brain_bridge
      }
    )
  end

  test "preserves provider-neutral semantic failure carrier fields across the AppKit bridge" do
    assert {:ok, scope} =
             ScopeObjects.host_scope(%{
               scope_id: "workspace/main",
               session_id: "sess-outer-brain-semantic-failure",
               tenant_id: "tenant-1",
               actor_id: "user-1",
               environment: "dev",
               metadata: %{workspace_root: "/workspace/main"}
             })

    assert {:error, {:semantic_failure, carrier}} =
             OuterBrainBridge.submit_turn(
               scope,
               "compile it",
               idempotency_key: "turn-outer-brain-semantic-failure",
               domain_module: Citadel.DomainSurface.Examples.ProvingGround,
               route_sources: [
                 Citadel.DomainSurface.Examples.ProvingGround.Routes.CompileWorkspace
               ],
               semantic_runtime: SemanticFailureRuntime
             )

    assert carrier.kind == :semantic_insufficient_context
    assert carrier.retry_class == :clarification_required
    assert carrier.tenant_id == "tenant-1"
    assert carrier.semantic_session_id == "sess-outer-brain-semantic-failure"
    assert carrier.causal_unit_id == "turn-outer-brain-semantic-failure"
    assert TraceIdentity.valid?(carrier.request_trace_id)
    assert carrier.provenance == [%{"surface" => "outer_brain.test_runtime"}]
    assert carrier.operator_message == "Need the workspace target before dispatch."
  end

  defp attach_telemetry(test_pid, event_keys) do
    handler_id = "outer-brain-bridge-test-#{System.unique_integer([:positive])}"

    :telemetry.attach_many(
      handler_id,
      Enum.map(event_keys, &Telemetry.event_name/1),
      &TelemetryForwarder.handle_event/4,
      test_pid
    )

    on_exit(fn -> :telemetry.detach(handler_id) end)
  end

  defp assert_event(event_key, measurements, metadata) do
    event_name = Telemetry.event_name(event_key)
    assert_receive {:telemetry, ^event_name, ^measurements, ^metadata}
    assert_contract_shape(event_key, measurements, metadata)
  end

  defp assert_contract_shape(event_key, measurements, metadata) do
    assert Enum.sort(Map.keys(measurements)) ==
             event_key |> Telemetry.measurement_keys() |> Enum.sort()

    assert Enum.sort(Map.keys(metadata)) ==
             event_key |> Telemetry.metadata_keys() |> Enum.sort()
  end
end
