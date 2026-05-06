defmodule AppKit.EvalSurfaceTest do
  use ExUnit.Case, async: true

  alias AppKit.EvalSurface

  test "builds DTO-only eval projections and promote requests" do
    assert {:ok, run} =
             EvalSurface.run_projection(%{
               eval_run_ref: "eval-run://a",
               suite_ref: "eval-suite://a",
               verdict: :regress,
               case_projection_refs: ["eval-case://a"]
             })

    assert run.verdict == :regress

    assert {:ok, promote} =
             EvalSurface.promote_request(%{
               request_ref: "request://promote",
               prompt_ref: "prompt://a",
               eval_run_ref: "eval-run://a",
               guard_chain_ref: "guard-chain://a",
               decision_evidence_ref: "decision://a"
             })

    assert promote.eval_run_ref == "eval-run://a"
  end

  test "rejects raw eval payloads and unknown verdicts" do
    assert {:error, {:raw_eval_surface_payload_forbidden, :model_output}} =
             EvalSurface.case_projection(%{
               case_ref: "case://a",
               verdict: :pass,
               evidence_ref: "evidence://a",
               model_output: "raw"
             })

    assert {:error, :unknown_eval_verdict} =
             EvalSurface.run_projection(%{
               eval_run_ref: "eval-run://a",
               suite_ref: "eval-suite://a",
               verdict: :free_form,
               case_projection_refs: []
             })
  end
end
