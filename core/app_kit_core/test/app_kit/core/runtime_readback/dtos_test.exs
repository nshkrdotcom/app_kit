defmodule AppKit.Core.RuntimeReadback.DtosTest do
  use ExUnit.Case, async: true

  alias AppKit.Core.RuntimeReadback.{
    CommandReconciliation,
    CommandResult,
    Diagnostic,
    RetryRow,
    RuntimeRow,
    RuntimeRunDetail,
    RuntimeStateSnapshot,
    WorkspaceRef
  }

  test "workspace refs require redacted public paths" do
    assert {:ok, %WorkspaceRef{path_redacted?: true}} =
             WorkspaceRef.new(%{id: "workspace://safe", path_redacted?: true})

    assert {:error, :invalid_workspace_ref} =
             WorkspaceRef.new(%{id: "workspace://safe", path_redacted?: false})

    assert {:error, :invalid_workspace_ref} =
             WorkspaceRef.new(%{
               id: "workspace://safe",
               path_redacted?: true,
               workspace_path: "/tmp/raw"
             })
  end

  test "state snapshot sorts rows by updated_at descending by default" do
    assert {:ok, snapshot} =
             RuntimeStateSnapshot.new(%{
               tenant_ref: "tenant://one",
               installation_ref: "installation://one",
               rows: [
                 %{
                   subject_ref: "subject://old",
                   run_ref: "run://old",
                   state: :running,
                   updated_at: "2026-04-27T00:00:00Z"
                 },
                 %{
                   subject_ref: "subject://new",
                   run_ref: "run://new",
                   state: :running,
                   updated_at: "2026-04-27T00:00:02Z"
                 }
               ]
             })

    assert Enum.map(snapshot.rows, & &1.subject_ref) == ["subject://new", "subject://old"]

    assert snapshot.persistence_posture.persistence_profile_ref ==
             "persistence-profile://mickey-mouse"

    assert Enum.all?(snapshot.rows, fn %RuntimeRow{} = row ->
             row.persistence_posture.raw_payload_persistence? == false
           end)
  end

  test "run detail sorts events deterministically and preserves unknown event kinds" do
    assert {:ok, detail} =
             RuntimeRunDetail.new(%{
               run_ref: "run://one",
               events: [
                 %{
                   event_ref: "event://b",
                   event_seq: 2,
                   event_kind: "future_async_wait",
                   observed_at: "2026-04-27T00:00:02Z"
                 },
                 %{
                   event_ref: "event://a",
                   event_seq: 1,
                   event_kind: :run_started,
                   observed_at: "2026-04-27T00:00:01Z"
                 }
               ]
             })

    assert Enum.map(detail.events, & &1.event_ref) == ["event://a", "event://b"]
    assert Enum.at(detail.events, 1).event_kind == "future_async_wait"
    assert detail.persistence_posture.raw_payload_persistence? == false
  end

  test "retry rows carry continuation due-time readback without product fields" do
    assert {:ok, retry} =
             RetryRow.new(%{
               retry_ref: "retry://work/1",
               attempt_ref: "attempt://work/1",
               status: "scheduled",
               reason: "source_still_active",
               scheduled_at: "2026-05-10T21:45:01Z",
               due_at: "2026-05-10T21:45:01Z",
               delay_ms: 1_000,
               delay_type: "continuation",
               continuation?: true,
               worker_ref: "worker://worker-a",
               workspace_ref: "workspace://work-1",
               metadata: %{"safe_action" => "schedule_continuation_retry"}
             })

    assert retry.delay_ms == 1_000
    assert retry.delay_type == "continuation"
    assert retry.continuation?
    assert retry.due_at == "2026-05-10T21:45:01Z"

    assert %{"due_at" => "2026-05-10T21:45:01Z", "metadata" => %{"safe_action" => _}} =
             RetryRow.dump(retry)
  end

  test "command result supports inspect_memory_proof without fabricating proof refs" do
    assert {:ok, result} =
             CommandResult.new(%{
               command_ref: "command://memory-proof",
               command_kind: :inspect_memory_proof,
               accepted?: true,
               coalesced?: false,
               status: :accepted,
               workflow_effect_state: "not_available",
               diagnostics: [
                 %{severity: :info, code: "memory_proof_not_available", message: "Phase 7 only"}
               ]
             })

    assert result.workflow_effect_state == "not_available"
    assert result.receipt_ref == nil

    assert result.persistence_posture.persistence_tier_ref ==
             "persistence-tier://memory-ephemeral"
  end

  test "runtime readback supports retention-off posture without blocking readback" do
    assert {:ok, snapshot} =
             RuntimeStateSnapshot.new(%{
               tenant_ref: "tenant://one",
               installation_ref: "installation://one",
               persistence_profile: :off
             })

    assert snapshot.rows == []
    assert snapshot.persistence_posture.retained? == false
    assert snapshot.persistence_posture.store_set_ref == "store-set://off"
  end

  test "diagnostics bound severity strings without accepting unknown atom names" do
    assert {:ok, %Diagnostic{severity: :warning}} =
             Diagnostic.new(%{
               severity: "warning",
               code: "bounded_severity",
               message: "bounded"
             })

    assert {:error, :invalid_diagnostic} =
             Diagnostic.new(%{
               severity: "provider_supplied_future_severity",
               code: "unbounded",
               message: "unbounded"
             })
  end

  test "database_first reconciliation has bounded terminal signal rejection reasons" do
    attrs =
      CommandReconciliation.terminal_signal_rejected(
        %{
          command_ref: "command://closed",
          command_kind: :pause,
          accepted?: true,
          coalesced?: false
        },
        "workflow_closed"
      )

    assert {:ok,
            %CommandResult{
              workflow_effect_state: "signal_rejected",
              terminal_reason: "workflow_closed"
            }} =
             CommandResult.new(attrs)
  end
end
