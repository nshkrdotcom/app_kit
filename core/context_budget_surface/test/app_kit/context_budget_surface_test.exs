defmodule AppKit.ContextBudgetSurfaceTest do
  use ExUnit.Case, async: true

  alias AppKit.ContextBudgetSurface

  test "budget view projections redact raw amount fields" do
    assert {:ok, projection} =
             ContextBudgetSurface.view_projection(%{
               budget_ref: budget_ref(),
               unit_class: :token,
               limit_units: 100,
               used_units: 20,
               residual_units: 80
             })

    assert projection.residual_units == 80

    assert {:error, {:raw_budget_surface_payload_forbidden, :amount}} =
             ContextBudgetSurface.view_projection(%{
               budget_ref: budget_ref(),
               unit_class: :token,
               limit_units: 100,
               used_units: 20,
               residual_units: 80,
               amount: "$12.34"
             })
  end

  test "override requests require bounded duration" do
    assert {:error, :budget_override_duration_unbounded} =
             ContextBudgetSurface.override_request(%{
               request_ref: "request://override",
               budget_ref: budget_ref(),
               permission_ref: "permission://budget/override",
               reason_ref: "decision://operator",
               duration_seconds: 3601,
               added_units: 1
             })

    assert {:ok, request} =
             ContextBudgetSurface.override_request(%{
               request_ref: "request://override",
               budget_ref: budget_ref(),
               permission_ref: "permission://budget/override",
               reason_ref: "decision://operator",
               duration_seconds: 60,
               added_units: 1
             })

    assert request.added_units == 1
  end

  test "exhaustion records carry bounded decisions" do
    assert {:ok, record} =
             ContextBudgetSurface.exhaustion_record(%{
               budget_ref: budget_ref(),
               locus: :preflight,
               decision: %{
                 budget_ref: "budget://a",
                 decision: :deny_exhausted,
                 reason: :cumulative_overflow,
                 requested_units: 10,
                 granted_units: 0,
                 residual_units: 0
               },
               trace_ref: "trace://a"
             })

    assert record.decision.decision == :deny_exhausted
  end

  defp budget_ref do
    %{
      budget_ref: "budget://a",
      tenant_ref: "tenant://a",
      authority_ref: "authority://a",
      installation_ref: "installation://a",
      trace_ref: "trace://a"
    }
  end
end
