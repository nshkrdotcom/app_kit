defmodule AppKit.Bridges.IntegrationBridgeTest do
  use ExUnit.Case, async: true

  alias AppKit.Bridges.IntegrationBridge
  alias AppKit.Core.RunRef

  test "compiles a durable run submission and review bundle" do
    assert {:ok, run_ref} = RunRef.new(%{run_id: "run-1", scope_id: "workspace/main"})

    assert {:ok, submission} =
             IntegrationBridge.compile_run_submission(run_ref, %{review_required: true})

    assert {:ok, review_bundle} =
             IntegrationBridge.review_bundle(run_ref, %{
               summary: "needs review",
               evidence_count: 2
             })

    assert submission.review_required
    assert review_bundle.evidence_count == 2
  end
end
