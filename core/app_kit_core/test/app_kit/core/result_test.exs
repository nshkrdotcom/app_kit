defmodule AppKit.Core.ResultTest do
  use ExUnit.Case, async: true

  alias AppKit.Core.{Result, RunRef}

  test "builds a stable surface result" do
    assert {:ok, result} =
             Result.new(%{
               surface: :chat,
               state: :accepted,
               payload: %{turn_id: "turn-1"},
               meta: %{source: :ui}
             })

    assert result.surface == :chat
    assert result.state == :accepted
  end

  test "builds a run reference" do
    assert {:ok, run_ref} =
             RunRef.new(%{
               run_id: "run-1",
               scope_id: "workspace/main"
             })

    assert run_ref.run_id == "run-1"
    assert run_ref.scope_id == "workspace/main"
  end
end
