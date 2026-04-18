defmodule AppKit.Bridges.DomainBridgeTest do
  use ExUnit.Case, async: false

  alias AppKit.Bridges.DomainBridge
  alias AppKit.Core.{Telemetry, TraceIdentity}
  alias AppKit.ScopeObjects
  alias Citadel.DomainSurface.{Command, Query}

  defmodule TelemetryForwarder do
    def handle_event(event, measurements, metadata, test_pid) do
      send(test_pid, {:telemetry, event, measurements, metadata})
    end
  end

  test "compiles real typed domain commands and queries for trusted callers" do
    trace_id = "0123456789abcdef0123456789abcdef"

    assert {:ok, scope} =
             ScopeObjects.host_scope(%{
               scope_id: "workspace/main",
               session_id: "sess-1",
               tenant_id: "tenant-1",
               actor_id: "user-1",
               environment: "dev"
             })

    assert {:ok, %Command{} = command} =
             DomainBridge.compile_command(
               scope,
               :compile_workspace,
               %{workspace_id: "workspace/main"},
               domain_module: Citadel.DomainSurface.Examples.ProvingGround,
               idempotency_key: "cmd-1",
               trace_trust: :trusted,
               context: %{trace_id: trace_id}
             )

    assert {:ok, %Query{} = query} =
             DomainBridge.compile_query(
               scope,
               :workspace_status,
               %{workspace_id: "workspace/main"},
               domain_module: Citadel.DomainSurface.Examples.ProvingGround,
               trace_trust: :trusted,
               context: %{trace_id: trace_id}
             )

    assert command.context[:session_id] == "sess-1"
    assert command.trace_id == trace_id
    assert query.context[:tenant_id] == "tenant-1"
  end

  test "replaces untrusted caller trace ids and preserves the client value" do
    client_trace_id = "fedcba9876543210fedcba9876543210"
    attach_telemetry(self(), [:trace_replaced])

    assert {:ok, scope} =
             ScopeObjects.host_scope(%{
               scope_id: "workspace/main",
               session_id: "sess-2",
               tenant_id: "tenant-1",
               actor_id: "user-1"
             })

    assert {:ok, %Command{} = command} =
             DomainBridge.compile_command(
               scope,
               :compile_workspace,
               %{workspace_id: "workspace/main"},
               domain_module: Citadel.DomainSurface.Examples.ProvingGround,
               idempotency_key: "cmd-2",
               context: %{trace_id: client_trace_id}
             )

    assert TraceIdentity.valid?(command.trace_id)
    refute command.trace_id == client_trace_id
    assert command.metadata[:client_trace_id] == client_trace_id

    assert_event(
      :trace_replaced,
      %{count: 1},
      %{
        trace_id: command.trace_id,
        tenant_id: "tenant-1",
        reason: :untrusted_caller,
        source: :request_edge,
        surface: :domain_bridge
      }
    )
  end

  test "rejects invalid caller trace ids before command compilation" do
    attach_telemetry(self(), [:trace_rejected])

    assert {:ok, scope} =
             ScopeObjects.host_scope(%{
               scope_id: "workspace/main",
               session_id: "sess-3",
               tenant_id: "tenant-1",
               actor_id: "user-1"
             })

    assert {:error, :invalid_trace_id} =
             DomainBridge.compile_command(
               scope,
               :compile_workspace,
               %{workspace_id: "workspace/main"},
               domain_module: Citadel.DomainSurface.Examples.ProvingGround,
               idempotency_key: "cmd-3",
               trace_trust: :trusted,
               context: %{trace_id: "trace/app-kit-1"}
             )

    assert_event(
      :trace_rejected,
      %{count: 1},
      %{
        reason: :invalid_format,
        tenant_id: "tenant-1",
        source: :request_edge,
        surface: :domain_bridge
      }
    )
  end

  defp attach_telemetry(test_pid, event_keys) do
    handler_id = "domain-bridge-test-#{System.unique_integer([:positive])}"

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
