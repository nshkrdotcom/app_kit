defmodule AppKit.Core.RevisionEpochTest do
  use ExUnit.Case, async: true

  alias AppKit.Core.InstallationRevisionEpochFence
  alias AppKit.Core.LeaseRevocationEvidence

  test "builds revision epoch fence DTOs for accepted operator projections" do
    assert {:ok, fence} =
             InstallationRevisionEpochFence.new(%{
               tenant_ref: "tenant-a",
               installation_ref: "inst-a",
               workspace_ref: "workspace-main",
               project_ref: "project-core",
               environment_ref: "prod",
               system_actor_ref: "system:revision-gate",
               resource_ref: "lease:read:run-123",
               authority_packet_ref: "authz-packet-10",
               permission_decision_ref: "decision-10",
               idempotency_key: "revision-epoch:run-123",
               trace_id: "trace:phase4:m10:063",
               correlation_id: "corr-revision-epoch",
               release_manifest_ref: "phase4-v6-milestone10",
               installation_revision: 42,
               activation_epoch: 7,
               lease_epoch: 5,
               node_id: "node:worker-a",
               fence_decision_ref: "fence:run-123:accepted",
               fence_status: :accepted,
               stale_reason: "none"
             })

    assert fence.contract_name == "AppKit.InstallationRevisionEpochFence.v1"
    assert fence.fence_status == "accepted"
    assert fence.installation_revision == 42
  end

  test "rejects revision epoch fence DTOs with missing scope or bad stale evidence" do
    assert {:error, {:missing_required_fields, fields}} =
             InstallationRevisionEpochFence.new(%{
               tenant_ref: "tenant-a",
               installation_ref: "inst-a",
               system_actor_ref: "system:revision-gate",
               authority_packet_ref: "authz-packet-10",
               permission_decision_ref: "decision-10",
               idempotency_key: "revision-epoch:run-123",
               correlation_id: "corr-revision-epoch",
               release_manifest_ref: "phase4-v6-milestone10",
               installation_revision: 42,
               activation_epoch: 7,
               lease_epoch: 5,
               node_id: "node:worker-a",
               fence_decision_ref: "fence:run-123:accepted",
               fence_status: "accepted",
               stale_reason: "none"
             })

    assert :workspace_ref in fields
    assert :trace_id in fields

    assert {:error, :invalid_installation_revision_epoch_fence} =
             InstallationRevisionEpochFence.new(
               Map.merge(valid_revision_epoch_fence(), %{
                 fence_status: "rejected",
                 stale_reason: "none",
                 attempted_installation_revision: 41
               })
             )
  end

  test "builds lease revocation DTOs for operator projections" do
    assert {:ok, revocation} =
             LeaseRevocationEvidence.new(%{
               tenant_ref: "tenant-a",
               installation_ref: "inst-a",
               workspace_ref: "workspace-main",
               project_ref: "project-core",
               environment_ref: "prod",
               system_actor_ref: "system:lease-revoker",
               resource_ref: "lease:stream:run-123",
               authority_packet_ref: "authz-packet-11",
               permission_decision_ref: "decision-11",
               idempotency_key: "lease-revocation:run-123",
               trace_id: "trace:phase4:m10:077",
               correlation_id: "corr-lease-revocation",
               release_manifest_ref: "phase4-v6-milestone10",
               lease_ref: "lease:stream:run-123",
               revocation_ref: "lease-revocation:stream:run-123:1",
               revoked_at: "2026-04-19T00:00:00Z",
               lease_scope: %{"tenant_ref" => "tenant-a", "family" => "runtime_stream"},
               cache_invalidation_ref: "lease-cache-invalidation:stream:run-123:1",
               post_revocation_attempt_ref: "attempt:stream:run-123:after-revoke",
               lease_status: :rejected_after_revocation
             })

    assert revocation.contract_name == "AppKit.LeaseRevocationEvidence.v1"
    assert revocation.lease_status == "rejected_after_revocation"
    assert revocation.lease_scope["tenant_ref"] == "tenant-a"
  end

  test "rejects lease revocation DTOs with empty scope or missing actor" do
    assert {:error, :invalid_lease_revocation_evidence} =
             LeaseRevocationEvidence.new(%{valid_lease_revocation() | lease_scope: %{}})

    assert {:error, {:missing_required_fields, fields}} =
             LeaseRevocationEvidence.new(
               Map.merge(valid_lease_revocation(), %{
                 principal_ref: nil,
                 system_actor_ref: nil
               })
             )

    assert :principal_ref_or_system_actor_ref in fields
  end

  defp valid_revision_epoch_fence do
    %{
      tenant_ref: "tenant-a",
      installation_ref: "inst-a",
      workspace_ref: "workspace-main",
      project_ref: "project-core",
      environment_ref: "prod",
      system_actor_ref: "system:revision-gate",
      resource_ref: "lease:read:run-123",
      authority_packet_ref: "authz-packet-10",
      permission_decision_ref: "decision-10",
      idempotency_key: "revision-epoch:run-123",
      trace_id: "trace:phase4:m10:063",
      correlation_id: "corr-revision-epoch",
      release_manifest_ref: "phase4-v6-milestone10",
      installation_revision: 42,
      activation_epoch: 7,
      lease_epoch: 5,
      node_id: "node:worker-a",
      fence_decision_ref: "fence:run-123:accepted",
      fence_status: "accepted",
      stale_reason: "none"
    }
  end

  defp valid_lease_revocation do
    %{
      tenant_ref: "tenant-a",
      installation_ref: "inst-a",
      workspace_ref: "workspace-main",
      project_ref: "project-core",
      environment_ref: "prod",
      system_actor_ref: "system:lease-revoker",
      resource_ref: "lease:stream:run-123",
      authority_packet_ref: "authz-packet-11",
      permission_decision_ref: "decision-11",
      idempotency_key: "lease-revocation:run-123",
      trace_id: "trace:phase4:m10:077",
      correlation_id: "corr-lease-revocation",
      release_manifest_ref: "phase4-v6-milestone10",
      lease_ref: "lease:stream:run-123",
      revocation_ref: "lease-revocation:stream:run-123:1",
      revoked_at: "2026-04-19T00:00:00Z",
      lease_scope: %{"tenant_ref" => "tenant-a", "family" => "runtime_stream"},
      cache_invalidation_ref: "lease-cache-invalidation:stream:run-123:1",
      post_revocation_attempt_ref: "attempt:stream:run-123:after-revoke",
      lease_status: "revoked"
    }
  end
end
