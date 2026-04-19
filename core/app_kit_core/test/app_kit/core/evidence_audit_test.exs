defmodule AppKit.Core.EvidenceAuditTest do
  use ExUnit.Case, async: true

  alias AppKit.Core.AuditHashChainProjection
  alias AppKit.Core.SuppressionVisibilityProjection

  test "accepts audit hash chain operator projection" do
    assert {:ok, projection} = AuditHashChainProjection.new(base_audit_projection())

    assert projection.contract_name == "AppKit.AuditHashChainProjection.v1"
    assert projection.source_contract_name == "Platform.AuditHashChain.v1"
    assert projection.previous_hash == "genesis"
  end

  test "rejects audit projection with invalid hash or source contract" do
    assert {:error, :invalid_audit_hash_chain_projection} =
             AuditHashChainProjection.new(%{
               base_audit_projection()
               | chain_head_hash: "bad",
                 source_contract_name: "Legacy.AuditChain.v0"
             })
  end

  test "accepts visible suppression operator projection" do
    assert {:ok, projection} = SuppressionVisibilityProjection.new(base_suppression_projection())

    assert projection.contract_name == "AppKit.SuppressionVisibilityProjection.v1"
    assert projection.source_contract_name == "Platform.SuppressionVisibility.v1"
    assert projection.recovery_action_refs == ["recovery-action:m13:072"]
  end

  test "rejects hidden suppression and missing recovery action refs" do
    assert {:error, :invalid_suppression_visibility_projection} =
             SuppressionVisibilityProjection.new(%{
               base_suppression_projection()
               | operator_visibility: "hidden"
             })

    assert {:error, {:missing_required_fields, [:recovery_action_refs]}} =
             SuppressionVisibilityProjection.new(%{
               base_suppression_projection()
               | recovery_action_refs: []
             })
  end

  defp base_audit_projection do
    %{
      tenant_ref: "tenant:acme",
      installation_ref: "installation:acme",
      workspace_ref: "workspace:core",
      project_ref: "project:ops",
      environment_ref: "prod",
      principal_ref: "principal:operator-1",
      system_actor_ref: nil,
      resource_ref: "audit://phase4/m13/071",
      authority_packet_ref: "authority-packet:m13:071",
      permission_decision_ref: "permission-decision:m13:071",
      idempotency_key: "audit-hash-chain:m13:071",
      trace_id: "trace:m13:071",
      correlation_id: "correlation:m13:071",
      release_manifest_ref: "phase4-v6-milestone13",
      audit_ref: "audit:m13:071:1",
      previous_hash: "genesis",
      event_hash: valid_hash("event-1"),
      chain_head_hash: valid_hash("head"),
      writer_ref: "writer:citadel:audit",
      immutability_proof_ref: "immutability-proof:m13:071:1",
      source_contract_name: "Platform.AuditHashChain.v1"
    }
  end

  defp base_suppression_projection do
    %{
      tenant_ref: "tenant:acme",
      installation_ref: "installation:acme",
      workspace_ref: "workspace:core",
      project_ref: "project:ops",
      environment_ref: "prod",
      principal_ref: "principal:operator-1",
      system_actor_ref: nil,
      resource_ref: "suppression://semantic/072",
      authority_packet_ref: "authority-packet:m13:072",
      permission_decision_ref: "permission-decision:m13:072",
      idempotency_key: "suppression-visibility:m13:072",
      trace_id: "trace:m13:072",
      correlation_id: "correlation:m13:072",
      release_manifest_ref: "phase4-v6-milestone13",
      suppression_ref: "suppression://semantic/072",
      suppression_kind: "duplicate",
      reason_code: "semantic_duplicate",
      target_ref: "semantic://candidate/072",
      operator_visibility: "visible",
      recovery_action_refs: ["recovery-action:m13:072"],
      diagnostics_ref: "diagnostics://suppression/072",
      source_contract_name: "Platform.SuppressionVisibility.v1"
    }
  end

  defp valid_hash(seed) do
    "sha256:" <> Base.encode16(:crypto.hash(:sha256, seed), case: :lower)
  end
end
