defmodule AppKit.ConversationBridgeTest do
  use ExUnit.Case, async: true

  alias AppKit.ConversationBridge
  alias AppKit.Core.RunRef
  alias AppKit.ScopeObjects

  test "composes a follow-up and a live update" do
    assert {:ok, scope} =
             ScopeObjects.host_scope(%{scope_id: "workspace/main", actor_id: "user-1"})

    assert {:ok, result} = ConversationBridge.compose_follow_up(scope, "continue")
    assert {:ok, run_ref} = RunRef.new(%{run_id: "run-1", scope_id: "workspace/main"})

    assert {:ok, update} =
             ConversationBridge.live_update(run_ref, %{
               route_name: :compile_workspace,
               state: :scheduled
             })

    assert result.surface == :conversation
    assert update.run_id == "run-1"
  end
end
