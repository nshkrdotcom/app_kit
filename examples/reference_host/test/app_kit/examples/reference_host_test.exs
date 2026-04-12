defmodule AppKit.Examples.ReferenceHostTest do
  use ExUnit.Case, async: true

  alias AppKit.Examples.ReferenceHost

  test "runs the full reference host flow" do
    result = ReferenceHost.run_demo()

    assert result.gateway.mode == :attached
    assert result.chat.surface == :conversation
    assert result.command.state == :waiting_review
    assert result.status.run_id == "run-1"
  end
end
