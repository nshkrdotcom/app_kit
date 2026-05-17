defmodule AppKit.Core.GenericContextAndRequestsTest do
  use ExUnit.Case, async: true

  alias AppKit.Core.{
    Context,
    EvidenceCollectionRequest,
    LeaseRequest,
    ProjectionRequest,
    ResourceEffectInvocationRequest,
    ReviewRequest,
    RuntimeOperationRequest,
    SemanticContextExt,
    SourceCandidateRequest,
    SourceCurrentStateRequest,
    SourcePublicationRequest,
    SourceSyncRequest,
    ToolInvocationRequest,
    TraceRequest,
    WorkSubmitRequest,
    WorkflowContextExt
  }

  test "context carries base refs once and typed extensions separately" do
    assert {:ok, context} =
             Context.new(%{
               actor_ref: %{id: "actor-a", kind: :user},
               tenant_ref: %{id: "tenant-a"},
               installation_ref: %{id: "install-a", pack_slug: "product-a"},
               trace_ref: "trace://tenant-a/request-a",
               request_ref: "request://tenant-a/request-a",
               idempotency_key: "idempotency://tenant-a/request-a",
               workflow: %{
                 workflow_ref: "workflow://tenant-a/run-a",
                 subject_ref: "subject://tenant-a/doc-a",
                 work_item_ref: "work-item://tenant-a/item-a"
               },
               semantic: %{semantic_ref: "semantic://tenant-a/run-a"}
             })

    assert %WorkflowContextExt{} = context.workflow
    assert %SemanticContextExt{} = context.semantic
    assert context.actor_ref.id == "actor-a"
    refute :tenant_ref in WorkflowContextExt.fields()
    refute :trace_ref in SemanticContextExt.fields()
  end

  test "constructs generic request DTOs with role refs" do
    assert {:ok, _} =
             SourceSyncRequest.new(%{
               request_ref: "request://source-sync",
               source_role_ref: :issue_tracker,
               payload: %{cursor: nil}
             })

    assert {:ok, _} =
             SourceCandidateRequest.new(%{
               request_ref: "request://source-candidates",
               source_role_ref: :issue_tracker,
               query: %{state: :open}
             })

    assert {:ok, _} =
             SourceCurrentStateRequest.new(%{
               request_ref: "request://source-state",
               source_role_ref: :issue_tracker,
               source_object_refs: ["source-object://a"]
             })

    assert {:ok, _} =
             SourcePublicationRequest.new(%{
               request_ref: "request://source-publication",
               publication_role_ref: :source_publication,
               source_ref: "source-object://a",
               subject_ref: "subject://a",
               body_ref: "payload://a"
             })

    assert {:ok, _} =
             WorkSubmitRequest.new(%{
               request_ref: "request://work",
               work_role_ref: :review_work,
               target_ref: "target://a",
               payload: %{title: "review"}
             })

    assert {:ok, _} =
             RuntimeOperationRequest.new(%{
               request_ref: "request://runtime",
               runtime_role_ref: :coding_agent_runtime,
               operation_role_ref: :draft_change,
               input_ref: "payload://runtime"
             })

    assert {:ok, _} =
             ToolInvocationRequest.new(%{
               request_ref: "request://tool",
               tool_role_ref: :issue_query_tool,
               operation_role_ref: :query,
               input_ref: "payload://tool"
             })

    assert {:ok, _} =
             EvidenceCollectionRequest.new(%{
               request_ref: "request://evidence",
               evidence_role_ref: :proposed_change_evidence,
               subject_ref: "subject://a"
             })

    assert {:ok, _} =
             ResourceEffectInvocationRequest.new(%{
               request_ref: "request://effect",
               resource_effect_role_ref: :cleanup,
               subject_ref: "subject://a"
             })

    assert {:ok, _} =
             ReviewRequest.new(%{
               request_ref: "request://review",
               review_role_ref: :operator_acceptance,
               subject_ref: "subject://a"
             })

    assert {:ok, _} = TraceRequest.new(%{request_ref: "request://trace", trace_ref: "trace://a"})

    assert {:ok, _} =
             ProjectionRequest.new(%{
               request_ref: "request://projection",
               subject_ref: "subject://a",
               projection_kind: :work_item
             })

    assert {:ok, _} =
             LeaseRequest.new(%{
               request_ref: "request://lease",
               subject_ref: "subject://a",
               scope: :read
             })
  end

  test "rejects concrete binding refs and raw secret fields in generic DTOs" do
    assert {:error, {:forbidden_generic_request_field, :source_binding_ref}} =
             SourceCandidateRequest.new(%{
               request_ref: "request://bad",
               source_role_ref: :issue_tracker,
               query: %{},
               source_binding_ref: "binding://tenant-a/install-a/source-a"
             })

    assert {:error,
            {:invalid_role_ref, :source_role_ref, "binding://tenant-a/install-a/source-a"}} =
             SourceCandidateRequest.new(%{
               request_ref: "request://bad-role",
               source_role_ref: "binding://tenant-a/install-a/source-a",
               query: %{}
             })

    forbidden_key = String.to_atom("api" <> "_key")

    attrs =
      %{
        request_ref: "request://bad-secret",
        runtime_role_ref: :runtime,
        operation_role_ref: :invoke,
        input_ref: "payload://a"
      }
      |> Map.put(forbidden_key, "secret")

    assert {:error, {:forbidden_generic_request_field, ^forbidden_key}} =
             RuntimeOperationRequest.new(attrs)
  end
end
