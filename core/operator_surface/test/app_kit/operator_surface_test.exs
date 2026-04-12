defmodule AppKit.OperatorSurfaceTest do
  use ExUnit.Case, async: true

  alias AppKit.Core.RunRef
  alias AppKit.OperatorSurface

  test "projects run status and review output" do
    assert {:ok, run_ref} = RunRef.new(%{run_id: "run-1", scope_id: "workspace/main"})

    assert {:ok, projection} =
             OperatorSurface.run_status(run_ref, %{
               route_name: :compile_workspace,
               state: :waiting_review
             })

    assert {:ok, review} =
             OperatorSurface.review_run(run_ref, %{kind: :operator_note, summary: "looks good"})

    assert projection.run_id == "run-1"
    assert review.decision.state == :approved
  end
end
