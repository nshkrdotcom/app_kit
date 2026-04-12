defmodule AppKit.Bridges.OuterBrainBridgeTest do
  use ExUnit.Case, async: true

  alias AppKit.Bridges.OuterBrainBridge
  alias AppKit.ScopeObjects

  test "compiles a semantic turn request" do
    assert {:ok, scope} =
             ScopeObjects.host_scope(%{
               scope_id: "workspace/main",
               actor_id: "user-1"
             })

    assert {:ok, turn} =
             OuterBrainBridge.compile_turn(scope, "ship the patch", strategy: :focused)

    assert turn.strategy == :focused
    assert turn.turn == "ship the patch"
  end
end
