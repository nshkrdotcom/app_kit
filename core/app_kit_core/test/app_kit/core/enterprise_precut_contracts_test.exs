defmodule AppKit.Core.EnterprisePrecutContractsTest do
  use ExUnit.Case, async: true

  alias AppKit.Core.{
    AttachGrantRef,
    CommandEnvelope,
    CommandResult,
    EnvironmentRef,
    LowerScopeRef,
    PrincipalRef,
    ProjectRef,
    Rejection,
    ResourcePath,
    ResourceRef,
    ReviewTaskRef,
    SystemActorRef,
    WorkflowQueryRequest,
    WorkflowRef,
    WorkflowSignalRequest,
    WorkflowStartRequest,
    WorkspaceRef
  }

  @precut_modules [
    WorkspaceRef,
    ProjectRef,
    EnvironmentRef,
    PrincipalRef,
    SystemActorRef,
    ResourceRef,
    ResourcePath,
    CommandEnvelope,
    CommandResult,
    WorkflowRef,
    WorkflowStartRequest,
    WorkflowSignalRequest,
    WorkflowQueryRequest,
    LowerScopeRef,
    AttachGrantRef,
    ReviewTaskRef,
    Rejection,
    AppKit.CommandSurface,
    AppKit.WorkflowControlSurface,
    AppKit.WorkflowReadSurface,
    AppKit.OperatorActionSurface,
    AppKit.LowerReadSurface,
    AppKit.AttachSurface,
    AppKit.ProjectionSurface
  ]

  test "loads every enterprise pre-cut AppKit DTO and surface contract" do
    for module <- @precut_modules do
      assert Code.ensure_loaded?(module), "#{inspect(module)} is not compiled"
    end
  end

  test "builds the enterprise command envelope and rejects missing required scope" do
    assert {:ok, envelope} =
             CommandEnvelope.new(%{
               command_id: "cmd-105",
               command_name: "work.start",
               command_version: "v1",
               tenant_ref: "tenant-acme",
               principal_ref: "principal-operator",
               resource_ref: "resource-work-1",
               resource_path: "tenant-acme/work/resource-work-1",
               request_id: "req-105",
               trace_id: "trace-105",
               correlation_id: "corr-105",
               idempotency_key: "idem-105",
               dedupe_scope: "tenant-acme:work.start",
               authority_packet_ref: "authpkt-105",
               redaction_posture: "operator_summary",
               error_namespace: "appkit.command",
               retry_posture: "safe_idempotent"
             })

    assert envelope.contract_name == "AppKit.CommandEnvelope.v1"
    assert envelope.tenant_ref == "tenant-acme"
    assert envelope.principal_ref == "principal-operator"
    assert envelope.resource_ref == "resource-work-1"

    assert {:error, {:missing_required_fields, [:tenant_ref]}} =
             CommandEnvelope.new(%{
               command_id: "cmd-105",
               command_name: "work.start",
               command_version: "v1",
               principal_ref: "principal-operator",
               resource_ref: "resource-work-1",
               authority_packet_ref: "authpkt-105",
               trace_id: "trace-105",
               idempotency_key: "idem-105"
             })
  end

  test "workflow, lower, attach, review, and rejection DTOs carry public-safe refs" do
    assert {:ok, workflow_ref} =
             WorkflowRef.new(%{
               workflow_type: "agentic_workflow",
               workflow_id: "wf-110",
               workflow_version: "v1",
               tenant_ref: "tenant-acme",
               resource_ref: "resource-work-1",
               subject_ref: "subject-1",
               starter_command_id: "cmd-105",
               trace_id: "trace-105",
               search_attributes: %{"phase4.workflow_type" => "agentic_workflow"},
               release_manifest_version: "phase4-v6-milestone24"
             })

    assert {:ok, _start} =
             WorkflowStartRequest.new(%{
               command_envelope: "cmd-105",
               permission_decision_ref: "decision-105",
               workflow_type: workflow_ref.workflow_type,
               workflow_id: workflow_ref.workflow_id,
               workflow_input_version: "v1",
               search_attributes: workflow_ref.search_attributes,
               starter_outbox_ref: "outbox-110"
             })

    assert {:ok, _signal} =
             WorkflowSignalRequest.new(%{
               command_envelope: "cmd-111",
               permission_decision_ref: "decision-111",
               workflow_ref: "wf-110",
               signal_name: "operator.cancel",
               signal_version: "v1",
               signal_id: "sig-111",
               signal_payload_ref: "claim-signal-111",
               signal_payload_hash: String.duplicate("a", 64)
             })

    assert {:ok, _query} =
             WorkflowQueryRequest.new(%{
               tenant_ref: "tenant-acme",
               principal_ref: "principal-operator",
               resource_ref: "resource-work-1",
               workflow_ref: "wf-110",
               query_name: "describe",
               query_version: "v1",
               trace_id: "trace-110",
               redaction_posture: "operator_summary"
             })

    assert {:ok, _lower_scope} =
             LowerScopeRef.new(%{
               tenant_ref: "tenant-acme",
               principal_ref: "principal-operator",
               resource_ref: "resource-work-1",
               lower_run_ref: "lower-112",
               permission_decision_ref: "decision-112",
               lease_ref: "lease-112",
               trace_id: "trace-112",
               redaction_posture: "operator_summary"
             })

    assert {:ok, _attach} =
             AttachGrantRef.new(%{
               attach_grant_id: "attach-114",
               tenant_ref: "tenant-acme",
               principal_ref: "principal-operator",
               resource_ref: "resource-work-1",
               stream_ref: "stream-114",
               lease_ref: "lease-114",
               expires_at: "2026-04-18T00:00:00Z",
               revocation_state: "active",
               trace_id: "trace-114"
             })

    assert {:ok, _review_task} =
             ReviewTaskRef.new(%{
               review_task_id: "review-1",
               tenant_ref: "tenant-acme",
               resource_ref: "resource-work-1",
               workflow_ref: "wf-110",
               requested_by_ref: "principal-operator",
               required_action: "approve",
               authority_context_ref: "authctx-1",
               status: "pending",
               trace_id: "trace-review"
             })

    assert {:ok, rejection} =
             Rejection.new(%{
               rejection_id: "rej-106",
               rejection_class: "unauthorized_action",
               public_message_code: "command.denied",
               retry_posture: "never",
               decision_ref: "decision-106",
               trace_id: "trace-106",
               redaction_posture: "public_safe"
             })

    assert rejection.contract_name == "AppKit.Rejection.v1"
  end

  test "basic refs expose tenant-scoped public identifiers" do
    assert {:ok, %WorkspaceRef{id: "workspace-1", tenant_id: "tenant-acme"}} =
             WorkspaceRef.new(%{id: "workspace-1", tenant_id: "tenant-acme"})

    assert {:ok, %ProjectRef{id: "project-1", tenant_id: "tenant-acme"}} =
             ProjectRef.new(%{id: "project-1", tenant_id: "tenant-acme"})

    assert {:ok, %EnvironmentRef{id: "env-1", tenant_id: "tenant-acme"}} =
             EnvironmentRef.new(%{id: "env-1", tenant_id: "tenant-acme"})

    assert {:ok, %PrincipalRef{id: "principal-1", tenant_id: "tenant-acme"}} =
             PrincipalRef.new(%{id: "principal-1", tenant_id: "tenant-acme", kind: "operator"})

    assert {:ok, %SystemActorRef{id: "system-1", tenant_id: "tenant-acme"}} =
             SystemActorRef.new(%{
               id: "system-1",
               tenant_id: "tenant-acme",
               actor_kind: "workflow",
               owning_repo: "mezzanine"
             })

    assert {:ok, %ResourceRef{id: "resource-1", tenant_id: "tenant-acme"}} =
             ResourceRef.new(%{
               id: "resource-1",
               tenant_id: "tenant-acme",
               resource_kind: "workflow",
               owning_repo: "mezzanine"
             })

    assert {:ok, %ResourcePath{terminal_resource_id: "resource-1"}} =
             ResourcePath.new(%{
               tenant_id: "tenant-acme",
               segments: ["tenant-acme", "workflow", "resource-1"],
               resource_kind_path: ["tenant", "workflow"],
               terminal_resource_id: "resource-1"
             })

    assert {:ok, %CommandResult{status: "accepted"}} =
             CommandResult.new(%{
               command_id: "cmd-105",
               status: "accepted",
               permission_decision_ref: "decision-105",
               trace_id: "trace-105",
               release_manifest_version: "phase4-v6-milestone24"
             })
  end
end
