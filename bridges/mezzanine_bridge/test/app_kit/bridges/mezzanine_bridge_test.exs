defmodule AppKit.Bridges.MezzanineBridgeTest do
  use ExUnit.Case, async: true

  defmodule FakeWorkQueryService do
    def ingest_subject(attrs, _opts) do
      {:ok,
       %{
         subject_id: "subj-1",
         subject_kind: :work_object,
         program_id: attrs.program_id,
         work_class_id: attrs.work_class_id,
         title: attrs.title || attrs.external_ref,
         description: "queued",
         status: :planned,
         inserted_at: DateTime.from_naive!(~N[2026-04-17 09:00:00], "Etc/UTC"),
         updated_at: DateTime.from_naive!(~N[2026-04-17 09:05:00], "Etc/UTC")
       }}
    end

    def list_subjects(_tenant_id, _program_id, _filters) do
      {:ok,
       [
         %{
           subject_id: "subj-1",
           subject_kind: :work_object,
           program_id: "program-1",
           work_class_id: "work-class-1",
           external_ref: "ENG-401",
           title: "A Item",
           description: "older",
           status: :planned,
           inserted_at: DateTime.from_naive!(~N[2026-04-17 09:00:00], "Etc/UTC"),
           updated_at: DateTime.from_naive!(~N[2026-04-17 09:05:00], "Etc/UTC")
         },
         %{
           subject_id: "subj-2",
           subject_kind: :work_object,
           program_id: "program-1",
           work_class_id: "work-class-1",
           external_ref: "ENG-402",
           title: "B Item",
           description: "newer",
           status: :running,
           inserted_at: DateTime.from_naive!(~N[2026-04-17 10:00:00], "Etc/UTC"),
           updated_at: DateTime.from_naive!(~N[2026-04-17 10:05:00], "Etc/UTC")
         }
       ]}
    end

    def get_subject_detail(_tenant_id, "subj-1") do
      {:ok,
       %{
         subject_id: "subj-1",
         subject_kind: :work_object,
         program_id: "program-1",
         work_class_id: "work-class-1",
         external_ref: "ENG-401",
         title: "A Item",
         description: "detail",
         status: :planned,
         active_run_id: "run-1",
         active_run_status: :accepted,
         pending_review_ids: ["dec-1"],
         gate_status: %{status: :pending},
         timeline: [%{event: "planned"}],
         audit_events: [%{event_kind: :work_planned}],
         run_series_ids: ["series-1"],
         obligation_ids: ["ob-1"],
         inserted_at: DateTime.from_naive!(~N[2026-04-17 09:00:00], "Etc/UTC"),
         updated_at: DateTime.from_naive!(~N[2026-04-17 09:05:00], "Etc/UTC")
       }}
    end

    def get_subject_detail(_tenant_id, _subject_id), do: {:error, :bridge_not_found}

    def get_subject_projection(_tenant_id, "subj-1") do
      {:ok, %{subject_id: "subj-1", work_status: :planned, review_status: :pending}}
    end

    def queue_stats(_tenant_id, _program_id) do
      {:ok, %{active_count: 2, running_count: 1}}
    end
  end

  defmodule FakeReviewQueryService do
    def list_pending_reviews(_tenant_id, _program_id) do
      {:ok,
       [
         %{
           decision_ref: %{
             id: "dec-1",
             decision_kind: "approval",
             subject_ref: %{id: "subj-1", subject_kind: "work_object"}
           },
           subject_ref: %{id: "subj-1", subject_kind: "work_object"},
           status: "pending",
           summary: "Needs approval"
         }
       ]}
    end

    def get_review_detail(_tenant_id, "dec-1"), do: {:ok, %{decision_ref: %{id: "dec-1"}}}
  end

  defmodule FakeReviewActionService do
    def record_decision(_tenant_id, "dec-1", _attrs, _opts) do
      {:ok,
       %{
         status: :completed,
         action_ref: %{
           id: "dec-1:accept",
           action_kind: "review_accept",
           subject_ref: %{id: "subj-1", subject_kind: "work_object"}
         },
         message: "Review accepted",
         metadata: %{backend: :fake}
       }}
    end
  end

  defmodule FakeInstallationService do
    def create_installation(attrs, _opts) do
      {:ok,
       %{
         installation_ref: %{
           id: "inst-1",
           pack_slug: attrs.pack_slug,
           pack_version: attrs.pack_version,
           compiled_pack_revision: 1,
           status: :active
         },
         status: :created,
         message: "Installation created",
         metadata: %{backend: :fake}
       }}
    end

    def get_installation("inst-1", _opts) do
      {:ok,
       %{
         installation_ref: %{
           id: "inst-1",
           pack_slug: "expense_approval",
           pack_version: "1.0.0",
           compiled_pack_revision: 1,
           status: :active
         },
         environment: "prod"
       }}
    end

    def list_installations(_tenant_id, _filters, _opts) do
      {:ok,
       [
         %{
           installation_ref: %{
             id: "inst-1",
             pack_slug: "expense_approval",
             pack_version: "1.0.0",
             compiled_pack_revision: 1,
             status: :active
           }
         }
       ]}
    end

    def update_bindings("inst-1", _binding_config, _opts) do
      {:ok,
       %{
         status: :completed,
         action_ref: %{id: "inst-1:update_bindings", action_kind: "update_bindings"},
         message: "Bindings updated",
         metadata: %{backend: :fake}
       }}
    end

    def suspend_installation("inst-1", _opts) do
      {:ok,
       %{
         status: :completed,
         action_ref: %{id: "inst-1:suspend_installation", action_kind: "suspend_installation"},
         message: "Installation suspended",
         metadata: %{backend: :fake}
       }}
    end

    def reactivate_installation("inst-1", _opts) do
      {:ok,
       %{
         status: :completed,
         action_ref: %{
           id: "inst-1:reactivate_installation",
           action_kind: "reactivate_installation"
         },
         message: "Installation reactivated",
         metadata: %{backend: :fake}
       }}
    end
  end

  defmodule FakeWorkControlService do
    alias AppKit.Core.{ActionResult, RequestContext, Result, RunRequest}

    def start_run(domain_call, _opts) do
      Result.new(%{
        surface: :work_control,
        state: :scheduled,
        payload: %{domain_call: domain_call, backend: :fake}
      })
    end

    def start_run(%RequestContext{} = context, %RunRequest{} = run_request, _opts) do
      Result.new(%{
        surface: :work_control,
        state: :scheduled,
        payload: %{
          backend: :fake,
          trace_id: context.trace_id,
          subject_id: run_request.subject_ref.id
        }
      })
    end

    def retry_run(_context, run_ref, _opts) do
      ActionResult.new(%{
        status: :accepted,
        action_ref: %{id: "#{run_ref.run_id}:retry", action_kind: "retry"},
        message: "retry queued"
      })
    end

    def cancel_run(_context, run_ref, _opts) do
      ActionResult.new(%{
        status: :completed,
        action_ref: %{id: "#{run_ref.run_id}:cancel", action_kind: "cancel"},
        message: "cancelled"
      })
    end
  end

  defmodule FakeOperatorQueryService do
    alias AppKit.Core.RunRef

    def run_status(%RunRef{} = run_ref, attrs, _opts) do
      {:ok, %{run_id: run_ref.run_id, attrs: attrs, backend: :fake}}
    end

    def subject_status(_tenant_id, "subj-1") do
      {:ok,
       %{
         subject_ref: %{id: "subj-1", subject_kind: "work_object"},
         lifecycle_state: "processing",
         current_execution_ref: %{id: "exec-1", dispatch_state: "accepted"},
         pending_decision_refs: [],
         updated_at: "2026-04-18T13:10:00Z",
         available_actions: [
           %{
             id: "subj-1:pause",
             action_kind: "pause",
             subject_ref: %{id: "subj-1", subject_kind: "work_object"}
           }
         ],
         payload: %{
           timeline: [
             %{
               ref: "evt-1",
               event_kind: "run_scheduled",
               occurred_at: ~U[2026-04-18 13:00:00Z],
               summary: "Run scheduled",
               actor_ref: "app_kit_bridge"
             }
           ]
         }
       }}
    end

    def timeline(_tenant_id, "subj-1") do
      {:ok,
       %{
         subject_ref: %{id: "subj-1", subject_kind: "work_object"},
         entries: [
           %{
             ref: "evt-1",
             event_kind: "run_scheduled",
             occurred_at: ~U[2026-04-18 13:00:00Z],
             summary: "Run scheduled",
             actor_ref: "app_kit_bridge"
           }
         ],
         last_event_at: ~U[2026-04-18 13:00:00Z]
       }}
    end

    def available_actions(_tenant_id, "subj-1") do
      {:ok,
       [
         %{
           id: "subj-1:cancel",
           action_kind: "cancel",
           subject_ref: %{id: "subj-1", subject_kind: "work_object"}
         }
       ]}
    end

    def get_unified_trace(_attrs, _opts) do
      {:ok,
       %{
         trace_id: "trace-mezzanine-bridge",
         installation_id: "inst-1",
         join_keys: %{"subject_id" => "subj-1"},
         steps: [
           %{
             ref: "step-1",
             source: :execution_record,
             occurred_at: ~U[2026-04-18 13:05:00Z],
             trace_id: "trace-mezzanine-bridge",
             freshness: :lower_authoritative_unreconciled,
             operator_actionable?: false,
             diagnostic?: false,
             payload: %{"dispatch_state" => "dispatching"}
           }
         ]
       }}
    end
  end

  defmodule FakeOperatorActionService do
    alias AppKit.Core.RunRef

    def review_run(%RunRef{} = run_ref, attrs, _opts) do
      {:ok, %{run_id: run_ref.run_id, attrs: attrs, backend: :fake}}
    end

    def apply_action(_tenant_id, "subj-1", "cancel", params, _actor) do
      {:ok,
       %{
         status: :completed,
         action_ref: %{
           id: "subj-1:cancel",
           action_kind: "cancel",
           subject_ref: %{id: "subj-1", subject_kind: "work_object"}
         },
         message: "Cancelled",
         metadata: %{params: params}
       }}
    end
  end

  alias AppKit.Bridges.MezzanineBridge

  alias AppKit.Core.{
    DecisionRef,
    FilterSet,
    InstallationBinding,
    InstallationRef,
    InstallTemplate,
    OperatorActionRequest,
    PageRequest,
    ProjectionRef,
    RequestContext,
    RunRef,
    RunRequest,
    SortSpec,
    SubjectRef
  }

  test "maps work-query services into app-kit contract types" do
    context = request_context()

    assert {:ok, created_ref} =
             MezzanineBridge.ingest_subject(
               context,
               %{external_ref: "ENG-401", title: "Created"},
               work_query_service: FakeWorkQueryService
             )

    assert created_ref.id == "subj-1"
    assert {:ok, sort_spec} = SortSpec.new(%{field: "title", direction: :desc})
    assert {:ok, filter_set} = FilterSet.new(%{clauses: []})

    assert {:ok, page_request} =
             PageRequest.new(%{limit: 1, sort: [sort_spec], filters: filter_set})

    assert {:ok, page_result} =
             MezzanineBridge.list_subjects(
               context,
               filter_set,
               page_request,
               work_query_service: FakeWorkQueryService
             )

    assert page_result.total_count == 2
    assert page_result.has_more == true
    assert hd(page_result.entries).subject_ref.id == "subj-2"

    assert {:ok, subject_ref} = SubjectRef.new(%{id: "subj-1", subject_kind: "work_object"})

    assert {:ok, detail} =
             MezzanineBridge.get_subject(
               context,
               subject_ref,
               work_query_service: FakeWorkQueryService
             )

    assert detail.current_execution_ref.id == "run-1"
    assert length(detail.pending_decision_refs) == 1

    assert {:ok, projection_ref} =
             ProjectionRef.new(%{name: "review_queue", subject_ref: subject_ref})

    assert {:ok, projection} =
             MezzanineBridge.get_projection(
               context,
               projection_ref,
               work_query_service: FakeWorkQueryService
             )

    assert projection.subject_id == "subj-1"

    assert {:ok, queue_stats} =
             MezzanineBridge.queue_stats(
               context,
               filter_set,
               work_query_service: FakeWorkQueryService
             )

    assert queue_stats.active_count == 2
  end

  test "maps review and installation services into app-kit contract types" do
    context = request_context()
    assert {:ok, page_request} = PageRequest.new(%{limit: 10})

    assert {:ok, review_page} =
             MezzanineBridge.list_pending(
               context,
               page_request,
               review_query_service: FakeReviewQueryService
             )

    assert hd(review_page.entries).decision_ref.id == "dec-1"

    assert {:ok, decision_ref} =
             DecisionRef.new(%{
               id: "dec-1",
               decision_kind: "approval",
               subject_ref: %{id: "subj-1", subject_kind: "work_object"}
             })

    assert {:ok, review_detail} =
             MezzanineBridge.get_review(
               context,
               decision_ref,
               review_query_service: FakeReviewQueryService
             )

    assert review_detail.decision_ref.id == "dec-1"

    assert {:ok, action_result} =
             MezzanineBridge.record_decision(
               context,
               decision_ref,
               %{decision: :accept},
               review_action_service: FakeReviewActionService
             )

    assert action_result.status == :completed

    assert {:ok, template} =
             InstallTemplate.new(%{
               template_key: "expense/default",
               pack_slug: "expense_approval",
               pack_version: "1.0.0"
             })

    assert {:ok, install_result} =
             MezzanineBridge.create_installation(
               context,
               template,
               installation_service: FakeInstallationService
             )

    assert install_result.installation_ref.id == "inst-1"

    assert {:ok, installation_ref} =
             InstallationRef.new(%{
               id: "inst-1",
               pack_slug: "expense_approval",
               status: :active
             })

    assert {:ok, fetched_ref} =
             MezzanineBridge.get_installation(
               context,
               installation_ref,
               installation_service: FakeInstallationService
             )

    assert fetched_ref.id == "inst-1"

    assert {:ok, binding} =
             InstallationBinding.new(%{
               binding_key: "expense_capture",
               binding_kind: :execution,
               config: %{"placement_ref" => "local_runner"}
             })

    assert {:ok, update_result} =
             MezzanineBridge.update_bindings(
               context,
               installation_ref,
               [binding],
               installation_service: FakeInstallationService
             )

    assert update_result.metadata.backend == :fake

    assert {:ok, list_result} =
             MezzanineBridge.list_installations(
               context,
               page_request,
               installation_service: FakeInstallationService
             )

    assert hd(list_result.entries).id == "inst-1"

    assert {:ok, suspend_result} =
             MezzanineBridge.suspend_installation(
               context,
               installation_ref,
               installation_service: FakeInstallationService
             )

    assert {:ok, reactivate_result} =
             MezzanineBridge.reactivate_installation(
               context,
               installation_ref,
               installation_service: FakeInstallationService
             )

    assert suspend_result.metadata.backend == :fake
    assert reactivate_result.metadata.backend == :fake
  end

  test "keeps legacy work-control and operator-backend compatibility" do
    assert {:ok, result} =
             MezzanineBridge.start_run(
               %{route_name: "compile.workspace"},
               work_control_service: FakeWorkControlService
             )

    assert result.payload.backend == :fake

    assert {:ok, run_ref} = RunRef.new(%{run_id: "run-1", scope_id: "scope-1"})

    assert {:ok, status_projection} =
             MezzanineBridge.run_status(
               run_ref,
               %{subject_id: "subj-1"},
               operator_query_service: FakeOperatorQueryService
             )

    assert {:ok, review_projection} =
             MezzanineBridge.review_run(
               run_ref,
               %{summary: "ok"},
               operator_action_service: FakeOperatorActionService
             )

    assert status_projection.backend == :fake
    assert review_projection.backend == :fake
  end

  test "maps widened work-control and operator surface contracts into app-kit DTOs" do
    context = request_context()

    assert {:ok, run_request} =
             RunRequest.new(%{
               subject_ref: %{id: "subj-1", subject_kind: "work_object"},
               recipe_ref: "expense_capture",
               params: %{"priority" => "high"}
             })

    assert {:ok, start_result} =
             MezzanineBridge.start_run(
               context,
               run_request,
               work_control_service: FakeWorkControlService
             )

    assert start_result.payload.subject_id == "subj-1"

    assert {:ok, run_ref} =
             RunRef.new(%{
               run_id: "run-1",
               scope_id: "program/program-1",
               metadata: %{work_object_id: "subj-1"}
             })

    assert {:ok, retry_result} =
             MezzanineBridge.retry_run(
               context,
               run_ref,
               work_control_service: FakeWorkControlService
             )

    assert {:ok, cancel_result} =
             MezzanineBridge.cancel_run(
               context,
               run_ref,
               work_control_service: FakeWorkControlService
             )

    assert {:ok, subject_ref} = SubjectRef.new(%{id: "subj-1", subject_kind: "work_object"})

    assert {:ok, projection} =
             MezzanineBridge.subject_status(
               context,
               subject_ref,
               operator_query_service: FakeOperatorQueryService
             )

    assert {:ok, timeline} =
             MezzanineBridge.timeline(
               context,
               subject_ref,
               operator_query_service: FakeOperatorQueryService
             )

    assert {:ok, actions} =
             MezzanineBridge.available_actions(
               context,
               subject_ref,
               operator_query_service: FakeOperatorQueryService
             )

    assert {:ok, action_request} =
             OperatorActionRequest.new(%{
               action_ref: hd(actions).action_ref,
               params: %{"reason" => "duplicate"}
             })

    assert {:ok, action_result} =
             MezzanineBridge.apply_action(
               context,
               subject_ref,
               action_request,
               operator_action_service: FakeOperatorActionService
             )

    assert {:ok, trace} =
             MezzanineBridge.get_unified_trace(
               context,
               projection.current_execution_ref,
               operator_query_service: FakeOperatorQueryService
             )

    assert retry_result.action_ref.action_kind == "retry"
    assert cancel_result.action_ref.action_kind == "cancel"
    assert projection.updated_at == ~U[2026-04-18 13:10:00Z]
    assert hd(projection.available_actions).action_ref.action_kind == "pause"
    assert hd(timeline).event_kind == "run_scheduled"
    assert hd(timeline).actor_ref.id == "app_kit_bridge"
    assert hd(projection.timeline).actor_ref.kind == :system
    assert hd(actions).action_ref.action_kind == "cancel"
    assert action_result.metadata.params["reason"] == "duplicate"
    assert hd(trace.steps).source == "execution_record"
  end

  test "normalizes missing program context into a surface error" do
    {:ok, context} =
      RequestContext.new(%{
        trace_id: "trace-missing-program",
        actor_ref: %{id: "user-1", kind: :human},
        tenant_ref: %{id: "tenant-1"}
      })

    {:ok, page_request} = PageRequest.new(%{limit: 10})

    assert {:error, error} =
             MezzanineBridge.list_pending(
               context,
               page_request,
               review_query_service: FakeReviewQueryService
             )

    assert error.kind == :validation
    assert error.code == "missing_program_id"
  end

  defp request_context do
    {:ok, context} =
      RequestContext.new(%{
        trace_id: "trace-mezzanine-bridge",
        actor_ref: %{id: "user-1", kind: :human},
        tenant_ref: %{id: "tenant-1"},
        installation_ref: %{id: "inst-1", pack_slug: "expense_approval", status: :active},
        metadata: %{program_id: "program-1", work_class_id: "work-class-1"}
      })

    context
  end
end
