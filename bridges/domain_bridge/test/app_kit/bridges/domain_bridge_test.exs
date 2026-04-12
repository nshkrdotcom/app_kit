defmodule AppKit.Bridges.DomainBridgeTest do
  use ExUnit.Case, async: true

  alias AppKit.Bridges.DomainBridge
  alias AppKit.ScopeObjects

  test "compiles command and query calls" do
    assert {:ok, scope} =
             ScopeObjects.host_scope(%{
               scope_id: "workspace/main",
               actor_id: "user-1"
             })

    assert {:ok, command} =
             DomainBridge.compile_command(scope, :compile_workspace, %{
               workspace_id: "workspace/main"
             })

    assert {:ok, query} =
             DomainBridge.compile_query(scope, :workspace_status, %{
               workspace_id: "workspace/main"
             })

    assert command.kind == :command
    assert query.kind == :query
  end
end
