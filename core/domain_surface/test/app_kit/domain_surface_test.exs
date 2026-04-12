defmodule AppKit.DomainSurfaceTest do
  use ExUnit.Case, async: true

  alias AppKit.DomainSurface
  alias AppKit.ScopeObjects

  test "submits commands and queries through the domain surface" do
    assert {:ok, scope} =
             ScopeObjects.host_scope(%{scope_id: "workspace/main", actor_id: "user-1"})

    assert {:ok, command_result} =
             DomainSurface.submit_command(scope, :compile_workspace, %{
               workspace_id: "workspace/main"
             })

    assert {:ok, query_result} =
             DomainSurface.ask_query(scope, :workspace_status, %{workspace_id: "workspace/main"})

    assert command_result.surface == :work_control
    assert query_result.surface == :domain
  end
end
