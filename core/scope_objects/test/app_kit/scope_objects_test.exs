defmodule AppKit.ScopeObjectsTest do
  use ExUnit.Case, async: true

  alias AppKit.ScopeObjects

  test "builds host scope and managed target objects" do
    assert {:ok, scope} =
             ScopeObjects.host_scope(%{
               scope_id: "workspace/main",
               actor_id: "user-1"
             })

    assert {:ok, target} =
             ScopeObjects.managed_target(%{
               target_id: "runtime/compiler",
               target_kind: :workspace_runtime
             })

    assert scope.scope_id == "workspace/main"
    assert target.target_kind == :workspace_runtime
  end
end
