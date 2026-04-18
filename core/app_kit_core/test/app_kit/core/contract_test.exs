defmodule AppKit.Core.ContractTest do
  use ExUnit.Case, async: true

  alias AppKit.Core.{
    ActionResult,
    ActorRef,
    BindingDescriptor,
    BindingEnvelope,
    BindingFailurePosture,
    BindingOwnership,
    BlockingCondition,
    DecisionRef,
    DecisionSummary,
    ExecutionRef,
    FilterSet,
    InstallationBinding,
    InstallationRef,
    InstallResult,
    InstallTemplate,
    ReadLease,
    ReadLeaseRef,
    OperatorAction,
    OperatorActionRef,
    OperatorActionRequest,
    OperatorProjection,
    NextStepPreview,
    PageRequest,
    PageResult,
    PendingObligation,
    ProjectionRef,
    RequestContext,
    RunRequest,
    SortSpec,
    StreamAttachLease,
    StreamAttachLeaseRef,
    SubjectDetail,
    SubjectSummary,
    SurfaceError,
    Telemetry,
    TenantRef,
    TimelineEvent,
    TraceIdentity,
    UnifiedTrace,
    UnifiedTraceStep
  }

  alias AppKit.Core.Backends.{
    InstallationBackend,
    OperatorBackend,
    ReviewBackend,
    WorkBackend,
    WorkQueryBackend
  }

  test "builds nested request context primitives" do
    assert {:ok, context} =
             RequestContext.new(%{
               trace_id: "0123456789abcdef0123456789abcdef",
               actor_ref: %{id: "user-1", kind: :human, roles: ["operator"]},
               tenant_ref: %{id: "tenant-1", slug: "acme"},
               installation_ref: %{id: "inst-1", pack_slug: "ops_pack", status: :active},
               causation_id: "cause-1",
               request_id: "req-1",
               idempotency_key: "idem-1",
               feature_flags: %{"new_review_path" => true}
             })

    assert %ActorRef{id: "user-1", kind: :human} = context.actor_ref
    assert %TenantRef{id: "tenant-1", slug: "acme"} = context.tenant_ref

    assert %InstallationRef{id: "inst-1", pack_slug: "ops_pack", status: :active} =
             context.installation_ref
  end

  test "rejects invalid request-context feature flags" do
    assert {:error, :invalid_request_context} =
             RequestContext.new(%{
               trace_id: "0123456789abcdef0123456789abcdef",
               actor_ref: %{id: "user-1", kind: :human},
               tenant_ref: %{id: "tenant-1"},
               feature_flags: %{new_review_path: true}
             })
  end

  test "mints a W3C trace id when request context omits one" do
    assert {:ok, context} =
             RequestContext.new(%{
               actor_ref: %{id: "user-1", kind: :human},
               tenant_ref: %{id: "tenant-1"}
             })

    assert TraceIdentity.valid?(context.trace_id)
  end

  test "freezes repo-owned Stage 11 telemetry event shapes" do
    assert Telemetry.event_name(:trace_minted) == [:app_kit, :trace, :minted]
    assert Telemetry.metadata_keys(:trace_rejected) == [:reason, :tenant_id, :source, :surface]

    assert Telemetry.measurement_keys(:unified_trace_assembled) == [
             :count,
             :step_count,
             :join_key_count
           ]

    assert Telemetry.metadata_keys(:unified_trace_assembled) == [
             :trace_id,
             :tenant_id,
             :installation_id,
             :execution_id,
             :source,
             :surface
           ]
  end

  test "rejects invalid request-context trace ids" do
    assert {:error, :invalid_request_context} =
             RequestContext.new(%{
               trace_id: "trace-1",
               actor_ref: %{id: "user-1", kind: :human},
               tenant_ref: %{id: "tenant-1"}
             })
  end

  test "builds paging, sorting, and filtering primitives" do
    assert {:ok, page_request} =
             PageRequest.new(%{
               limit: 25,
               cursor: "cursor-1",
               sort: [%{field: "inserted_at", direction: :desc, nulls: :last}],
               filters: %{clauses: [%{"field" => "status", "op" => "eq", "value" => "queued"}]}
             })

    assert [%SortSpec{field: "inserted_at", direction: :desc, nulls: :last}] = page_request.sort

    assert %FilterSet{
             mode: :and,
             clauses: [%{"field" => "status", "op" => "eq", "value" => "queued"}]
           } =
             page_request.filters

    assert {:ok, page_result} =
             PageResult.new(%{
               entries: [%{id: "row-1"}],
               next_cursor: nil,
               total_count: 1,
               has_more: false
             })

    assert page_result.total_count == 1
    assert page_result.has_more == false
  end

  test "rejects invalid paging primitives" do
    assert {:error, :invalid_page_request} =
             PageRequest.new(%{
               limit: 0,
               sort: [%{field: "inserted_at", direction: :sideways}]
             })
  end

  test "builds stable aggregate refs and summaries" do
    opened_at = DateTime.from_naive!(~N[2026-04-16 09:00:00], "Etc/UTC")
    updated_at = DateTime.from_naive!(~N[2026-04-16 09:05:00], "Etc/UTC")

    assert {:ok, subject_summary} =
             SubjectSummary.new(%{
               subject_ref: %{
                 id: "subj-1",
                 subject_kind: "expense_request",
                 installation_ref: %{id: "inst-1", pack_slug: "expense_approval"}
               },
               lifecycle_state: "submitted",
               title: "Approve expense",
               summary: "Waiting for capture",
               opened_at: opened_at,
               updated_at: updated_at,
               schema_ref: "expense/request",
               schema_version: 2,
               payload: %{"amount" => 42}
             })

    assert {:ok, subject_detail} =
             SubjectDetail.new(%{
               subject_ref: subject_summary.subject_ref,
               lifecycle_state: "processing",
               current_execution_ref: %{
                 id: "exec-1",
                 subject_ref: %{id: "subj-1", subject_kind: "expense_request"},
                 recipe_ref: "expense_capture",
                 dispatch_state: :accepted
               },
               pending_decision_refs: [
                 %{
                   id: "dec-1",
                   decision_kind: "approval",
                   subject_ref: %{id: "subj-1", subject_kind: "expense_request"}
                 }
               ],
               pending_obligations: [
                 %{
                   obligation_id: "ob-1",
                   obligation_kind: "review",
                   status: "pending",
                   summary: "Operator review required",
                   decision_ref_id: "dec-1",
                   blocking?: true
                 }
               ],
               blocking_conditions: [
                 %{
                   blocker_kind: "review_pending",
                   status: "blocked",
                   summary: "Waiting for operator review",
                   obligation_id: "ob-1",
                   decision_ref_id: "dec-1"
                 }
               ],
               next_step_preview: %{
                 step_kind: "record_review_decision",
                 status: "blocked",
                 summary: "Record the pending review decision",
                 blocking_condition_kinds: ["review_pending"],
                 obligation_ids: ["ob-1"]
               },
               available_actions: [
                 %{
                   id: "action-1",
                   action_kind: "approve",
                   subject_ref: %{id: "subj-1", subject_kind: "expense_request"}
                 }
               ]
             })

    assert %ExecutionRef{recipe_ref: "expense_capture", dispatch_state: :accepted} =
             subject_detail.current_execution_ref

    assert [%DecisionRef{id: "dec-1"}] = subject_detail.pending_decision_refs

    assert [%PendingObligation{obligation_id: "ob-1", blocking?: true}] =
             subject_detail.pending_obligations

    assert [%BlockingCondition{blocker_kind: "review_pending"}] =
             subject_detail.blocking_conditions

    assert %NextStepPreview{step_kind: "record_review_decision"} =
             subject_detail.next_step_preview

    assert [%OperatorActionRef{id: "action-1"}] = subject_detail.available_actions

    assert {:ok, decision_summary} =
             DecisionSummary.new(%{
               decision_ref: %{id: "dec-1", decision_kind: "approval"},
               status: "pending",
               subject_ref: %{id: "subj-1", subject_kind: "expense_request"},
               summary: "Manager approval required"
             })

    assert %DecisionRef{id: "dec-1", decision_kind: "approval"} = decision_summary.decision_ref

    assert {:ok, projection_ref} =
             ProjectionRef.new(%{
               name: "review_queue",
               subject_ref: %{id: "subj-1", subject_kind: "expense_request"},
               schema_ref: "projection/review_queue",
               schema_version: 1
             })

    assert projection_ref.schema_version == 1
  end

  test "builds operator projection with first-class obligation, blocker, and next-step facts" do
    assert {:ok, projection} =
             OperatorProjection.new(%{
               subject_ref: %{id: "subj-1", subject_kind: "expense_request"},
               lifecycle_state: "awaiting_review",
               pending_obligations: [
                 %{
                   obligation_id: "ob-1",
                   obligation_kind: "review",
                   status: "pending"
                 }
               ],
               blocking_conditions: [
                 %{
                   blocker_kind: "review_pending",
                   status: "blocked"
                 }
               ],
               next_step_preview: %{
                 step_kind: "record_review_decision",
                 status: "blocked"
               }
             })

    assert [%PendingObligation{obligation_id: "ob-1"}] = projection.pending_obligations
    assert [%BlockingCondition{blocker_kind: "review_pending"}] = projection.blocking_conditions
    assert %NextStepPreview{step_kind: "record_review_decision"} = projection.next_step_preview
  end

  test "builds action and error envelopes" do
    assert {:ok, surface_error} =
             SurfaceError.new(%{
               code: "not_found",
               message: "missing subject",
               kind: :not_found,
               retryable: false,
               details: %{"subject_id" => "subj-1"}
             })

    assert surface_error.kind == :not_found

    assert {:ok, action_result} =
             ActionResult.new(%{
               status: :accepted,
               action_ref: %{id: "action-1", action_kind: "approve"},
               execution_ref: %{id: "exec-1", recipe_ref: "expense_capture"},
               message: "queued"
             })

    assert %OperatorActionRef{id: "action-1"} = action_result.action_ref
    assert %ExecutionRef{id: "exec-1"} = action_result.execution_ref
  end

  test "builds operational DTOs for work control and operator surfaces" do
    occurred_at = DateTime.from_naive!(~N[2026-04-18 11:00:00], "Etc/UTC")
    trace_id = "fedcba9876543210fedcba9876543210"

    assert {:ok, run_request} =
             RunRequest.new(%{
               subject_ref: %{id: "subj-1", subject_kind: "expense_request"},
               recipe_ref: "expense_capture",
               params: %{"priority" => "high"},
               reason: "start governed execution"
             })

    assert {:ok, operator_action} =
             OperatorAction.new(%{
               action_ref: %{
                 id: "subj-1:cancel",
                 action_kind: "cancel",
                 subject_ref: %{id: "subj-1", subject_kind: "expense_request"}
               },
               label: "Cancel run",
               dangerous?: true,
               requires_confirmation?: true
             })

    assert {:ok, action_request} =
             OperatorActionRequest.new(%{
               action_ref: operator_action.action_ref,
               params: %{"reason" => "duplicate submission"},
               reason: "operator requested cancel"
             })

    assert {:ok, timeline_event} =
             TimelineEvent.new(%{
               ref: "evt-1",
               event_kind: "run_scheduled",
               occurred_at: occurred_at,
               summary: "Run scheduled for dispatch",
               actor_ref: %{id: "user-1", kind: :human},
               payload: %{"dispatch_state" => "pending_dispatch"}
             })

    assert {:ok, trace_step} =
             UnifiedTraceStep.new(%{
               ref: "trace-step-1",
               source: "execution_record",
               occurred_at: occurred_at,
               trace_id: trace_id,
               causation_id: "cause-1",
               freshness: "lower_authoritative_unreconciled",
               operator_actionable?: false,
               diagnostic?: false,
               payload: %{"dispatch_state" => "dispatching"}
             })

    assert {:ok, trace} =
             UnifiedTrace.new(%{
               trace_id: trace_id,
               installation_ref: %{id: "inst-1", pack_slug: "expense_approval"},
               join_keys: %{"subject_id" => "subj-1"},
               steps: [trace_step]
             })

    assert {:ok, projection} =
             OperatorProjection.new(%{
               subject_ref: %{id: "subj-1", subject_kind: "expense_request"},
               lifecycle_state: "processing",
               current_execution_ref: %{id: "exec-1", dispatch_state: :accepted},
               available_actions: [operator_action],
               timeline: [timeline_event],
               payload: %{"queue" => "expense_capture"}
             })

    assert %RunRequest{recipe_ref: "expense_capture"} = run_request
    assert %OperatorActionRef{action_kind: "cancel"} = action_request.action_ref
    assert %TimelineEvent{event_kind: "run_scheduled"} = timeline_event
    assert %UnifiedTraceStep{source: "execution_record"} = trace_step
    assert %UnifiedTrace{trace_id: ^trace_id} = trace
    assert %OperatorProjection{lifecycle_state: "processing"} = projection
  end

  test "builds installation DTOs" do
    assert {:ok, descriptor} =
             BindingDescriptor.new(%{
               attachment: "outer_brain.context_adapter",
               contract: :contributing,
               envelope: %{
                 staleness_class: :diagnostic_only,
                 trace_propagation: :required,
                 tenant_scope: :installation_scoped,
                 blast_radius: :installation,
                 timeout_ms: 750,
                 runbook_ref: "runbooks/memory_context"
               },
               failure: %{
                 on_unavailable: :proceed_without,
                 on_timeout: :proceed_without
               },
               ownership: %{
                 external_system: "Mem0",
                 external_system_ref: "mem0.primary",
                 operator_owner: "memory-platform"
               }
             })

    assert {:ok, install_template} =
             InstallTemplate.new(%{
               template_key: "expense/default",
               pack_slug: "expense_approval",
               pack_version: "1.2.3",
               default_bindings: %{"connector" => "expenses_api"}
             })

    assert {:ok, installation_binding} =
             InstallationBinding.new(%{
               binding_key: "expense_capture",
               binding_kind: :execution,
               config: %{"placement_ref" => "local_runner"},
               credential_ref: "cred-1"
             })

    assert {:ok, context_binding} =
             InstallationBinding.new(%{
               binding_key: "workspace_memory",
               binding_kind: :context,
               descriptor: descriptor,
               config: %{
                 "adapter_key" => "mem0_context",
                 "config" => %{"workspace" => "default"},
                 "timeout_ms" => 500
               },
               credential_ref: "cred-memory-1"
             })

    assert {:ok, install_result} =
             InstallResult.new(%{
               installation_ref: %{id: "inst-1", pack_slug: "expense_approval"},
               status: :created,
               message: "installed"
             })

    assert install_template.template_key == "expense/default"
    assert installation_binding.binding_kind == :execution
    assert %BindingEnvelope{runbook_ref: "runbooks/memory_context"} = descriptor.envelope
    assert %BindingFailurePosture{on_timeout: :proceed_without} = descriptor.failure
    assert %BindingOwnership{external_system_ref: "mem0.primary"} = descriptor.ownership
    assert context_binding.binding_kind == :context
    assert context_binding.descriptor.attachment == "outer_brain.context_adapter"
    assert %InstallationRef{id: "inst-1"} = install_result.installation_ref
  end

  test "builds leased read and stream attach envelopes" do
    assert {:ok, read_lease} =
             ReadLease.new(%{
               lease_ref: %{
                 id: "lease-read-1",
                 allowed_family: "unified_trace",
                 execution_ref: %{id: "exec-1"}
               },
               trace_id: "0123456789abcdef0123456789abcdef",
               expires_at: ~U[2026-04-18 12:10:00Z],
               lease_token: "read-token",
               allowed_operations: ["fetch_run", "events"],
               scope: %{"include_lower" => true},
               lineage_anchor: %{"submission_ref" => "sub-1"},
               invalidation_cursor: 9,
               invalidation_channel: "read:unified_trace"
             })

    assert %ReadLeaseRef{id: "lease-read-1", allowed_family: "unified_trace"} =
             read_lease.lease_ref

    assert {:ok, stream_attach_lease} =
             StreamAttachLease.new(%{
               lease_ref: %{
                 id: "lease-stream-1",
                 allowed_family: "runtime_stream",
                 execution_ref: %{id: "exec-1"}
               },
               trace_id: "0123456789abcdef0123456789abcdef",
               expires_at: ~U[2026-04-18 12:10:00Z],
               attach_token: "stream-token",
               scope: %{"transport" => "sse"},
               lineage_anchor: %{"submission_ref" => "sub-1"},
               reconnect_cursor: 9,
               invalidation_channel: "stream:runtime_stream",
               poll_interval_ms: 2_000
             })

    assert %StreamAttachLeaseRef{id: "lease-stream-1", allowed_family: "runtime_stream"} =
             stream_attach_lease.lease_ref
  end

  test "exposes the frozen backend contracts" do
    assert {:start_run, 3} in WorkBackend.behaviour_info(:callbacks)
    assert {:retry_run, 3} in WorkBackend.behaviour_info(:callbacks)
    assert {:cancel_run, 3} in WorkBackend.behaviour_info(:callbacks)

    assert {:subject_status, 3} in OperatorBackend.behaviour_info(:callbacks)
    assert {:timeline, 3} in OperatorBackend.behaviour_info(:callbacks)
    assert {:get_unified_trace, 3} in OperatorBackend.behaviour_info(:callbacks)
    assert {:issue_read_lease, 3} in OperatorBackend.behaviour_info(:callbacks)
    assert {:issue_stream_attach_lease, 3} in OperatorBackend.behaviour_info(:callbacks)
    assert {:available_actions, 3} in OperatorBackend.behaviour_info(:callbacks)
    assert {:apply_action, 4} in OperatorBackend.behaviour_info(:callbacks)

    assert {:ingest_subject, 3} in WorkQueryBackend.behaviour_info(:callbacks)
    assert {:list_subjects, 4} in WorkQueryBackend.behaviour_info(:callbacks)
    assert {:record_decision, 4} in ReviewBackend.behaviour_info(:callbacks)
    assert {:create_installation, 3} in InstallationBackend.behaviour_info(:callbacks)
    assert {:reactivate_installation, 3} in InstallationBackend.behaviour_info(:callbacks)
  end
end
