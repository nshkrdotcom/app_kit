defmodule AppKit.BudgetSurfaceTest do
  use ExUnit.Case, async: true

  alias AppKit.BudgetSurface

  test "builds budget view, exhaustion, override, and audit DTOs" do
    assert {:ok, view} =
             BudgetSurface.view_projection(%{
               budget_ref: "budget://phase-d",
               period_class: :per_run,
               hard_cap_class: :redacted_above_ceiling,
               soft_cap_class: :redacted_below_floor,
               decision_class: :allow_warn_soft
             })

    assert view.period_class == :per_run

    assert {:ok, exhaustion} =
             BudgetSurface.exhaustion_record(%{
               budget_ref: "budget://phase-d",
               locus: :preflight,
               decision_class: :deny_hard_exhausted,
               requested_units: 10,
               granted_units: 0
             })

    assert exhaustion.locus == :preflight

    assert {:ok, override} =
             BudgetSurface.override_request(%{
               request_ref: "request://override",
               budget_ref: "budget://phase-d",
               operator_ref: "operator://a",
               permission_ref: "permission://budget/override",
               reason_ref: "reason://bounded",
               duration_seconds: 60
             })

    assert override.duration_seconds == 60

    assert {:ok, audit} =
             BudgetSurface.audit_projection(%{
               audit_ref: "audit://budget",
               budget_ref: "budget://phase-d",
               decision_refs: ["decision://one"]
             })

    assert audit.redaction_posture == "bounded_refs_only"
  end

  test "rejects raw override reasons and unbounded override duration" do
    assert {:error, {:raw_budget_surface_payload_forbidden, :override_reason}} =
             BudgetSurface.override_request(%{
               request_ref: "request://override",
               budget_ref: "budget://phase-d",
               operator_ref: "operator://a",
               permission_ref: "permission://budget/override",
               reason_ref: "reason://bounded",
               duration_seconds: 60,
               override_reason: "raw text"
             })

    assert {:error, :budget_override_duration_unbounded} =
             BudgetSurface.override_request(%{
               request_ref: "request://override",
               budget_ref: "budget://phase-d",
               operator_ref: "operator://a",
               permission_ref: "permission://budget/override",
               reason_ref: "reason://bounded",
               duration_seconds: 3_601
             })
  end
end
