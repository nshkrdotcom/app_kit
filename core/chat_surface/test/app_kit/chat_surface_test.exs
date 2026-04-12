defmodule AppKit.ChatSurfaceTest do
  use ExUnit.Case, async: true

  alias AppKit.ChatSurface
  alias AppKit.ScopeObjects

  test "submits a chat turn through the northbound surface" do
    assert {:ok, scope} =
             ScopeObjects.host_scope(%{scope_id: "workspace/main", actor_id: "user-1"})

    assert {:ok, result} = ChatSurface.submit_turn(scope, "compile the workspace")
    assert result.surface == :conversation
  end
end
