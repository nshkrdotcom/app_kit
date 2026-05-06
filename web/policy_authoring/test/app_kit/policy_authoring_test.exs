defmodule AppKit.PolicyAuthoringTest do
  use ExUnit.Case, async: true

  alias AppKit.PolicyAuthoring

  test "builds diff and promotion with decision evidence" do
    assert {:ok, diff} =
             PolicyAuthoring.diff(%{
               diff_ref: "policy-diff://one",
               tenant_ref: "tenant://alpha",
               from_policy_ref: "policy://old",
               to_policy_ref: "policy://new",
               change_refs: ["change://guard", "change://budget"]
             })

    assert diff.change_refs == ["change://guard", "change://budget"]

    assert {:ok, promotion} =
             PolicyAuthoring.promote(%{
               request_ref: "request://policy/promote",
               tenant_ref: "tenant://alpha",
               prompt_ref: "prompt://one",
               guard_chain_ref: "guard-chain://one",
               budget_policy_ref: "budget-policy://one",
               connector_policy_ref: "connector-policy://one",
               decision_evidence_ref: "decision://human/one"
             })

    assert promotion.decision_evidence_ref == "decision://human/one"
  end

  test "requires forward-only rollback and rejects raw policy bodies" do
    assert {:ok, rollback} =
             PolicyAuthoring.rollback(%{
               request_ref: "request://policy/rollback",
               tenant_ref: "tenant://alpha",
               policy_ref: "policy://new",
               target_revision: 3,
               new_revision: 5,
               decision_evidence_ref: "decision://human/rollback"
             })

    assert rollback.new_revision == 5

    assert {:error, :policy_rollback_must_create_forward_revision} =
             PolicyAuthoring.rollback(%{
               request_ref: "request://policy/rollback",
               tenant_ref: "tenant://alpha",
               policy_ref: "policy://new",
               target_revision: 3,
               new_revision: 2,
               decision_evidence_ref: "decision://human/rollback"
             })

    assert {:error, {:raw_policy_authoring_payload_forbidden, :prompt_body}} =
             PolicyAuthoring.promote(%{
               request_ref: "request://policy/promote",
               tenant_ref: "tenant://alpha",
               prompt_ref: "prompt://one",
               guard_chain_ref: "guard-chain://one",
               budget_policy_ref: "budget-policy://one",
               connector_policy_ref: "connector-policy://one",
               decision_evidence_ref: "decision://human/one",
               prompt_body: "private"
             })
  end
end
