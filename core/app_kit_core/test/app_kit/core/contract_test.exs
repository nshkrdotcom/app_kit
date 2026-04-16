defmodule AppKit.Core.ContractTest do
  use ExUnit.Case, async: true

  alias AppKit.Core.{
    ActionResult,
    ActorRef,
    DecisionRef,
    DecisionSummary,
    ExecutionRef,
    FilterSet,
    InstallationBinding,
    InstallationRef,
    InstallResult,
    InstallTemplate,
    OperatorActionRef,
    PageRequest,
    PageResult,
    ProjectionRef,
    RequestContext,
    SortSpec,
    SubjectDetail,
    SubjectSummary,
    SurfaceError,
    TenantRef
  }

  alias AppKit.Core.Backends.{InstallationBackend, ReviewBackend, WorkQueryBackend}

  test "builds nested request context primitives" do
    assert {:ok, context} =
             RequestContext.new(%{
               trace_id: "trace-1",
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
               trace_id: "trace-1",
               actor_ref: %{id: "user-1", kind: :human},
               tenant_ref: %{id: "tenant-1"},
               feature_flags: %{new_review_path: true}
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

  test "builds installation DTOs" do
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

    assert {:ok, install_result} =
             InstallResult.new(%{
               installation_ref: %{id: "inst-1", pack_slug: "expense_approval"},
               status: :created,
               message: "installed"
             })

    assert install_template.template_key == "expense/default"
    assert installation_binding.binding_kind == :execution
    assert %InstallationRef{id: "inst-1"} = install_result.installation_ref
  end

  test "exposes the frozen backend contracts" do
    assert {:ingest_subject, 3} in WorkQueryBackend.behaviour_info(:callbacks)
    assert {:list_subjects, 4} in WorkQueryBackend.behaviour_info(:callbacks)
    assert {:record_decision, 4} in ReviewBackend.behaviour_info(:callbacks)
    assert {:create_installation, 3} in InstallationBackend.behaviour_info(:callbacks)
    assert {:reactivate_installation, 3} in InstallationBackend.behaviour_info(:callbacks)
  end
end
