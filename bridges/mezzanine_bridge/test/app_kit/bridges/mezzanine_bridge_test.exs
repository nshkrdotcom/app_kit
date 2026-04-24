defmodule AppKit.Bridges.MezzanineBridgeTest do
  use ExUnit.Case, async: true

  alias AppKit.Core.{BindingDescriptor, Telemetry}

  defmodule TelemetryForwarder do
    def handle_event(event, measurements, metadata, test_pid) do
      send(test_pid, {:telemetry, event, measurements, metadata})
    end
  end

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
         active_run_status: :running,
         active_execution_id: "exec-1",
         active_execution_dispatch_state: :awaiting_receipt,
         active_execution_trace_id: "11111111111111111111111111111111",
         pending_review_ids: ["dec-1"],
         gate_status: %{status: :pending},
         pending_obligations: [
           %{
             obligation_id: "ob-1",
             obligation_kind: :review,
             status: :pending,
             summary: "Operator review required",
             decision_ref_id: "dec-1",
             blocking?: true
           }
         ],
         blocking_conditions: [
           %{
             blocker_kind: :review_pending,
             status: :blocked,
             summary: "Waiting for operator review",
             obligation_id: "ob-1",
             decision_ref_id: "dec-1"
           }
         ],
         next_step_preview: %{
           step_kind: :record_review_decision,
           status: :blocked,
           summary: "Record operator review"
         },
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

  defmodule FakeArchivedWorkQueryService do
    def ingest_subject(_attrs, _opts), do: {:error, :bridge_not_found}
    def list_subjects(_tenant_id, _program_id, _filters), do: {:ok, []}
    def get_subject_detail(_tenant_id, _subject_id), do: {:error, :archived, "manifest-1"}
    def get_subject_projection(_tenant_id, _subject_id), do: {:error, :archived, "manifest-1"}
    def queue_stats(_tenant_id, _program_id), do: {:ok, %{active_count: 0, running_count: 0}}
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

  defmodule FakeProgramContextService do
    def resolve(
          "tenant-1",
          %{program_slug: "expense_program", work_class_name: "expense_item"},
          _opts
        ) do
      {:ok, %{program_id: "program-1", work_class_id: "work-class-1"}}
    end

    def resolve("tenant-1", %{program_slug: "expense_program"}, _opts) do
      {:ok, %{program_id: "program-1"}}
    end

    def resolve(_tenant_id, _attrs, _opts), do: {:error, :bridge_not_found}
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

    def update_bindings("inst-1", binding_config, _opts) do
      {:ok,
       %{
         status: :completed,
         action_ref: %{id: "inst-1:update_bindings", action_kind: "update_bindings"},
         message: "Bindings updated",
         metadata: %{backend: :fake, binding_config: binding_config}
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

  defmodule FakeLeaseService do
    def issue_read_lease(_attrs, _opts) do
      {:ok,
       %{
         lease_ref: %{
           id: "lease-read-1",
           allowed_family: "unified_trace",
           execution_ref: %{id: "run-1"}
         },
         trace_id: "33333333333333333333333333333333",
         expires_at: ~U[2026-04-18 12:10:00Z],
         lease_token: "read-token-1",
         allowed_operations: ["fetch_run", "events"],
         scope: %{"include_lower" => true},
         lineage_anchor: %{"submission_ref" => "sub-1"},
         invalidation_cursor: 7,
         invalidation_channel: "read:unified_trace"
       }}
    end

    def issue_stream_attach_lease(_attrs, _opts) do
      {:ok,
       %{
         lease_ref: %{
           id: "lease-stream-1",
           allowed_family: "runtime_stream",
           execution_ref: %{id: "run-1"}
         },
         trace_id: "33333333333333333333333333333333",
         expires_at: ~U[2026-04-18 12:10:00Z],
         attach_token: "stream-token-1",
         scope: %{"transport" => "sse"},
         lineage_anchor: %{"submission_ref" => "sub-1"},
         reconnect_cursor: 7,
         invalidation_channel: "stream:runtime_stream",
         poll_interval_ms: 2_000
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
           summary: "Record operator review",
           blocking_condition_kinds: ["review_pending"],
           obligation_ids: ["ob-1"]
         },
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

    def execution_trace_lineage("exec-1") do
      {:ok,
       %{
         execution_id: "exec-1",
         installation_id: "inst-1",
         trace_id: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
       }}
    end

    def get_unified_trace(_attrs, _opts) do
      {:ok,
       %{
         trace_id: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
         installation_id: "inst-1",
         join_keys: %{"subject_id" => "subj-1"},
         steps: [
           %{
             ref: "step-1",
             source: :execution_record,
             occurred_at: ~U[2026-04-18 13:05:00Z],
             trace_id: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
             staleness_class: :lower_fresh,
             operator_actionable?: false,
             diagnostic?: false,
             payload: %{"dispatch_state" => "dispatching"}
           }
         ]
       }}
    end
  end

  defmodule FakeDeniedOperatorQueryService do
    def execution_trace_lineage(_execution_id), do: {:error, :unauthorized_lower_read}
    def get_unified_trace(_attrs, _opts), do: {:error, :unauthorized_lower_read}
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

  defmodule FakeMemoryControlService do
    def list_fragments_by_proof_token(attrs, _opts) do
      send(self(), {:memory_list, attrs})

      {:ok,
       [
         %{
           fragment_ref: "memory-private://alpha/private-1",
           tenant_ref: attrs.tenant_ref,
           installation_ref: attrs.installation_ref,
           tier: "private",
           proof_token_ref: attrs.proof_token_ref,
           proof_hash: valid_hash("proof"),
           source_node_ref: "node://memory-reader@host/reader-1",
           snapshot_epoch: 42,
           commit_lsn: "16/B374D848",
           commit_hlc: %{wall_ns: 1_800_000_000_000_000_000, logical: 1, node: "reader-1"},
           provenance_refs: ["provenance://outer-brain/context/1"],
           evidence_refs: [%{ref: "evidence://recall/1", kind: "proof"}],
           governance_refs: [%{ref: "governance://memory/read", kind: "read"}],
           cluster_invalidation_status: "none",
           staleness_class: "fresh",
           redaction_posture: "operator_safe",
           payload: %{"forbidden" => "service must strip this"}
         }
       ]}
    end

    def lookup_fragment_by_proof_token(attrs, _opts) do
      send(self(), {:memory_lookup, attrs})

      {:ok,
       %{
         fragment_ref: "memory-private://alpha/private-1",
         tenant_ref: attrs.tenant_ref,
         installation_ref: attrs.installation_ref,
         tier: "private",
         proof_token_ref: attrs.proof_token_ref,
         proof_hash: valid_hash("proof"),
         source_node_ref: "node://memory-reader@host/reader-1",
         snapshot_epoch: 42,
         commit_lsn: "16/B374D848",
         commit_hlc: %{wall_ns: 1_800_000_000_000_000_000, logical: 1, node: "reader-1"},
         provenance_refs: ["provenance://outer-brain/context/1"],
         evidence_refs: [%{ref: "evidence://recall/1", kind: "proof"}],
         governance_refs: [%{ref: "governance://memory/read", kind: "read"}],
         cluster_invalidation_status: "none",
         staleness_class: "fresh",
         redaction_posture: "operator_safe"
       }}
    end

    def fragment_provenance(attrs, _opts) do
      send(self(), {:memory_provenance, attrs})

      {:ok,
       %{
         fragment_ref: attrs.fragment_ref,
         proof_token_ref: "proof://recall/1",
         proof_hash: valid_hash("proof"),
         source_contract_name: "OuterBrain.MemoryContextProvenance.v2",
         snapshot_epoch: 42,
         source_node_ref: "node://memory-reader@host/reader-1",
         commit_lsn: "16/B374D848",
         commit_hlc: %{wall_ns: 1_800_000_000_000_000_000, logical: 1, node: "reader-1"},
         provenance_refs: ["provenance://outer-brain/context/1"],
         evidence_refs: [%{ref: "evidence://recall/1", kind: "proof"}],
         governance_refs: [%{ref: "governance://memory/read", kind: "read"}]
       }}
    end

    def request_share_up(attrs, _opts) do
      send(self(), {:memory_share_up, attrs})
      action_result(attrs.fragment_ref, "share_up", "Share-up requested")
    end

    def request_promotion(attrs, _opts) do
      send(self(), {:memory_promotion, attrs})
      action_result(attrs.shared_fragment_ref, "promote", "Promotion requested")
    end

    def request_invalidation(attrs, _opts) do
      send(self(), {:memory_invalidation, attrs})
      action_result(attrs.root_fragment_ref, "invalidate", "Invalidation requested")
    end

    defp action_result(fragment_ref, action_kind, message) do
      {:ok,
       %{
         status: :accepted,
         action_ref: %{
           id: "#{fragment_ref}:#{action_kind}",
           action_kind: action_kind
         },
         message: message,
         metadata: %{fragment_ref: fragment_ref}
       }}
    end

    defp valid_hash(seed) do
      "sha256:" <> Base.encode16(:crypto.hash(:sha256, seed), case: :lower)
    end
  end

  defmodule FakeDeniedMemoryControlService do
    def lookup_fragment_by_proof_token(%{expected_tenant_ref: "tenant://other"}, _opts),
      do: {:error, :unauthorized_lower_read}

    def lookup_fragment_by_proof_token(%{current_epoch: 43}, _opts),
      do: {:error, :stale_proof_token}
  end

  alias AppKit.Bridges.MezzanineBridge

  alias AppKit.Core.{
    DecisionRef,
    ExecutionRef,
    FilterSet,
    InstallationBinding,
    InstallationRef,
    InstallTemplate,
    MemoryFragmentListRequest,
    MemoryInvalidationRequest,
    MemoryPromotionRequest,
    MemoryProofTokenLookup,
    MemoryShareUpRequest,
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

    assert detail.current_execution_ref.id == "exec-1"
    assert length(detail.pending_decision_refs) == 1
    assert hd(detail.pending_obligations).obligation_id == "ob-1"
    assert hd(detail.blocking_conditions).blocker_kind == "review_pending"
    assert detail.next_step_preview.step_kind == "record_review_decision"

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

  test "maps archived hot-subject reads into a terminal surface error carrying manifest_ref" do
    context = request_context()
    assert {:ok, subject_ref} = SubjectRef.new(%{id: "subj-1", subject_kind: "work_object"})

    assert {:error, error} =
             MezzanineBridge.get_subject(
               context,
               subject_ref,
               work_query_service: FakeArchivedWorkQueryService
             )

    assert error.kind == :terminal
    assert error.code == "archived"
    assert error.details.manifest_ref == "manifest-1"
    refute error.retryable
  end

  test "resolves program context from product metadata when raw lower ids are absent" do
    context =
      request_context(%{
        program_slug: "expense_program",
        work_class_name: "expense_item"
      })

    assert {:ok, created_ref} =
             MezzanineBridge.ingest_subject(
               context,
               %{external_ref: "ENG-499", title: "Created from metadata"},
               work_query_service: FakeWorkQueryService,
               program_context_service: FakeProgramContextService
             )

    assert created_ref.id == "subj-1"

    assert {:ok, page_request} = PageRequest.new(%{limit: 10})

    assert {:ok, review_page} =
             MezzanineBridge.list_pending(
               context,
               page_request,
               review_query_service: FakeReviewQueryService,
               program_context_service: FakeProgramContextService
             )

    assert hd(review_page.entries).decision_ref.id == "dec-1"
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

    assert {:ok, execution_binding} =
             InstallationBinding.new(%{
               binding_key: "expense_capture",
               binding_kind: :execution,
               config: %{"placement_ref" => "local_runner"}
             })

    assert {:ok, context_descriptor} =
             BindingDescriptor.new(%{
               attachment: "outer_brain.context_adapter",
               contract: :contributing,
               envelope: %{
                 staleness_class: :diagnostic_only,
                 trace_propagation: :required,
                 tenant_scope: :installation_scoped,
                 blast_radius: :installation,
                 timeout_ms: 600,
                 runbook_ref: "runbooks/context_adapter"
               },
               failure: %{
                 on_unavailable: :proceed_without,
                 on_timeout: :proceed_without
               },
               ownership: %{
                 external_system: "Mem0",
                 external_system_ref: "mem0.primary",
                 operator_owner: "memory-ops"
               }
             })

    assert {:ok, subject_descriptor} =
             BindingDescriptor.new(%{
               attachment: "mezzanine.subject_kind",
               contract: :authoritative,
               envelope: %{
                 staleness_class: :substrate_authoritative,
                 trace_propagation: :required,
                 tenant_scope: :installation_scoped,
                 blast_radius: :installation,
                 runbook_ref: "runbooks/consolidation_subject"
               },
               failure: %{
                 on_unavailable: :retry_background,
                 on_timeout: :retry_background
               },
               ownership: %{
                 external_system: "Mem0",
                 external_system_ref: "mem0.primary",
                 operator_owner: "memory-ops"
               }
             })

    assert {:ok, observer_descriptor} =
             BindingDescriptor.new(%{
               attachment: "jido_integration.audit_subscriber",
               contract: :advisory,
               envelope: %{
                 staleness_class: :diagnostic_only,
                 trace_propagation: :required,
                 tenant_scope: :installation_scoped,
                 blast_radius: :installation,
                 runbook_ref: "runbooks/audit_export"
               },
               failure: %{
                 on_unavailable: :fail_installation_health,
                 on_timeout: :retry_background
               },
               ownership: %{
                 external_system: "Mem0",
                 external_system_ref: "mem0.primary",
                 operator_owner: "memory-ops"
               }
             })

    assert {:ok, context_binding} =
             InstallationBinding.new(%{
               binding_key: "workspace_memory",
               binding_kind: :context,
               descriptor: context_descriptor,
               config: %{
                 "adapter_key" => "mem0_context",
                 "config" => %{"workspace" => "default"},
                 "timeout_ms" => 500
               },
               credential_ref: "cred-memory-1"
             })

    assert {:ok, subject_binding} =
             InstallationBinding.new(%{
               binding_key: "turn_consolidation",
               binding_kind: :subject,
               descriptor: subject_descriptor,
               config: %{
                 "subject_kind" => "turn_consolidation",
                 "recipe_refs" => ["belief_consolidation_runtime"]
               }
             })

    assert {:ok, observer_binding} =
             InstallationBinding.new(%{
               binding_key: "hindsight_audit",
               binding_kind: :observer,
               descriptor: observer_descriptor,
               config: %{
                 "subscriber_key" => "mem0_audit_export",
                 "event_types" => ["run.accepted", "event.appended"]
               }
             })

    assert {:ok, update_result} =
             MezzanineBridge.update_bindings(
               context,
               installation_ref,
               [execution_binding, context_binding, subject_binding, observer_binding],
               installation_service: FakeInstallationService
             )

    assert update_result.metadata.backend == :fake

    assert update_result.metadata.binding_config["execution_bindings"]["expense_capture"][
             "placement_ref"
           ] == "local_runner"

    assert update_result.metadata.binding_config["context_bindings"]["workspace_memory"][
             "adapter_key"
           ] == "mem0_context"

    assert get_in(update_result.metadata.binding_config, [
             "context_bindings",
             "workspace_memory",
             "descriptor",
             "ownership",
             "external_system_ref"
           ]) == "mem0.primary"

    assert update_result.metadata.binding_config["subject_bindings"]["turn_consolidation"][
             "subject_kind"
           ] == "turn_consolidation"

    assert get_in(update_result.metadata.binding_config, [
             "observer_bindings",
             "hindsight_audit",
             "descriptor",
             "attachment"
           ]) == "jido_integration.audit_subscriber"

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

  test "routes work control and operator actions through the current backend split" do
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
    attach_telemetry(self(), [:unified_trace_assembled])
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

    assert {:ok, read_lease} =
             MezzanineBridge.issue_read_lease(
               context,
               projection.current_execution_ref,
               lease_service: FakeLeaseService,
               operator_query_service: FakeOperatorQueryService
             )

    assert {:ok, stream_attach_lease} =
             MezzanineBridge.issue_stream_attach_lease(
               context,
               projection.current_execution_ref,
               lease_service: FakeLeaseService,
               operator_query_service: FakeOperatorQueryService
             )

    assert retry_result.action_ref.action_kind == "retry"
    assert cancel_result.action_ref.action_kind == "cancel"
    assert projection.updated_at == ~U[2026-04-18 13:10:00Z]
    assert hd(projection.available_actions).action_ref.action_kind == "pause"
    assert hd(projection.pending_obligations).obligation_id == "ob-1"
    assert hd(projection.blocking_conditions).blocker_kind == "review_pending"
    assert projection.next_step_preview.step_kind == "record_review_decision"
    assert hd(timeline).event_kind == "run_scheduled"
    assert hd(timeline).actor_ref.id == "app_kit_bridge"
    assert hd(projection.timeline).actor_ref.kind == :system
    assert hd(actions).action_ref.action_kind == "cancel"
    assert action_result.metadata.params["reason"] == "duplicate"
    assert hd(trace.steps).source == "execution_record"
    assert read_lease.lease_ref.allowed_family == "unified_trace"
    assert stream_attach_lease.lease_ref.allowed_family == "runtime_stream"

    assert_event(
      :unified_trace_assembled,
      %{count: 1, step_count: 1, join_key_count: 1},
      %{
        trace_id: trace.trace_id,
        tenant_id: "tenant-1",
        installation_id: "inst-1",
        execution_id: projection.current_execution_ref.id,
        source: :northbound_surface,
        surface: :mezzanine_bridge
      }
    )
  end

  test "maps memory-control service into operator-safe AppKit DTOs" do
    context = request_context()

    assert {:ok, list_request} =
             MemoryFragmentListRequest.new(%{
               proof_token_ref: "proof://recall/1",
               include_provenance?: true
             })

    assert {:ok, proof_lookup} =
             MemoryProofTokenLookup.new(%{
               proof_token_ref: "proof://recall/1",
               expected_tenant_ref: "tenant://alpha",
               reject_stale?: true,
               current_epoch: 42
             })

    assert {:ok, [fragment]} =
             MezzanineBridge.list_memory_fragments(
               context,
               list_request,
               memory_control_service: FakeMemoryControlService
             )

    assert {:ok, same_fragment} =
             MezzanineBridge.memory_fragment_by_proof_token(
               context,
               proof_lookup,
               memory_control_service: FakeMemoryControlService
             )

    assert {:ok, provenance} =
             MezzanineBridge.memory_fragment_provenance(
               context,
               "memory-private://alpha/private-1",
               memory_control_service: FakeMemoryControlService
             )

    assert_received {:memory_list, list_attrs}
    assert_received {:memory_lookup, lookup_attrs}
    assert_received {:memory_provenance, provenance_attrs}

    assert list_attrs.tenant_ref == "tenant-1"
    assert lookup_attrs.proof_token_ref == "proof://recall/1"
    assert provenance_attrs.fragment_ref == "memory-private://alpha/private-1"
    assert fragment.proof_hash == same_fragment.proof_hash
    assert fragment.staleness_class == "fresh"
    assert fragment.cluster_invalidation_status == "none"
    refute Map.has_key?(Map.from_struct(fragment), :payload)
    assert provenance.source_contract_name == "OuterBrain.MemoryContextProvenance.v2"
  end

  test "routes share-up, promotion, and invalidation requests through memory-control service" do
    context = request_context()

    assert {:ok, share_up_request} =
             MemoryShareUpRequest.new(%{
               fragment_ref: "memory-private://alpha/private-1",
               target_scope_ref: "scope://team-alpha",
               share_up_policy_ref: "share-up-policy://team-alpha",
               transform_ref: "transform://redact-pii",
               reason: "share project memory",
               evidence_refs: [%{ref: "evidence://operator/share-up", kind: "operator"}]
             })

    assert {:ok, promotion_request} =
             MemoryPromotionRequest.new(%{
               shared_fragment_ref: "memory-shared://alpha/shared-1",
               promotion_policy_ref: "promote-policy://governed",
               reason: "approved for governed memory",
               evidence_refs: [%{ref: "evidence://operator/promote", kind: "operator"}]
             })

    assert {:ok, invalidation_request} =
             MemoryInvalidationRequest.new(%{
               root_fragment_ref: "memory-private://alpha/private-1",
               reason: :operator_suppression,
               suppression_reason: "obsolete user preference",
               invalidate_policy_ref: "invalidate-policy://default",
               authority_ref: %{ref: "authority://operator/suppression", kind: "operator"},
               evidence_refs: [%{ref: "evidence://operator/invalidate", kind: "operator"}]
             })

    assert {:ok, share_up_result} =
             MezzanineBridge.request_memory_share_up(
               context,
               share_up_request,
               memory_control_service: FakeMemoryControlService
             )

    assert {:ok, promotion_result} =
             MezzanineBridge.request_memory_promotion(
               context,
               promotion_request,
               memory_control_service: FakeMemoryControlService
             )

    assert {:ok, invalidation_result} =
             MezzanineBridge.request_memory_invalidation(
               context,
               invalidation_request,
               memory_control_service: FakeMemoryControlService
             )

    assert_received {:memory_share_up, share_attrs}
    assert_received {:memory_promotion, promotion_attrs}
    assert_received {:memory_invalidation, invalidation_attrs}

    assert share_attrs.trace_id == context.trace_id
    assert share_attrs.actor_ref == "user-1"
    assert promotion_attrs.shared_fragment_ref == "memory-shared://alpha/shared-1"
    assert invalidation_attrs.reason == :operator_suppression
    assert invalidation_attrs.suppression_reason == "obsolete user preference"
    assert share_up_result.action_ref.action_kind == "share_up"
    assert promotion_result.action_ref.action_kind == "promote"
    assert invalidation_result.action_ref.action_kind == "invalidate"
  end

  test "memory proof lookup rejects cross-tenant and stale proof-token reads" do
    context = request_context()

    assert {:ok, cross_tenant_lookup} =
             MemoryProofTokenLookup.new(%{
               proof_token_ref: "proof://recall/1",
               expected_tenant_ref: "tenant://other",
               reject_stale?: true,
               current_epoch: 42
             })

    assert {:error, cross_tenant_error} =
             MezzanineBridge.memory_fragment_by_proof_token(
               context,
               cross_tenant_lookup,
               memory_control_service: FakeDeniedMemoryControlService
             )

    assert {:ok, stale_lookup} =
             MemoryProofTokenLookup.new(%{
               proof_token_ref: "proof://recall/1",
               expected_tenant_ref: "tenant-1",
               reject_stale?: true,
               current_epoch: 43
             })

    assert {:error, stale_error} =
             MezzanineBridge.memory_fragment_by_proof_token(
               context,
               stale_lookup,
               memory_control_service: FakeDeniedMemoryControlService
             )

    assert cross_tenant_error.kind == :authorization
    assert cross_tenant_error.code == "unauthorized_lower_read"
    assert stale_error.kind == :validation
    assert stale_error.code == "stale_proof_token"
  end

  test "memory-control bridge keeps direct stores out of the northbound AppKit surface" do
    bridge_root = Path.expand("../../..", __DIR__)

    bridge_root
    |> Path.join("lib/**/*.ex")
    |> Path.wildcard(match_dot: true)
    |> Enum.each(fn path ->
      contents = File.read!(path)

      refute contents =~ "Jido.Integration.V2.StorePostgres",
             "#{path} imports the lower memory store directly"

      refute contents =~ "MemoryTierStore",
             "#{path} bypasses the Mezzanine memory-control facade"
    end)
  end

  test "normalizes missing program context into a surface error" do
    {:ok, context} =
      RequestContext.new(%{
        trace_id: "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
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

  test "normalizes unauthorized lower reads into an authorization surface error" do
    context = request_context()

    assert {:ok, subject_ref} = SubjectRef.new(%{id: "subj-1", subject_kind: "work_object"})

    assert {:ok, execution_ref} =
             ExecutionRef.new(%{
               id: "exec-1",
               subject_ref: subject_ref,
               recipe_ref: "expense_capture",
               dispatch_state: :accepted
             })

    assert {:error, error} =
             MezzanineBridge.get_unified_trace(
               context,
               execution_ref,
               operator_query_service: FakeDeniedOperatorQueryService
             )

    assert error.kind == :authorization
    assert error.code == "unauthorized_lower_read"
    refute error.retryable
  end

  test "does not declare the deprecated mezzanine app-kit bridge package" do
    deps = AppKitMezzanineBridge.MixProject.project()[:deps]

    refute Enum.any?(deps, fn
             {:mezzanine_app_kit_bridge, _opts} -> true
             {:mezzanine_app_kit_bridge, _requirement, _opts} -> true
             _other -> false
           end)
  end

  test "does not declare or reference the deprecated mezzanine ops_model package" do
    deps = AppKitMezzanineBridge.MixProject.project()[:deps]

    refute Enum.any?(deps, fn
             {:mezzanine_ops_model, _opts} -> true
             {:mezzanine_ops_model, _requirement, _opts} -> true
             _other -> false
           end)

    bridge_root = Path.expand("../../..", __DIR__)

    bridge_root
    |> Path.join("lib/**/*.ex")
    |> Path.wildcard(match_dot: true)
    |> Enum.each(fn path ->
      refute File.read!(path) =~ "MezzanineOpsModel", "#{path} still references MezzanineOpsModel"
    end)
  end

  test "does not declare or reference the deprecated mezzanine ops_audit package" do
    deps = AppKitMezzanineBridge.MixProject.project()[:deps]

    refute Enum.any?(deps, fn
             {:mezzanine_ops_audit, _opts} -> true
             {:mezzanine_ops_audit, _requirement, _opts} -> true
             _other -> false
           end)

    bridge_root = Path.expand("../../..", __DIR__)

    bridge_root
    |> Path.join("lib/**/*.ex")
    |> Path.wildcard(match_dot: true)
    |> Enum.each(fn path ->
      refute File.read!(path) =~ "Mezzanine.WorkAudit",
             "#{path} still references Mezzanine.WorkAudit"
    end)
  end

  test "does not declare or reference the deprecated mezzanine ops_control package" do
    deps = AppKitMezzanineBridge.MixProject.project()[:deps]

    refute Enum.any?(deps, fn
             {:mezzanine_ops_control, _opts} -> true
             {:mezzanine_ops_control, _requirement, _opts} -> true
             _other -> false
           end)

    bridge_root = Path.expand("../../..", __DIR__)

    bridge_root
    |> Path.join("lib/**/*.ex")
    |> Path.wildcard(match_dot: true)
    |> Enum.each(fn path ->
      refute File.read!(path) =~ "Mezzanine.Control",
             "#{path} still references Mezzanine.Control"
    end)
  end

  test "does not declare or reference the deprecated mezzanine ops_assurance package" do
    deps = AppKitMezzanineBridge.MixProject.project()[:deps]

    refute Enum.any?(deps, fn
             {:mezzanine_ops_assurance, _opts} -> true
             {:mezzanine_ops_assurance, _requirement, _opts} -> true
             _other -> false
           end)

    bridge_root = Path.expand("../../..", __DIR__)

    bridge_root
    |> Path.join("lib/**/*.ex")
    |> Path.wildcard(match_dot: true)
    |> Enum.each(fn path ->
      refute File.read!(path) =~ "Mezzanine.Assurance",
             "#{path} still references Mezzanine.Assurance"
    end)
  end

  test "does not declare or reference the deprecated mezzanine ops_domain package directly" do
    deps = AppKitMezzanineBridge.MixProject.project()[:deps]

    refute Enum.any?(deps, fn
             {:mezzanine_ops_domain, _opts} -> true
             {:mezzanine_ops_domain, _requirement, _opts} -> true
             _other -> false
           end)

    bridge_root = Path.expand("../../..", __DIR__)

    bridge_root
    |> Path.join("lib/**/*.ex")
    |> Path.wildcard(match_dot: true)
    |> Enum.each(fn path ->
      contents = File.read!(path)

      refute contents =~ "Mezzanine.OpsDomain.Repo",
             "#{path} still references Mezzanine.OpsDomain.Repo"

      refute Regex.match?(
               ~r/Mezzanine\.(Programs|Work|Runs|Review|Evidence|Control)\b/,
               contents
             ),
             "#{path} still references direct ops_domain namespaces"
    end)
  end

  defp request_context(metadata \\ %{}) do
    metadata =
      Map.merge(
        %{
          program_id: "program-1",
          work_class_id: "work-class-1",
          installation_revision: 42,
          activation_epoch: 7,
          lease_epoch: 3
        },
        metadata
      )

    {:ok, context} =
      RequestContext.new(%{
        trace_id: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        actor_ref: %{id: "user-1", kind: :human},
        tenant_ref: %{id: "tenant-1"},
        installation_ref: %{id: "inst-1", pack_slug: "expense_approval", status: :active},
        metadata: metadata
      })

    context
  end

  defp attach_telemetry(test_pid, event_keys) do
    handler_id = "mezzanine-bridge-test-#{System.unique_integer([:positive])}"

    :telemetry.attach_many(
      handler_id,
      Enum.map(event_keys, &Telemetry.event_name/1),
      &TelemetryForwarder.handle_event/4,
      test_pid
    )

    on_exit(fn -> :telemetry.detach(handler_id) end)
  end

  defp assert_event(event_key, measurements, metadata) do
    event_name = Telemetry.event_name(event_key)
    assert_receive {:telemetry, ^event_name, ^measurements, ^metadata}
    assert_contract_shape(event_key, measurements, metadata)
  end

  defp assert_contract_shape(event_key, measurements, metadata) do
    assert Enum.sort(Map.keys(measurements)) ==
             event_key |> Telemetry.measurement_keys() |> Enum.sort()

    assert Enum.sort(Map.keys(metadata)) ==
             event_key |> Telemetry.metadata_keys() |> Enum.sort()
  end
end
