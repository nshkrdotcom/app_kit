defmodule AppKit.Core.RuntimeReadback.DtosTest do
  use ExUnit.Case, async: true

  alias AppKit.Core.RuntimeReadback.{
    CommandReconciliation,
    CommandResult,
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
