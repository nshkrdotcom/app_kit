defmodule AppKit.EvalSurfaceTest do
  use ExUnit.Case, async: true

  alias AppKit.EvalSurface
  alias OuterBrain.ContextABI.Failure

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

  test "projects owner-local failures into product and operator safe summaries" do
    failure =
      Failure.new!(%{
        owner: :mezzanine,
        reason_code: "mezzanine.eval.golden_case_failed.v1",
        safe_message: "golden case failed",
        trace_ref: "trace://eval",
        evidence_refs: ["eval-case://a"]
      })

    assert {:ok, projection} = EvalSurface.failure_projection(failure)

    assert projection.failure_ref =~ ~r/^failure:\/\/mezzanine\/[0-9a-f]{64}$/
    assert projection.failure_family == :eval
    assert projection.owner == :mezzanine
    assert projection.product_summary == "Evaluation did not approve this result."
    assert projection.operator_summary =~ "Eval gate failed"
    assert projection.safe_action == :review_eval_evidence
    assert projection.evidence_refs == ["eval-case://a"]

    assert {:error, {:raw_eval_surface_payload_forbidden, :model_output}} =
             projection
             |> Map.from_struct()
             |> Map.put(:model_output, "raw")
             |> EvalSurface.failure_projection()
  end
end
