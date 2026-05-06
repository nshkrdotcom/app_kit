defmodule AppKit.CostDashboardTest do
  use ExUnit.Case, async: true

  alias AppKit.CostDashboard

  test "renders redacted cost and budget rows" do
    assert {:ok, dashboard} =
             CostDashboard.dashboard(%{
               dashboard_ref: "dashboard://cost",
               tenant_ref: "tenant://alpha",
               threshold_policy_ref: "threshold://cost/redact",
               cost_rows: [
                 %{
                   fact_ref: "cost-fact://one",
                   amount_class: :redacted_below_floor,
                   provider_account_ref: "provider-account://private"
                 }
               ],
               budget_rows: [
                 %{
                   budget_ref: "budget://one",
                   decision_class: :allow_warn_soft
                 }
               ]
             })

    assert dashboard.redaction_posture == "amount_classes_and_refs_only"
    assert [%{provider_account_ref: "provider-account://redacted"}] = dashboard.cost_rows
  end

  test "rejects raw amount and provider account ids" do
    assert {:error, {:raw_cost_dashboard_payload_forbidden, :cost_amount}} =
             CostDashboard.dashboard(%{
               dashboard_ref: "dashboard://cost",
               tenant_ref: "tenant://alpha",
               threshold_policy_ref: "threshold://cost/redact",
               cost_amount: 100
             })

    assert {:error, {:raw_cost_dashboard_payload_forbidden, :provider_account_id}} =
             CostDashboard.dashboard(%{
               dashboard_ref: "dashboard://cost",
               tenant_ref: "tenant://alpha",
               threshold_policy_ref: "threshold://cost/redact",
               provider_account_id: "private-id"
             })
  end
end
