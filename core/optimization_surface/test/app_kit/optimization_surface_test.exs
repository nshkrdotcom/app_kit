defmodule AppKit.OptimizationSurfaceTest do
  use ExUnit.Case, async: true

  alias AppKit.OptimizationSurface
  alias AppKit.OptimizationSurface.{CandidateComparison, RunCreateRequest}

  test "creates run requests and compares candidates through refs only" do
    assert {:ok, %RunCreateRequest{} = request} =
             OptimizationSurface.create_run_request(%{
               request_ref: "request://optimization/create",
               tenant_ref: "tenant://phase-8",
               authority_ref: "authority://optimization",
               actor_ref: "operator://phase-8",
               target_ref: "target://role-pack",
               objective_refs: ["objective://exact", "objective://cost"],
               model_profile_refs: ["model-profile://mock/proposer"],
               endpoint_profile_refs: ["endpoint-profile://mock/proposer"],
               eval_suite_ref: "eval-suite://phase-8",
               replay_bundle_ref: "replay-bundle://phase-8",
               budget_ref: "budget://optimization",
               trace_refs: ["trace://optimization/create"],
               idempotency_ref: "idempotency://optimization/create"
             })

    assert request.budget_ref == "budget://optimization"

    assert {:ok, %CandidateComparison{} = comparison} =
             OptimizationSurface.compare_candidates(%{
               comparison_ref: "comparison://phase-8",
               baseline_candidate_ref: "candidate://baseline",
               challenger_candidate_ref: "candidate://challenger",
               score_refs: ["score://exact"],
               eval_refs: ["eval://suite/run"],
               replay_refs: ["replay://bundle/run"],
               budget_refs: ["budget://optimization"],
               trace_refs: ["trace://comparison"],
               decision_ref: "decision://challenger"
             })

    assert comparison.decision_ref == "decision://challenger"
  end

  test "requires full promotion gates and exposes rollback refs" do
    promotion_attrs = %{
      request_ref: "request://promotion",
      candidate_ref: "candidate://challenger",
      operator_ref: "operator://phase-8",
      eval_ref: "eval://suite/run",
      replay_ref: "replay://bundle/run",
      guardrail_ref: "guardrail://pass",
      cost_ref: "cost://bounded",
      shadow_ref: "shadow://pass",
      canary_ref: "canary://pass",
      human_approval_ref: "approval://operator",
      provenance_ref: "provenance://candidate",
      rollback_ref: "rollback://candidate",
      promotion_ref: "promotion://candidate",
      trace_refs: ["trace://promotion"]
    }

    assert {:ok, decision} = OptimizationSurface.promote_candidate(promotion_attrs)
    assert decision.decision_class == :promote
    assert decision.rollback_ref == "rollback://candidate"

    assert {:error, {:missing_promotion_gate_refs, [:human_approval_ref]}} =
             promotion_attrs
             |> Map.delete(:human_approval_ref)
             |> OptimizationSurface.promote_candidate()
  end

  test "rejects lower mutation and raw payload fields" do
    assert {:error, {:raw_optimization_surface_payload_forbidden, :provider_payload}} =
             OptimizationSurface.candidate_projection(%{
               candidate_ref: "candidate://bad",
               run_ref: "optimization-run://bad",
               lineage_refs: ["lineage://bad"],
               score_refs: ["score://bad"],
               eval_refs: ["eval://bad"],
               replay_refs: ["replay://bad"],
               budget_refs: ["budget://bad"],
               trace_refs: ["trace://bad"],
               promotion_refs: [],
               rollback_refs: [],
               provider_payload: %{body: "hidden"}
             })
  end
end
