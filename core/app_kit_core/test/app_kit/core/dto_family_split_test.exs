defmodule AppKit.Core.DTOFamilySplitTest do
  use ExUnit.Case, async: true

  alias AppKit.Core.{
    BlockingCondition,
    NextStepPreview,
    ObserverDescriptor,
    OperatorAction,
    OperatorActionRequest,
    OperatorProjection,
    OperatorSignalResult,
    OperatorSurfaceProjection,
    PendingObligation,
    ReadLease,
    RunRequest,
    StreamAttachLease,
    TimelineEvent,
    UnifiedTrace,
    UnifiedTraceStep
  }

  alias AppKit.Core.RuntimeReadback.{
    CommandResult,
    ControlRequest,
    Diagnostic,
    PollingState,
    RateLimitSnapshot,
    RefreshRequest,
    RetryRow,
    RuntimeEventRow,
    RuntimeRow,
    RuntimeRunDetail,
    RuntimeStateSnapshot,
    RuntimeSubjectDetail,
    SessionRef,
    TokenTotals,
    WorkspaceRef
  }

  @trace_id "0123456789abcdef0123456789abcdef"
  @now ~U[2026-05-18 12:00:00Z]

  test "operational DTO families reconstruct from their public structs" do
    assert_struct_round_trip(RunRequest, %{
      subject_ref: %{id: "subject-1", subject_kind: "coding_task"},
      recipe_ref: "recipe-default"
    })

    assert_struct_round_trip(OperatorAction, %{
      action_ref: %{id: "action-1", action_kind: "pause"},
      label: "Pause"
    })

    assert_struct_round_trip(OperatorActionRequest, %{
      action_ref: %{id: "action-1", action_kind: "pause"},
      params: %{"reason" => "operator"}
    })

    assert_struct_round_trip(TimelineEvent, %{
      event_kind: "run_scheduled",
      occurred_at: @now,
      actor_ref: %{id: "actor-1", kind: :operator}
    })

    assert_struct_round_trip(UnifiedTraceStep, %{
      ref: "trace-step-1",
      source: "execution_record",
      trace_id: @trace_id
    })

    assert_struct_round_trip(UnifiedTrace, %{
      trace_id: @trace_id,
      steps: [%{ref: "trace-step-1", source: "execution_record"}]
    })

    assert_struct_round_trip(ReadLease, %{
      lease_ref: %{id: "read-lease-1", allowed_family: "unified_trace"},
      trace_id: @trace_id,
      expires_at: @now,
      lease_token: "read-token"
    })

    assert_struct_round_trip(StreamAttachLease, %{
      lease_ref: %{id: "stream-lease-1", allowed_family: "runtime_stream"},
      trace_id: @trace_id,
      expires_at: @now,
      attach_token: "stream-token"
    })
  end

  test "operator projection DTO families reconstruct from their public structs" do
    assert_struct_round_trip(PendingObligation, %{
      obligation_id: "obligation-1",
      obligation_kind: "review",
      status: "pending"
    })

    assert_struct_round_trip(BlockingCondition, %{
      blocker_kind: "review_pending",
      status: "blocked"
    })

    assert_struct_round_trip(NextStepPreview, %{
      step_kind: "record_review_decision",
      status: "blocked"
    })

    assert_struct_round_trip(OperatorProjection, %{
      subject_ref: %{id: "subject-1", subject_kind: "coding_task"},
      lifecycle_state: "waiting_review",
      pending_obligations: [
        %{obligation_id: "obligation-1", obligation_kind: "review", status: "pending"}
      ],
      blocking_conditions: [%{blocker_kind: "review_pending", status: "blocked"}],
      next_step_preview: %{step_kind: "record_review_decision", status: "blocked"}
    })

    assert_struct_round_trip(OperatorSurfaceProjection, operator_surface_projection_attrs())
    assert_struct_round_trip(OperatorSignalResult, operator_signal_result_attrs())
    assert_struct_round_trip(ObserverDescriptor, observer_descriptor_attrs())
  end

  test "runtime readback DTO families reconstruct from dumped public maps" do
    assert_dump_round_trip(SessionRef, "session://one")

    assert_dump_round_trip(WorkspaceRef, %{
      id: "workspace://redacted",
      path_redacted?: true,
      display_label: "redacted workspace"
    })

    assert_dump_round_trip(Diagnostic, %{
      severity: :warning,
      code: "bounded",
      message: "bounded diagnostic"
    })

    assert_dump_round_trip(TokenTotals, %{
      total_input_tokens: 3,
      total_output_tokens: 5,
      total_tokens: 8
    })

    assert_dump_round_trip(RateLimitSnapshot, %{
      limit_id: "limit://runtime",
      remaining: 10
    })

    assert_dump_round_trip(PollingState, %{
      checking?: true,
      poll_interval_ms: 1_000,
      staleness_ms: 0
    })

    assert_dump_round_trip(RuntimeEventRow, %{
      event_ref: "event://runtime/1",
      event_seq: 1,
      event_kind: :run_started,
      observed_at: @now
    })

    assert_dump_round_trip(RetryRow, %{
      retry_ref: "retry://run/1",
      attempt_ref: "attempt://run/1",
      status: "scheduled",
      due_at: @now,
      continuation?: true
    })

    assert_dump_round_trip(RuntimeRow, %{
      subject_ref: "subject://one",
      run_ref: "run://one",
      state: :running,
      updated_at: @now,
      session_ref: %{id: "session://one"},
      workspace_ref: %{id: "workspace://redacted", path_redacted?: true}
    })

    assert_dump_round_trip(CommandResult, %{
      command_ref: "command://one",
      command_kind: :pause,
      accepted?: true,
      coalesced?: false,
      status: :accepted,
      workflow_effect_state: :pending_signal
    })

    assert_dump_round_trip(RefreshRequest, %{
      idempotency_key: "refresh-1",
      actor_ref: "actor://one",
      scope_ref: "run://one",
      operations: [:runtime_state]
    })

    assert_dump_round_trip(ControlRequest, %{
      idempotency_key: "control-1",
      actor_ref: "actor://one",
      subject_ref: "subject://one",
      action: :pause
    })

    assert_dump_round_trip(RuntimeStateSnapshot, %{
      tenant_ref: "tenant://one",
      installation_ref: "installation://one",
      rows: [
        %{subject_ref: "subject://one", run_ref: "run://one", state: :running, updated_at: @now}
      ]
    })

    assert_dump_round_trip(RuntimeSubjectDetail, %{
      subject_ref: "subject://one",
      rows: [
        %{subject_ref: "subject://one", run_ref: "run://one", state: :running, updated_at: @now}
      ]
    })

    assert_dump_round_trip(RuntimeRunDetail, %{
      run_ref: "run://one",
      runtime_row: %{
        subject_ref: "subject://one",
        run_ref: "run://one",
        state: :running,
        updated_at: @now
      }
    })
  end

  defp assert_struct_round_trip(module, attrs) do
    assert {:ok, first} = module.new(attrs)
    assert {:ok, second} = module.new(Map.from_struct(first))
    assert second == first
  end

  defp assert_dump_round_trip(module, attrs) do
    assert {:ok, first} = module.new(attrs)
    assert {:ok, second} = module.new(module.dump(first))
    assert module.dump(second) == module.dump(first)
  end

  defp operator_surface_projection_attrs do
    %{
      projection_ref: %{
        name: "operator_signal_projection",
        subject_ref: %{id: "subject-1", subject_kind: "coding_task"},
        schema_ref: "AppKit.OperatorSurfaceProjection.v1",
        schema_version: 1
      },
      tenant_ref: %{id: "tenant-1"},
      installation_ref: %{id: "installation-1", pack_slug: "coding_ops"},
      operator_ref: %{id: "operator-1", kind: :human},
      target_ref: %{id: "workflow/run-1", kind: "workflow"},
      authority_packet_ref: "authority-packet-1",
      permission_decision_ref: "decision-1",
      idempotency_key: "operator-signal-1",
      trace_id: @trace_id,
      correlation_id: "correlation-1",
      release_manifest_ref: "release-manifest-1",
      projection_version: 1,
      source_event_position: 1,
      observed_at: @now,
      produced_at: @now,
      staleness_class: :pending_workflow_ack,
      dispatch_state: :delivered_to_temporal,
      workflow_effect_state: :pending
    }
  end

  defp operator_signal_result_attrs do
    %{
      command_id: "command-1",
      signal_id: "signal-1",
      workflow_ref: "workflow://run-1",
      tenant_ref: %{id: "tenant-1"},
      installation_ref: %{id: "installation-1", pack_slug: "coding_ops"},
      operator_ref: %{id: "operator-1", kind: :human},
      resource_ref: %{id: "workflow/run-1", kind: "workflow"},
      authority_packet_ref: "authority-packet-1",
      permission_decision_ref: "decision-1",
      idempotency_key: "operator-signal-1",
      trace_id: @trace_id,
      correlation_id: "correlation-1",
      release_manifest_version: "release-manifest-1",
      authority_state: :authorized,
      local_state: :accepted,
      dispatch_state: :delivered_to_temporal,
      workflow_effect_state: :pending,
      projection_state: :fresh,
      operator_message: "accepted"
    }
  end

  defp observer_descriptor_attrs do
    %{
      observer_ref: "observer-1",
      projection_ref: %{
        name: "operator_signal_projection",
        subject_ref: %{id: "subject-1", subject_kind: "coding_task"},
        schema_ref: "AppKit.ObserverDescriptor.v1",
        schema_version: 1
      },
      tenant_ref: %{id: "tenant-1"},
      installation_ref: %{id: "installation-1", pack_slug: "coding_ops"},
      principal_ref: %{id: "operator-1", kind: :human},
      resource_ref: %{id: "workflow/run-1", kind: "workflow"},
      authority_packet_ref: "authority-packet-1",
      permission_decision_ref: "decision-1",
      idempotency_key: "observer-1",
      trace_id: @trace_id,
      correlation_id: "correlation-1",
      release_manifest_ref: "release-manifest-1",
      staleness_class: :diagnostic_only,
      redaction_policy_ref: "redaction-policy-1",
      allowed_fields: ["observer_ref"],
      blocked_fields: ["raw_provider_metadata"]
    }
  end
end
