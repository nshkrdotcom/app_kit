defmodule AppKit.WorkControlTest do
  use ExUnit.Case, async: true

  alias AppKit.WorkControl

  test "starts a governed run from a domain call" do
    assert {:ok, result} =
             WorkControl.start_run(
               %{route_name: :compile_workspace, scope_id: "workspace/main"},
               review_required: true
             )

    assert result.state == :waiting_review
  end
end
