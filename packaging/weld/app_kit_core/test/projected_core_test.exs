defmodule AppKitCoreProjectedTest do
  use ExUnit.Case, async: true

  test "projects the core result contract" do
    assert {:ok, result} =
             AppKit.Core.Result.new(%{
               surface: :chat,
               state: :accepted,
               payload: %{turn_id: "turn-1"}
             })

    assert result.surface == :chat
    assert result.state == :accepted
  end
end
