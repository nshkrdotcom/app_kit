defmodule AppKit.Bridges.DomainBridgeTest do
  use ExUnit.Case, async: true

  alias AppKit.Bridges.DomainBridge
  alias AppKit.ScopeObjects
  alias Citadel.DomainSurface.{Command, Query}

  test "compiles real typed domain commands and queries" do
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
               context: %{trace_id: "trace/app-kit-1"}
             )

    assert {:ok, %Query{} = query} =
             DomainBridge.compile_query(
               scope,
               :workspace_status,
               %{workspace_id: "workspace/main"},
               domain_module: Citadel.DomainSurface.Examples.ProvingGround,
               context: %{trace_id: "trace/app-kit-1"}
             )

    assert command.context[:session_id] == "sess-1"
    assert command.trace_id == "trace/app-kit-1"
    assert query.context[:tenant_id] == "tenant-1"
  end
end
