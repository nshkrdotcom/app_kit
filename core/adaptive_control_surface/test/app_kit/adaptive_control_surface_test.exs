defmodule AppKit.AdaptiveControlSurfaceTest do
  use ExUnit.Case, async: true

  alias AppKit.AdaptiveControlSurface
  alias AppKit.AdaptiveControlSurface.OperatorProjection

  test "projects adaptive-control operator state through refs only" do
    assert {:ok, %OperatorProjection{} = projection} =
             AdaptiveControlSurface.operator_projection(projection_attrs())

    assert projection.fixture_refs == ["AOC-037"]
    assert projection.control_run_ref == "adaptive-control://phase-13/worker"
    assert projection.shadow_comparison_ref == "shadow://candidate/worker/v2"
    assert projection.canary_state_ref == "canary://candidate/worker/v2"

    assert projection.threshold_status_refs == [
             "threshold://improvement/pass",
             "threshold://regression/pass",
             "threshold://budget/pass",
             "threshold://approval/operator"
           ]

    assert projection.budget_impact_ref == "budget-impact://candidate/worker/v2"
    assert projection.approval_decision_ref == "approval://operator/worker/v2"
    assert projection.promotion_readiness_ref == "promotion-readiness://candidate/worker/v2"
    assert projection.rollback_ref == "rollback://candidate/worker/v1"
    assert projection.artifact_lock_refs == ["artifact-lock://role-worker"]
    assert projection.stale_artifact_rejection_refs == ["stale-rejection://candidate/worker/v1"]
    assert projection.audit_refs == ["audit://adaptive-control/worker"]
    assert projection.redaction_posture == :refs_only
  end

  test "rejects raw prompts, provider payloads, model outputs, memory bodies, credentials, and operator payloads" do
    assert {:error, {:raw_adaptive_control_surface_payload_forbidden, :operator_private_payload}} =
             projection_attrs()
             |> Map.put(:operator_private_payload, %{body: "hidden"})
             |> AdaptiveControlSurface.operator_projection()
  end

  test "fails closed when required operator refs are missing" do
    assert {:error, {:missing_required_refs, :threshold_status_refs}} =
             projection_attrs()
             |> Map.put(:threshold_status_refs, [])
             |> AdaptiveControlSurface.operator_projection()
  end

  defp projection_attrs do
    %{
      control_run_ref: "adaptive-control://phase-13/worker",
      tenant_ref: "tenant://adaptive",
      authority_ref: "authority://adaptive-control",
      actor_ref: "operator://adaptive",
      shadow_comparison_ref: "shadow://candidate/worker/v2",
      canary_state_ref: "canary://candidate/worker/v2",
      threshold_status_refs: [
        "threshold://improvement/pass",
        "threshold://regression/pass",
        "threshold://budget/pass",
        "threshold://approval/operator"
      ],
      budget_impact_ref: "budget-impact://candidate/worker/v2",
      approval_decision_ref: "approval://operator/worker/v2",
      promotion_readiness_ref: "promotion-readiness://candidate/worker/v2",
      rollback_ref: "rollback://candidate/worker/v1",
      artifact_lock_refs: ["artifact-lock://role-worker"],
      stale_artifact_rejection_refs: ["stale-rejection://candidate/worker/v1"],
      audit_refs: ["audit://adaptive-control/worker"],
      trace_refs: ["trace://adaptive-control/worker"]
    }
  end
end
