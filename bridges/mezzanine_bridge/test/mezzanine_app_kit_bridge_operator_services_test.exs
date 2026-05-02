defmodule Mezzanine.AppKitBridge.OperatorServicesTest do
  use ExUnit.Case, async: false

  alias AppKit.Bridges.MezzanineBridge

  alias AppKit.Core.{
    InstallationRef,
    OperatorActionRequest,
    RequestContext,
    RunRef,
    SubjectRef,
    TraceIdentity
  }

  alias Ecto.Adapters.SQL
  alias Ecto.Adapters.SQL.Sandbox
  alias Jido.Integration.V2.TenantScope

  alias Mezzanine.AppKitBridge.{
    OperatorActionService,
    OperatorProjectionAdapter,
    OperatorQueryService
  }

  alias Mezzanine.Archival.ArchivalManifest
  alias Mezzanine.Archival.BundleChecksum
  alias Mezzanine.Archival.FileSystemColdStore
  alias Mezzanine.Archival.Repo, as: ArchivalRepo
  alias Mezzanine.Audit.Repo, as: AuditRepo
  alias Mezzanine.Audit.WorkAudit
  alias Mezzanine.Control.ControlSession
  alias Mezzanine.DecisionCommands
  alias Mezzanine.Decisions.DecisionRecord
  alias Mezzanine.Decisions.Repo, as: DecisionsRepo
  alias Mezzanine.EvidenceLedger.Repo, as: EvidenceRepo
  alias Mezzanine.Execution.LifecycleContinuation
  alias Mezzanine.Execution.Repo, as: ExecutionRepo
  alias Mezzanine.Objects.Repo, as: ObjectsRepo
  alias Mezzanine.Objects.{SubjectPayloadSchema, SubjectRecord}
  alias Mezzanine.OpsDomain.Repo, as: OpsDomainRepo
  alias Mezzanine.Programs.{PolicyBundle, Program}
  alias Mezzanine.ReadLease
  alias Mezzanine.Review.ReviewUnit
  alias Mezzanine.Runs.{Run, RunArtifact, RunSeries}
  alias Mezzanine.Work.{WorkClass, WorkObject}

  @revision_epoch_fields %{
    installation_revision: 42,
    activation_epoch: 7,
    lease_epoch: 3
  }

  defmodule LowerFactsStub do
    def operation_supported?(operation),
      do: operation in [:fetch_run, :events, :attempts, :run_artifacts]

    def fetch_run(%TenantScope{} = scope, run_id) do
      send(self(), {:fetch_run, [scope.tenant_id, run_id]})

      {:ok,
       %{
         run_id: run_id,
         status: :running,
         occurred_at: ~U[2026-04-15 10:02:00Z]
       }}
    end

    def events(%TenantScope{} = scope, run_id) do
      send(self(), {:events, [scope.tenant_id, run_id]})

      [
        %{
          id: "lower-event-1",
          run_id: run_id,
          event_kind: "attempt.started",
          occurred_at: ~U[2026-04-15 10:03:00Z]
        }
      ]
    end

    def attempts(%TenantScope{} = scope, run_id) do
      send(self(), {:attempts, [scope.tenant_id, run_id]})

      [
        %{
          attempt_id: "attempt-1",
          run_id: run_id,
          status: :running,
          occurred_at: ~U[2026-04-15 10:04:00Z]
        }
      ]
    end

    def run_artifacts(%TenantScope{} = scope, run_id) do
      send(self(), {:run_artifacts, [scope.tenant_id, run_id]})

      [
        %{
          artifact_id: "artifact-1",
          run_id: run_id,
          kind: :log,
          occurred_at: ~U[2026-04-15 10:05:00Z]
        }
      ]
    end
  end

  defmodule DeadLetterContinuationDispatcher do
    @moduledoc false

    def dispatch_lifecycle_continuation(_continuation, _target),
      do: {:error, :invalid_transition}
  end

  setup do
    ops_domain_owner = Sandbox.start_owner!(OpsDomainRepo, shared: false)
    audit_owner = Sandbox.start_owner!(AuditRepo, shared: false)
    objects_owner = Sandbox.start_owner!(ObjectsRepo, shared: false)
    execution_owner = Sandbox.start_owner!(ExecutionRepo, shared: false)
    decisions_owner = Sandbox.start_owner!(DecisionsRepo, shared: false)
    evidence_owner = Sandbox.start_owner!(EvidenceRepo, shared: false)
    archival_owner = Sandbox.start_owner!(ArchivalRepo, shared: false)

    on_exit(fn ->
      Sandbox.stop_owner(archival_owner)
      Sandbox.stop_owner(evidence_owner)
      Sandbox.stop_owner(decisions_owner)
      Sandbox.stop_owner(execution_owner)
      Sandbox.stop_owner(objects_owner)
      Sandbox.stop_owner(audit_owner)
      Sandbox.stop_owner(ops_domain_owner)
    end)

    :ok
  end

  test "operator query service exposes subject status, timeline, alerts, reviews, and health without the deprecated operator surface" do
    %{tenant_id: tenant_id, program: program, work_object: work_object} =
      fixture_stack("tenant-operator-services")

    %{execution: execution} =
      seed_trace_ledger(tenant_id, work_object.id, "operator-services-status")

    assert {:ok, status} = OperatorQueryService.subject_status(tenant_id, work_object.id)
    assert status.subject_ref.id == work_object.id
    assert status.subject_ref.subject_kind == "work_object"
    assert status.current_execution_ref.id == execution.id
    assert Enum.any?(status.available_actions, &(&1.action_kind == "pause"))

    assert [%{obligation_id: obligation_id, decision_ref_id: decision_ref_id}] =
             status.payload.pending_obligations

    assert String.starts_with?(obligation_id, "obligation:review:")
    assert is_binary(decision_ref_id)
    assert [%{blocker_kind: "review_pending"}] = status.payload.blocking_conditions
    assert status.payload.next_step_preview.step_kind == "record_review_decision"
    assert status.payload.next_step_preview.status == "blocked"

    assert {:ok, timeline} = OperatorQueryService.timeline(tenant_id, work_object.id)
    assert timeline.subject_ref.id == work_object.id
    assert Enum.any?(timeline.entries, &(&1.event_kind == "run_scheduled"))

    assert {:ok, alerts} = OperatorQueryService.list_operator_alerts(tenant_id, program.id)
    assert Enum.any?(alerts, &(&1.subject_ref.id == work_object.id))

    assert {:ok, pending_reviews} =
             OperatorQueryService.list_pending_reviews(tenant_id, program.id)

    assert Enum.any?(pending_reviews, &(&1.subject_ref.id == work_object.id))

    assert {:ok, health} = OperatorQueryService.system_health(tenant_id, program.id)
    assert health.program_id == program.id
    assert health.active_run_count >= 1
    assert health.pending_review_count >= 1
  end

  test "operator timeline self-heals when an empty projection was materialized before later audit events" do
    %{tenant_id: tenant_id, work_object: work_object, run: run, program: program} =
      fixture_stack("tenant-operator-timeline-staleness", seed_run_event?: false)

    assert {:ok, status_before_event} =
             OperatorQueryService.subject_status(tenant_id, work_object.id)

    assert status_before_event.payload.timeline == []

    assert {:ok, _audit} =
             WorkAudit.record_event(tenant_id, %{
               program_id: program.id,
               work_object_id: work_object.id,
               run_id: run.id,
               event_kind: :run_scheduled,
               actor_kind: :system,
               actor_ref: "planner",
               payload: %{"attempt" => 1},
               occurred_at: ~U[2026-04-15 09:59:00Z]
             })

    assert {:ok, timeline} = OperatorQueryService.timeline(tenant_id, work_object.id)
    assert Enum.any?(timeline.entries, &(&1.event_kind == "run_scheduled"))

    assert {:ok, status_after_event} =
             OperatorQueryService.subject_status(tenant_id, work_object.id)

    assert Enum.any?(status_after_event.payload.timeline, &(&1.event_kind == "run_scheduled"))
  end

  test "operator action service applies control actions and preserves review decision coverage" do
    %{
      tenant_id: tenant_id,
      program: program,
      work_object: work_object,
      review_unit: review_unit
    } = fixture_stack("tenant-operator-actions")

    assert {:ok, pause_result} =
             OperatorActionService.apply_action(
               tenant_id,
               work_object.id,
               :pause,
               %{"reason" => "needs inspection"},
               %{actor_ref: "ops_lead"}
             )

    assert pause_result.status == :completed
    assert pause_result.action_ref.action_kind == "pause"
    assert pause_result.metadata.control_session.current_mode == :paused

    assert {:ok, resume_result} =
             OperatorActionService.apply_action(
               tenant_id,
               work_object.id,
               :resume,
               %{"reason" => "inspection complete"},
               %{actor_ref: "ops_lead"}
             )

    assert resume_result.status == :completed
    assert resume_result.action_ref.action_kind == "resume"
    assert resume_result.metadata.control_session.current_mode == :normal

    assert {:ok, override_result} =
             OperatorActionService.apply_action(
               tenant_id,
               work_object.id,
               :grant_override,
               %{grant_overrides: %{:"linear.issue.update" => :allow}},
               %{actor_ref: "ops_lead"}
             )

    assert override_result.action_ref.action_kind == "grant_override"

    assert override_result.metadata.control_session.active_override_set["linear.issue.update"] ==
             "allow"

    run_ref = %RunRef{
      run_id: "run/operator-review",
      scope_id: "program/#{program.id}",
      metadata: %{
        tenant_id: tenant_id,
        program_id: program.id,
        work_object_id: work_object.id,
        review_unit_id: review_unit.id
      }
    }

    assert {:ok, %{decision: decision, review_unit: updated_review_unit}} =
             OperatorProjectionAdapter.review_run(
               run_ref,
               %{
                 kind: :review_summary,
                 summary: "Ready to proceed",
                 details: %{"checklist" => ["tests", "credo", "dialyzer"]}
               },
               reason: "approved by operator"
             )

    assert decision.state == :approved
    assert updated_review_unit.status == :accepted

    %{tenant_id: cancel_tenant_id, work_object: cancel_work_object} =
      fixture_stack("tenant-operator-cancel")

    assert {:ok, cancel_result} =
             OperatorActionService.apply_action(
               cancel_tenant_id,
               cancel_work_object.id,
               :cancel,
               %{"reason" => "operator stopped the task"},
               %{actor_ref: "ops_lead"}
             )

    assert cancel_result.status == :completed
    assert cancel_result.action_ref.action_kind == "cancel"
    assert cancel_result.metadata.work_object.status == :cancelled
  end

  test "operator action service resolves accept and rework through DecisionCommands with tenant authority" do
    %{tenant_id: tenant_id, work_object: accept_work_object} =
      fixture_stack("tenant-operator-decision-accept")

    %{decision_id: accept_decision_id} =
      seed_trace_ledger(tenant_id, accept_work_object.id, "operator-decision-accept")

    assert {:ok, accept_result} =
             OperatorActionService.apply_action(
               tenant_id,
               accept_work_object.id,
               :accept,
               %{
                 "decision_id" => accept_decision_id,
                 "operator_context" =>
                   operator_command_context(
                     tenant_id,
                     tenant_id,
                     "trace-operator-accept",
                     "cause-operator-accept",
                     "idem-operator-accept"
                   )
               },
               %{actor_ref: "ops_lead"}
             )

    assert accept_result.action_ref.action_kind == "accept"
    assert accept_result.metadata.decision_value == "accept"
    assert accept_result.metadata.authority.tenant_id == tenant_id

    assert {:ok, accepted_decision} =
             DecisionCommands.fetch_by_identity(%{
               installation_id: tenant_id,
               subject_id: accept_work_object.id,
               execution_id: accept_result.metadata.decision.execution_id,
               decision_kind: "human_review_required"
             })

    assert accepted_decision.lifecycle_state == "resolved"

    %{tenant_id: rework_tenant_id, work_object: rework_work_object} =
      fixture_stack("tenant-operator-decision-rework")

    %{decision_id: rework_decision_id} =
      seed_trace_ledger(rework_tenant_id, rework_work_object.id, "operator-decision-rework")

    assert {:ok, rework_result} =
             OperatorActionService.apply_action(
               rework_tenant_id,
               rework_work_object.id,
               :rework,
               %{
                 "decision_id" => rework_decision_id,
                 "reason" => "needs another pass",
                 "operator_context" =>
                   operator_command_context(
                     rework_tenant_id,
                     rework_tenant_id,
                     "trace-operator-rework",
                     "cause-operator-rework",
                     "idem-operator-rework"
                   )
               },
               %{actor_ref: "ops_lead"}
             )

    assert rework_result.action_ref.action_kind == "rework"
    assert rework_result.metadata.decision_value == "rework"

    assert {:error, :cross_tenant_operator_command_denied} =
             OperatorActionService.apply_action(
               "tenant-wrong",
               rework_work_object.id,
               :accept,
               %{
                 "decision_id" => rework_decision_id,
                 "operator_context" =>
                   operator_command_context(
                     "tenant-wrong",
                     "installation-wrong",
                     "trace-operator-denied",
                     "cause-operator-denied",
                     "idem-operator-denied"
                   )
               },
               %{actor_ref: "ops_lead"}
             )

    assert {:ok, current_decision} =
             Ash.get(DecisionRecord, rework_decision_id,
               authorize?: false,
               domain: Mezzanine.Decisions
             )

    assert current_decision.decision_value == "rework"
  end

  test "app-kit operator surface rejects wrong-tenant cancel and refresh before subject effects" do
    assert {:ok, subject} = ingest_subject_record("tenant-subject-command", "phase13")

    assert {:ok, subject_ref} =
             SubjectRef.new(%{
               id: subject.id,
               subject_kind: "coding_task",
               installation_ref: installation_ref("tenant-subject-command")
             })

    wrong_context =
      request_context(
        "tenant-other",
        "tenant-subject-command",
        "trace-subject-cancel-denied",
        "cause-subject-cancel-denied",
        "idem-subject-cancel-denied"
      )

    assert {:ok, cancel_request} =
             OperatorActionRequest.new(%{
               action_ref: %{
                 id: "#{subject.id}:cancel",
                 action_kind: "cancel",
                 subject_ref: subject_ref
               },
               reason: "wrong tenant"
             })

    assert {:error, cancel_error} =
             MezzanineBridge.apply_action(wrong_context, subject_ref, cancel_request, [])

    assert cancel_error.code == "cross_tenant_operator_command_denied"
    assert cancel_error.kind == :authorization
    assert {:ok, still_active} = Ash.get(SubjectRecord, subject.id)
    assert still_active.status == "active"

    assert {:ok, refresh_request} =
             OperatorActionRequest.new(%{
               action_ref: %{
                 id: "#{subject.id}:refresh",
                 action_kind: "refresh",
                 subject_ref: subject_ref
               },
               reason: "wrong tenant"
             })

    assert {:error, refresh_error} =
             MezzanineBridge.apply_action(wrong_context, subject_ref, refresh_request, [])

    assert refresh_error.code == "cross_tenant_operator_command_denied"
    assert refresh_error.kind == :authorization

    valid_context =
      request_context(
        "tenant-subject-command",
        "tenant-subject-command",
        "trace-subject-refresh",
        "cause-subject-refresh",
        "idem-subject-refresh"
      )

    assert {:ok, refresh_result} =
             MezzanineBridge.apply_action(valid_context, subject_ref, refresh_request, [])

    assert refresh_result.action_ref.action_kind == "refresh"
    assert refresh_result.metadata.refresh_requested?
    assert refresh_result.metadata.lower_effect_started? == false
    assert refresh_result.metadata.reconcile_started? == false
  end

  test "operator services expose and retry lifecycle continuation dead letters" do
    %{tenant_id: tenant_id, work_object: work_object} =
      fixture_stack("tenant-operator-continuations")

    {:ok, continuation} =
      LifecycleContinuation.enqueue(%{
        continuation_id: "continuation-operator-1",
        tenant_id: tenant_id,
        installation_id: tenant_id,
        subject_id: work_object.id,
        execution_id: Ecto.UUID.generate(),
        from_state: "processing",
        target_transition: "execution_completed:expense_capture",
        next_attempt_at: ~U[2026-04-18 19:00:00Z],
        trace_id: "trace-continuation-operator",
        metadata: %{
          "continuation_target" => %{
            "kind" => "owner_command",
            "owner" => "operator_services_test",
            "command" => "record_dead_letter",
            "idempotency_key" => "continuation-operator-1"
          }
        },
        status: :pending
      })

    {:ok, dead_lettered} =
      LifecycleContinuation.process(continuation.continuation_id,
        now: ~U[2026-04-18 19:01:00Z],
        dispatcher: DeadLetterContinuationDispatcher
      )

    assert dead_lettered.status == :dead_lettered

    assert {:ok, status} = OperatorQueryService.subject_status(tenant_id, work_object.id)
    assert [operator_continuation] = status.payload.lifecycle_continuations
    assert operator_continuation.continuation_id == continuation.continuation_id
    assert operator_continuation.status == :dead_lettered
    assert operator_continuation.last_error_class == "invalid_transition"

    assert {:ok, retry_result} =
             OperatorActionService.apply_action(
               tenant_id,
               work_object.id,
               :retry_continuation,
               %{continuation_id: continuation.continuation_id},
               %{actor_ref: "ops_lead"}
             )

    assert retry_result.action_ref.action_kind == "retry_continuation"
    assert retry_result.metadata.status == :pending
    assert retry_result.metadata.continuation_id == continuation.continuation_id
  end

  test "operator query service assembles unified trace through the substrate contract and lower read bridge" do
    %{tenant_id: tenant_id, work_object: work_object} =
      fixture_stack("tenant-operator-unified-trace")

    %{execution: execution, trace_id: trace_id} =
      seed_trace_ledger(tenant_id, work_object.id, "operator-services")

    assert {:ok, trace} =
             OperatorQueryService.get_unified_trace(
               %{
                 tenant_id: tenant_id,
                 actor_id: "ops_lead",
                 installation_id: tenant_id,
                 execution_id: execution.id,
                 trace_id: trace_id
               }
               |> Map.merge(@revision_epoch_fields),
               lower_facts: LowerFactsStub
             )

    assert trace.trace_id == trace_id
    assert trace.installation_id == tenant_id

    assert trace.join_keys == %{
             "trace_id" => trace_id,
             "installation_id" => tenant_id,
             "execution_id" => execution.id
           }

    assert trace.metadata.indexed_join_keys == ["trace_id", "causation_id"]
    assert Enum.any?(trace.steps, &(&1.source == :audit_fact))
    assert Enum.any?(trace.steps, &(&1.source == :execution_record))
    assert Enum.any?(trace.steps, &(&1.source == :decision_record))
    assert Enum.any?(trace.steps, &(&1.source == :evidence_record))

    lower_step = Enum.find(trace.steps, &(&1.source == :lower_run_status))
    assert lower_step.staleness_class == :lower_fresh
    refute lower_step.operator_actionable?

    [read_lease] = ExecutionRepo.all(ReadLease)
    assert read_lease.execution_id == execution.id
    assert read_lease.allowed_family == "unified_trace"
    assert read_lease.installation_revision == 42
    assert read_lease.activation_epoch == 7
    assert read_lease.lease_epoch == 3

    assert Enum.sort(read_lease.allowed_operations) == [
             "attempts",
             "events",
             "fetch_run",
             "run_artifacts"
           ]

    assert_received {:fetch_run, [^tenant_id, "lower-run-operator-services"]}
    assert_received {:events, [^tenant_id, "lower-run-operator-services"]}
    assert_received {:attempts, [^tenant_id, "lower-run-operator-services"]}
    assert_received {:run_artifacts, [^tenant_id, "lower-run-operator-services"]}
    refute_received {:fetch_submission_receipt, _args}
  end

  test "operator query service returns explicit auth denial for unauthorized lower-enriched trace reads" do
    %{tenant_id: tenant_id, work_object: work_object} =
      fixture_stack("tenant-operator-unified-trace-denied")

    %{execution: execution, trace_id: trace_id} =
      seed_trace_ledger(tenant_id, work_object.id, "operator-services-denied")

    assert {:error, :unauthorized_lower_read} =
             OperatorQueryService.get_unified_trace(
               %{
                 tenant_id: tenant_id,
                 actor_id: "ops_lead",
                 installation_id: "inst-other",
                 execution_id: execution.id,
                 trace_id: trace_id
               }
               |> Map.merge(@revision_epoch_fields),
               lower_facts: LowerFactsStub
             )
  end

  test "operator query service reconstructs archived unified trace by trace_id after hot rows are removed" do
    %{tenant_id: tenant_id, work_object: work_object} =
      fixture_stack("tenant-operator-archived-trace")

    %{
      execution: execution,
      trace_id: trace_id,
      decision_id: decision_id,
      evidence_id: evidence_id,
      audit_fact_id: audit_fact_id
    } = seed_trace_ledger(tenant_id, work_object.id, "operator-services-archived")

    manifest_ref =
      archive_trace_ledger!(
        tenant_id,
        work_object.id,
        execution.id,
        decision_id,
        evidence_id,
        audit_fact_id,
        trace_id,
        "operator-services-archived"
      )

    assert {:error, :archived, ^manifest_ref} =
             OperatorQueryService.subject_status(tenant_id, work_object.id)

    assert {:ok, lineage} = OperatorQueryService.execution_trace_lineage(execution.id)
    assert lineage.execution_id == execution.id
    assert lineage.installation_id == tenant_id
    assert lineage.trace_id == trace_id

    assert {:ok, trace} =
             OperatorQueryService.get_unified_trace(
               %{
                 tenant_id: tenant_id,
                 actor_id: "ops_lead",
                 installation_id: tenant_id,
                 execution_id: execution.id,
                 trace_id: trace_id
               },
               lower_facts: LowerFactsStub
             )

    assert trace.trace_id == trace_id
    assert trace.metadata.archived_manifest_ref == manifest_ref
    assert Enum.any?(trace.steps, &(&1.source == :audit_fact))
    assert Enum.any?(trace.steps, &(&1.source == :execution_record))
    assert Enum.any?(trace.steps, &(&1.source == :decision_record))
    assert Enum.any?(trace.steps, &(&1.source == :evidence_record))
    assert Enum.all?(trace.steps, &(&1.staleness_class == :authoritative_archived))
    refute Enum.any?(trace.steps, &(&1.source == :lower_run_status))
    refute_received {:fetch_run, _args}

    for {pivot, pivot_id} <- [
          subject_id: work_object.id,
          execution_id: execution.id,
          decision_id: decision_id,
          run_id: "lower-run-operator-services-archived",
          attempt_id: "attempt-operator-services-archived",
          artifact_id: "artifact-operator-services-archived",
          manifest_ref: manifest_ref
        ] do
      assert {:ok, pivot_trace} =
               OperatorQueryService.get_archived_unified_trace_by_pivot(%{
                 installation_id: tenant_id,
                 pivot: pivot,
                 pivot_id: pivot_id
               })

      assert pivot_trace.trace_id == trace_id
      assert pivot_trace.metadata.archived_manifest_ref == manifest_ref
      assert pivot_trace.metadata.archive_pivot == Atom.to_string(pivot)
      assert Enum.all?(pivot_trace.steps, &(&1.staleness_class == :authoritative_archived))
    end
  end

  test "operator services archive paths use disposable temp storage outside the bridge package" do
    cold_store = Application.fetch_env!(:mezzanine_archival_engine, :cold_store)
    configured_root = Keyword.fetch!(cold_store, :root)
    archive_root = operator_services_archive_root()
    bridge_root = Path.expand("..", __DIR__)

    refute path_inside?(configured_root, bridge_root)
    assert path_inside?(configured_root, System.tmp_dir!())
    refute path_inside?(archive_root, bridge_root)
    assert path_inside?(archive_root, System.tmp_dir!())
  end

  defp fixture_stack(tenant_id, opts \\ []) do
    actor = %{tenant_id: tenant_id}

    {:ok, program} =
      Program.create_program(
        %{
          slug: "operator-services-#{System.unique_integer([:positive])}",
          name: "Operator Services Program",
          product_family: "operator_stack",
          configuration: %{},
          metadata: %{}
        },
        actor: actor,
        tenant: tenant_id
      )

    {:ok, bundle} =
      PolicyBundle.load_bundle(
        %{
          program_id: program.id,
          name: "default",
          version: "1.0.0",
          policy_kind: :workflow_md,
          source_ref: "WORKFLOW.md",
          body: workflow_body(),
          metadata: %{}
        },
        actor: actor,
        tenant: tenant_id
      )

    {:ok, work_class} =
      WorkClass.create_work_class(
        %{
          program_id: program.id,
          name: "coding_task_#{System.unique_integer([:positive])}",
          kind: "coding_task",
          intake_schema: %{"required" => ["title"]},
          policy_bundle_id: bundle.id,
          default_review_profile: %{"required" => true},
          default_run_profile: %{"runtime" => "session"}
        },
        actor: actor,
        tenant: tenant_id
      )

    {:ok, work_object} =
      WorkObject.ingest(
        %{
          program_id: program.id,
          work_class_id: work_class.id,
          external_ref: "linear:ENG-#{System.unique_integer([:positive])}",
          title: "Operator work",
          description: "Exercise operator services",
          priority: 50,
          source_kind: "linear",
          payload: %{"issue_id" => "ENG-1"},
          normalized_payload: %{"issue_id" => "ENG-1"}
        },
        actor: actor,
        tenant: tenant_id
      )

    {:ok, work_object} =
      WorkObject.compile_plan(work_object, %{}, actor: actor, tenant: tenant_id)

    {:ok, control_session} =
      ControlSession.open(
        %{program_id: program.id, work_object_id: work_object.id},
        actor: actor,
        tenant: tenant_id
      )

    {:ok, run_series} =
      RunSeries.open_series(
        %{work_object_id: work_object.id, control_session_id: control_session.id},
        actor: actor,
        tenant: tenant_id
      )

    {:ok, run} =
      Run.schedule(
        %{
          run_series_id: run_series.id,
          attempt: 1,
          runtime_profile: %{"runtime" => "session"},
          grant_profile: %{"linear.issue.update" => "allow"}
        },
        actor: actor,
        tenant: tenant_id
      )

    {:ok, _run_series} =
      RunSeries.attach_current_run(run_series, %{current_run_id: run.id},
        actor: actor,
        tenant: tenant_id
      )

    {:ok, _run_artifact} =
      RunArtifact.record_artifact(
        %{run_id: run.id, kind: :pr, ref: "https://github.com/example/pr/1", metadata: %{}},
        actor: actor,
        tenant: tenant_id
      )

    {:ok, review_unit} =
      ReviewUnit.create_review_unit(
        %{
          work_object_id: work_object.id,
          run_id: run.id,
          review_kind: :operator_review,
          required_by: DateTime.utc_now(),
          decision_profile: %{"required_decisions" => 1},
          reviewer_actor: %{"kind" => "human", "ref" => "ops_lead"}
        },
        actor: actor,
        tenant: tenant_id
      )

    if Keyword.get(opts, :seed_run_event?, true) do
      {:ok, _audit} =
        WorkAudit.record_event(tenant_id, %{
          program_id: program.id,
          work_object_id: work_object.id,
          run_id: run.id,
          event_kind: :run_scheduled,
          actor_kind: :system,
          actor_ref: "planner",
          payload: %{"attempt" => 1},
          occurred_at: ~U[2026-04-15 09:59:00Z]
        })
    end

    %{
      tenant_id: tenant_id,
      actor: actor,
      program: program,
      bundle: bundle,
      work_class: work_class,
      work_object: work_object,
      review_unit: review_unit,
      run: run
    }
  end

  defp seed_trace_ledger(installation_id, subject_id, suffix) do
    execution_id = Ecto.UUID.generate()
    decision_id = Ecto.UUID.generate()
    evidence_id = Ecto.UUID.generate()
    audit_fact_id = Ecto.UUID.generate()
    trace_id = TraceIdentity.mint()
    now = ~U[2026-04-15 10:00:00Z]

    assert {1, _} =
             ExecutionRepo.insert_all("execution_records", [
               %{
                 id: dump_uuid!(execution_id),
                 tenant_id: installation_id,
                 installation_id: installation_id,
                 subject_id: dump_uuid!(subject_id),
                 recipe_ref: "triage_ticket",
                 trace_id: trace_id,
                 causation_id: "cause-#{suffix}",
                 dispatch_state: "accepted_active",
                 dispatch_attempt_count: 0,
                 next_dispatch_at: now,
                 submission_ref: %{"id" => "submission-#{suffix}"},
                 lower_receipt: %{"run_id" => "lower-run-#{suffix}"},
                 last_dispatch_error_payload: %{},
                 row_version: 1,
                 inserted_at: now,
                 updated_at: now,
                 compiled_pack_revision: 7,
                 binding_snapshot: %{"placement_ref" => "local-session"}
               }
             ])

    assert {1, _} =
             AuditRepo.insert_all("audit_facts", [
               %{
                 id: dump_uuid!(audit_fact_id),
                 installation_id: installation_id,
                 subject_id: subject_id,
                 execution_id: execution_id,
                 trace_id: trace_id,
                 causation_id: "cause-#{suffix}",
                 fact_kind: "execution_dispatched",
                 actor_ref: %{kind: :scheduler},
                 payload: %{dispatch_state: "accepted_active"},
                 occurred_at: now,
                 inserted_at: now,
                 updated_at: now
               }
             ])

    assert {1, _} =
             AuditRepo.insert_all("execution_lineage_records", [
               %{
                 id: dump_uuid!(Ecto.UUID.generate()),
                 trace_id: trace_id,
                 causation_id: "cause-#{suffix}",
                 tenant_id: installation_id,
                 installation_id: installation_id,
                 subject_id: subject_id,
                 execution_id: execution_id,
                 ji_submission_key: "submission-#{suffix}",
                 lower_run_id: "lower-run-#{suffix}",
                 lower_attempt_id: "attempt-#{suffix}",
                 artifact_refs: ["artifact-1"],
                 inserted_at: now,
                 updated_at: now
               }
             ])

    assert {1, _} =
             DecisionsRepo.insert_all("decision_records", [
               %{
                 id: dump_uuid!(decision_id),
                 installation_id: installation_id,
                 subject_id: dump_uuid!(subject_id),
                 execution_id: dump_uuid!(execution_id),
                 decision_kind: "human_review_required",
                 lifecycle_state: "pending",
                 required_by: ~U[2026-04-20 00:00:00Z],
                 trace_id: trace_id,
                 causation_id: execution_id,
                 row_version: 1,
                 inserted_at: ~U[2026-04-15 10:01:00Z],
                 updated_at: ~U[2026-04-15 10:01:00Z]
               }
             ])

    assert {1, _} =
             EvidenceRepo.insert_all("evidence_records", [
               %{
                 id: dump_uuid!(evidence_id),
                 installation_id: installation_id,
                 subject_id: dump_uuid!(subject_id),
                 execution_id: dump_uuid!(execution_id),
                 evidence_kind: "run_log",
                 collector_ref: "jido_run_output",
                 content_ref: "artifact://#{suffix}",
                 status: "collected",
                 metadata: %{"size" => 128},
                 collected_at: ~U[2026-04-15 10:02:00Z],
                 trace_id: trace_id,
                 causation_id: execution_id,
                 row_version: 1,
                 inserted_at: ~U[2026-04-15 10:02:00Z],
                 updated_at: ~U[2026-04-15 10:02:00Z]
               }
             ])

    %{
      execution: %{id: execution_id},
      trace_id: trace_id,
      decision_id: decision_id,
      evidence_id: evidence_id,
      audit_fact_id: audit_fact_id
    }
  end

  defp ingest_subject_record(installation_id, suffix) do
    SubjectRecord.ingest(%{
      installation_id: installation_id,
      source_ref: "linear://#{installation_id}/issue/#{suffix}",
      source_binding_id: "linear-primary",
      subject_kind: "linear_coding_ticket",
      lifecycle_state: "queued",
      schema_ref: SubjectPayloadSchema.default_schema_ref!("linear_coding_ticket"),
      schema_version: SubjectPayloadSchema.default_schema_version!("linear_coding_ticket"),
      payload: %{},
      trace_id: "trace-ingest-#{suffix}",
      causation_id: "cause-ingest-#{suffix}",
      actor_ref: %{kind: :source_ingest, tenant_id: installation_id}
    })
  end

  defp request_context(tenant_id, installation_id, _trace_id, causation_id, idempotency_key) do
    {:ok, context} =
      RequestContext.new(%{
        trace_id: TraceIdentity.mint(),
        causation_id: causation_id,
        idempotency_key: idempotency_key,
        actor_ref: %{id: "ops_lead", kind: "operator"},
        tenant_ref: %{id: tenant_id},
        installation_ref: installation_ref(installation_id)
      })

    context
  end

  defp installation_ref(installation_id) do
    {:ok, installation_ref} =
      InstallationRef.new(%{
        id: installation_id,
        pack_slug: "coding_ops",
        status: :active
      })

    installation_ref
  end

  defp operator_command_context(
         tenant_id,
         installation_id,
         trace_id,
         causation_id,
         idempotency_key
       ) do
    %{
      "tenant_id" => tenant_id,
      "installation_id" => installation_id,
      "trace_id" => trace_id,
      "causation_id" => causation_id,
      "idempotency_key" => idempotency_key,
      "actor_ref" => %{
        "kind" => "operator",
        "id" => "ops_lead",
        "tenant_id" => tenant_id
      }
    }
  end

  defp archive_trace_ledger!(
         installation_id,
         subject_id,
         execution_id,
         decision_id,
         evidence_id,
         audit_fact_id,
         trace_id,
         suffix
       ) do
    terminal_at = ~U[2026-04-16 12:00:00Z]

    manifest_ref =
      "archive/#{installation_id}/#{subject_id}/#{System.unique_integer([:positive])}"

    archive_root = operator_services_archive_root()

    bundle = %{
      "manifest_ref" => manifest_ref,
      "subject" => %{"id" => subject_id},
      "trace_views" => %{
        trace_id => %{
          "audit_facts" => [
            %{
              "id" => audit_fact_id,
              "trace_id" => trace_id,
              "causation_id" => "cause-#{suffix}",
              "occurred_at" => "2026-04-15T10:00:00Z",
              "fact_kind" => "execution_dispatched",
              "actor_ref" => %{"kind" => "scheduler"},
              "payload" => %{"dispatch_state" => "accepted_active"}
            }
          ],
          "executions" => [
            %{
              "id" => execution_id,
              "trace_id" => trace_id,
              "causation_id" => "cause-#{suffix}",
              "subject_id" => subject_id,
              "dispatch_state" => "accepted_active",
              "recipe_ref" => "triage_ticket",
              "compiled_pack_revision" => 7,
              "lower_receipt" => %{
                "run_id" => "lower-run-#{suffix}",
                "attempt_id" => "attempt-#{suffix}",
                "artifact_ids" => ["artifact-#{suffix}"]
              },
              "barrier_id" => nil,
              "last_reconcile_wave_id" => nil,
              "supersedes_execution_id" => nil,
              "failure_kind" => nil,
              "terminal_rejection_reason" => nil,
              "inserted_at" => "2026-04-15T09:59:00Z",
              "updated_at" => "2026-04-15T10:00:00Z"
            }
          ],
          "decisions" => [
            %{
              "id" => decision_id,
              "trace_id" => trace_id,
              "causation_id" => execution_id,
              "subject_id" => subject_id,
              "execution_id" => execution_id,
              "decision_kind" => "human_review_required",
              "lifecycle_state" => "pending",
              "decision_value" => nil,
              "reason" => nil,
              "resolved_at" => "2026-04-15T10:01:00Z",
              "inserted_at" => "2026-04-15T10:00:30Z"
            }
          ],
          "evidence" => [
            %{
              "id" => evidence_id,
              "trace_id" => trace_id,
              "causation_id" => execution_id,
              "subject_id" => subject_id,
              "execution_id" => execution_id,
              "evidence_kind" => "run_log",
              "status" => "collected",
              "collector_ref" => "jido_run_output",
              "content_ref" => "artifact-#{suffix}",
              "metadata" => %{"size" => 128},
              "collected_at" => "2026-04-15T10:02:00Z",
              "inserted_at" => "2026-04-15T10:01:30Z"
            }
          ]
        }
      }
    }

    bundle = Map.put(bundle, "checksum", BundleChecksum.generate(bundle))

    {:ok, cold_result} =
      FileSystemColdStore.write_bundle(manifest_ref, bundle, root: archive_root)

    {:ok, manifest} =
      ArchivalManifest.stage(%{
        manifest_ref: manifest_ref,
        installation_id: installation_id,
        subject_id: subject_id,
        subject_state: "completed",
        execution_states: ["accepted_active"],
        trace_ids: [trace_id],
        execution_ids: [execution_id],
        decision_ids: [decision_id],
        evidence_ids: [evidence_id],
        audit_fact_ids: [audit_fact_id],
        projection_names: [],
        terminal_at: terminal_at,
        due_at: terminal_at,
        retention_seconds: 0,
        storage_kind: "filesystem",
        metadata: %{"test" => "operator_services_archived_trace"}
      })

    {:ok, verified} =
      ArchivalManifest.mark_verified(manifest, %{
        storage_uri: cold_result.storage_uri,
        checksum: cold_result.checksum,
        verified_at: terminal_at,
        metadata: %{
          "cold_store_checksum" => cold_result.checksum,
          "cold_store_uri" => cold_result.storage_uri
        }
      })

    {:ok, archived} = ArchivalManifest.mark_archived(verified, %{archived_at: terminal_at})

    SQL.query!(AuditRepo, "DELETE FROM audit_facts WHERE id = $1::uuid", [
      dump_uuid!(audit_fact_id)
    ])

    SQL.query!(EvidenceRepo, "DELETE FROM evidence_records WHERE id = $1::uuid", [
      dump_uuid!(evidence_id)
    ])

    SQL.query!(DecisionsRepo, "DELETE FROM decision_records WHERE id = $1::uuid", [
      dump_uuid!(decision_id)
    ])

    SQL.query!(ExecutionRepo, "DELETE FROM execution_records WHERE id = $1::uuid", [
      dump_uuid!(execution_id)
    ])

    archived.manifest_ref
  end

  defp operator_services_archive_root do
    root =
      Path.join([
        System.tmp_dir!(),
        "app_kit_mezzanine_bridge",
        "operator_services_archival",
        Integer.to_string(System.unique_integer([:positive]))
      ])

    File.rm_rf!(root)
    on_exit(fn -> File.rm_rf!(root) end)
    root
  end

  defp path_inside?(path, root) do
    expanded_path = path |> Path.expand() |> String.trim_trailing("/")
    expanded_root = root |> Path.expand() |> String.trim_trailing("/")

    expanded_path == expanded_root or String.starts_with?(expanded_path, expanded_root <> "/")
  end

  defp workflow_body do
    """
    ---
    tracker:
      kind: linear
      endpoint: https://api.linear.app/graphql
    run:
      profile: default_session
      runtime_class: session
      capability: linear.issue.execute
      target: linear-default
    approval:
      mode: manual
      reviewers:
        - ops_lead
      escalation_required: true
    retry:
      strategy: exponential
      max_attempts: 4
      initial_backoff_ms: 5000
      max_backoff_ms: 300000
    placement:
      profile_id: default-placement
      strategy: affinity
      target_selector:
        runtime_driver: jido_session
      runtime_preferences:
        locality: same_region
    workspace:
      root_mode: per_work
      sandbox_profile: strict
    review:
      required: true
      required_decisions: 1
      gates:
        - operator
    capability_grants:
      - capability_id: linear.issue.read
        mode: allow
      - capability_id: linear.issue.update
        mode: allow
    ---
    # Operator Prompt
    """
  end

  defp dump_uuid!(value), do: Ecto.UUID.dump!(value)
end
