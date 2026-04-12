defmodule AppKit.RunGovernanceTest do
  use ExUnit.Case, async: true

  alias AppKit.RunGovernance

  test "builds evidence and a decision state" do
    assert {:ok, evidence} =
             RunGovernance.evidence(%{kind: :operator_note, summary: "looks good"})

    assert RunGovernance.review_state(evidence) == :approved
    assert {:ok, decision} = RunGovernance.decision(%{run_id: "run-1", state: :approved})
    assert decision.state == :approved
  end
end
