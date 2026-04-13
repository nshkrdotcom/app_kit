defmodule AppKit.ScopeObjectsTest do
  use ExUnit.Case, async: true

  alias AppKit.ScopeObjects

  test "builds host scope and managed target objects" do
    assert {:ok, scope} =
             ScopeObjects.host_scope(%{
               scope_id: "workspace/main",
               session_id: "session-1",
               tenant_id: "tenant-1",
               actor_id: "user-1",
               environment: "dev"
             })

    assert {:ok, target} =
             ScopeObjects.managed_target(%{
               target_id: "runtime/compiler",
               target_kind: :workspace_runtime
             })

    assert scope.scope_id == "workspace/main"
    assert scope.session_id == "session-1"
    assert scope.tenant_id == "tenant-1"
    assert scope.environment == "dev"
    assert target.target_kind == :workspace_runtime
  end
end
