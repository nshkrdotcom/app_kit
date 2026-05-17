defmodule AppKit.SourceSurfaceTest do
  use ExUnit.Case, async: true

  defmodule FakeSourceBackend do
    @behaviour AppKit.Core.Backends.SourceBackend

    @impl true
    def sync_source(_context, source_role_ref, source_page, _opts) do
      {:ok,
       %{
         operation: "linear.issues.list",
         source_role_ref: source_role_ref,
         subjects: [
           %{
             payload: %{
               external_ref: "linear://inst-1/issue/ENG-321",
               provider_external_ref: "lin-issue-321"
             }
           }
         ],
         page_info: Map.get(source_page, :page_info, %{})
       }}
    end

    @impl true
    def current_states(_context, source_role_ref, request, _opts) do
      {:ok,
       %{
         source_role_ref: source_role_ref,
         requested_issue_ids: Map.fetch!(request, :issue_ids),
         missing_issue_ids: []
       }}
    end

    @impl true
    def fetch_candidates(_context, source_role_ref, request, _opts) do
      source_binding = Map.fetch!(request, :source_binding)

      {:ok,
       %{
         source_role_ref: source_role_ref,
         source_binding_id: source_binding.source_binding_id,
         source_intake: %{
           operation: "linear.issues.list",
           subject_attrs: [
             %{source_ref: "linear://inst-1/issue/ENG-321", title: "Investigate rollback"}
           ]
         },
         provider_request_sent?: true,
         provider_response_received?: true
       }}
    end

    @impl true
    def publish_source(_context, publication_role_ref, attrs, _opts) do
      {:ok,
       %{
         publication_role_ref: publication_role_ref,
         source_publication_receipt: %{
           source_publication_receipt_ref: "source-publication://linear-primary/test",
           source_publish_ref: attrs.source_publish_ref,
           source_binding_id: attrs.source_binding_id,
           source_ref: attrs.source_ref,
           status: "published",
           capability_id: "linear.comments.update",
           workpad_refs: ["linear-comment://comment-1"]
         }
       }}
    end
  end

  alias AppKit.Core.RequestContext
  alias AppKit.SourceSurface

  test "delegates source intake through the configured backend" do
    context = request_context()

    assert {:ok, sync} =
             SourceSurface.sync_source(
               context,
               :issue_tracker,
               %{issues: [%{id: "lin-issue-321"}], page_info: %{has_next_page: false}},
               source_backend: FakeSourceBackend
             )

    assert sync.source_role_ref == :issue_tracker
    assert sync.operation == "linear.issues.list"
    assert hd(sync.subjects).payload.external_ref == "linear://inst-1/issue/ENG-321"

    assert {:ok, states} =
             SourceSurface.current_states(
               context,
               :issue_tracker,
               %{
                 issue_ids: ["lin-issue-321"],
                 source_binding: %{source_binding_id: "linear-primary"}
               },
               source_backend: FakeSourceBackend
             )

    assert states.source_role_ref == :issue_tracker
    assert states.requested_issue_ids == ["lin-issue-321"]
  end

  test "delegates source candidate fetch through the configured backend" do
    context = request_context()

    assert {:ok, candidates} =
             SourceSurface.fetch_candidates(
               context,
               :issue_tracker,
               %{source_binding: %{source_binding_id: "linear-primary"}},
               source_backend: FakeSourceBackend
             )

    assert candidates.source_role_ref == :issue_tracker
    assert candidates.source_binding_id == "linear-primary"
    assert candidates.source_intake.operation == "linear.issues.list"
    assert candidates.provider_request_sent? == true
    assert candidates.provider_response_received? == true
  end

  test "delegates source publication through the configured backend" do
    context = request_context()

    assert {:ok, publication} =
             SourceSurface.publish(
               context,
               :source_publication,
               %{
                 source_publish_ref: "linear_workpad_review",
                 source_binding_id: "linear-primary",
                 source_ref: "linear://inst-1/issue/ENG-321",
                 comment_id: "comment-1",
                 body: "Ready for review"
               },
               source_backend: FakeSourceBackend
             )

    assert publication.publication_role_ref == :source_publication
    assert publication.source_publication_receipt.status == "published"
    assert publication.source_publication_receipt.capability_id == "linear.comments.update"
  end

  defp request_context do
    {:ok, context} =
      RequestContext.new(%{
        trace_id: "22222222222222222222222222222222",
        actor_ref: %{id: "user-1", kind: :human},
        tenant_ref: %{id: "tenant-1"},
        installation_ref: %{id: "inst-1", pack_slug: "expense_approval"},
        metadata: %{program_id: "program-1", work_class_id: "work-class-1"}
      })

    context
  end
end
