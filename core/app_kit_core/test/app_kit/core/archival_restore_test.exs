defmodule AppKit.Core.ArchivalRestoreTest do
  use ExUnit.Case, async: true

  alias AppKit.Core.ArchivalConflictProjection
  alias AppKit.Core.ArchivalSweepProjection
  alias AppKit.Core.ColdRestoreArtifactProjection
  alias AppKit.Core.ColdRestoreTraceProjection

  test "builds cold restore trace projections for operator restore workflows" do
    assert {:ok, projection} =
             ColdRestoreTraceProjection.new(
               base_attrs()
               |> Map.merge(%{
                 restore_request_ref: "restore-request:trace:1",
                 archive_partition_ref: "archive-partition:tenant-1:2026-04",
                 hot_index_ref: "hot-index:trace-archive-1",
                 cold_object_ref: "cold-object:archive/inst-1/subject-1/1",
                 restore_consistency_hash:
                   "sha256:8f434346648f6b96df89dda901c5176b10a6d83961dd3c1ac88b59b2dc327aa4",
                 source_contract_name: "Mezzanine.ColdRestoreTraceQuery.v1"
               })
             )

    assert projection.contract_name == "AppKit.ColdRestoreTraceProjection.v1"
    assert projection.source_contract_name == "Mezzanine.ColdRestoreTraceQuery.v1"
  end

  test "builds cold restore artifact projections for incident export" do
    assert {:ok, projection} =
             ColdRestoreArtifactProjection.new(
               base_attrs()
               |> Map.merge(%{
                 artifact_id: "artifact-123",
                 artifact_kind: "run_log",
                 artifact_hash:
                   "sha256:ed7002b439e9ac845f2233ce2e61e5b32c02fb0722d3cc9045a91b46f41c1590",
                 lineage_ref: "lineage:artifact-123",
                 archive_object_ref: "cold-object:archive/inst-1/artifact-123",
                 restore_validation_ref: "restore-validation:artifact-123",
                 source_contract_name: "Mezzanine.ColdRestoreArtifactQuery.v1"
               })
             )

    assert projection.contract_name == "AppKit.ColdRestoreArtifactProjection.v1"
    assert projection.artifact_id == "artifact-123"
  end

  test "builds conflict and sweep projections with deterministic operator actions" do
    assert {:ok, conflict} =
             ArchivalConflictProjection.new(
               base_attrs()
               |> Map.merge(%{
                 conflict_ref: "archival-conflict:trace:m12:062",
                 hot_hash:
                   "sha256:ab0b934789acee88a3a39b141f9a0602f075cb5403b7cce210c3acdac0d5686d",
                 cold_hash:
                   "sha256:ed7002b439e9ac845f2233ce2e61e5b32c02fb0722d3cc9045a91b46f41c1590",
                 precedence_rule: :quarantine_until_operator_resolution,
                 quarantine_ref: "quarantine:archive-conflict:1",
                 resolution_action_ref: "operator-action:resolve-archive-conflict:1",
                 source_contract_name: "Mezzanine.ArchivalConflict.v1"
               })
             )

    assert conflict.contract_name == "AppKit.ArchivalConflictProjection.v1"
    assert conflict.precedence_rule == "quarantine_until_operator_resolution"

    assert {:ok, sweep} =
             ArchivalSweepProjection.new(
               base_attrs()
               |> Map.merge(%{
                 sweep_ref: "archival-sweep:tenant-1:2026-04-19T12:00:00Z",
                 artifact_ref: "artifact-123",
                 retry_count: 3,
                 retry_policy_ref: "retry-policy:archive-sweep:v1",
                 quarantine_ref: "quarantine:archive-sweep:artifact-123",
                 next_retry_at: "2026-04-19T12:30:00Z",
                 source_contract_name: "Mezzanine.ArchivalSweep.v1"
               })
             )

    assert sweep.contract_name == "AppKit.ArchivalSweepProjection.v1"
    assert sweep.retry_count == 3
  end

  test "rejects missing authority, same hash conflicts, and invalid sweep retry counts" do
    assert {:error, {:missing_required_fields, fields}} =
             ColdRestoreTraceProjection.new(base_attrs() |> Map.delete(:authority_packet_ref))

    assert :authority_packet_ref in fields

    same_hash = "sha256:ab0b934789acee88a3a39b141f9a0602f075cb5403b7cce210c3acdac0d5686d"

    assert {:error, :invalid_archival_conflict_projection} =
             ArchivalConflictProjection.new(
               base_attrs()
               |> Map.merge(%{
                 conflict_ref: "archival-conflict:trace:m12:062",
                 hot_hash: same_hash,
                 cold_hash: same_hash,
                 precedence_rule: :cold_authoritative,
                 quarantine_ref: "quarantine:archive-conflict:1",
                 resolution_action_ref: "operator-action:resolve-archive-conflict:1",
                 source_contract_name: "Mezzanine.ArchivalConflict.v1"
               })
             )

    assert {:error, :invalid_archival_sweep_projection} =
             ArchivalSweepProjection.new(
               base_attrs()
               |> Map.merge(%{
                 sweep_ref: "archival-sweep:tenant-1:2026-04-19T12:00:00Z",
                 artifact_ref: "artifact-123",
                 retry_count: -1,
                 retry_policy_ref: "retry-policy:archive-sweep:v1",
                 quarantine_ref: "quarantine:archive-sweep:artifact-123",
                 next_retry_at: "2026-04-19T12:30:00Z",
                 source_contract_name: "Mezzanine.ArchivalSweep.v1"
               })
             )
  end

  defp base_attrs do
    %{
      tenant_ref: "tenant-1",
      installation_ref: "inst-1",
      workspace_ref: "workspace-main",
      project_ref: "project-core",
      environment_ref: "prod",
      system_actor_ref: "system:archival-restore",
      resource_ref: "archive:inst-1:subject-1",
      authority_packet_ref: "authz-packet-archive-restore",
      permission_decision_ref: "decision-archive-restore",
      idempotency_key: "archive-restore:trace:m12:060",
      trace_id: "trace:m12:060",
      correlation_id: "corr-archive-restore",
      release_manifest_ref: "phase4-v6-milestone12"
    }
  end
end
