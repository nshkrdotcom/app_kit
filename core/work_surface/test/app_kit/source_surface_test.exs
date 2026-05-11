defmodule AppKit.SourceSurfaceTest do
  use ExUnit.Case, async: true

  defmodule FakeSourceBackend do
    @behaviour AppKit.Core.Backends.SourceBackend

    @impl true
    def sync_linear_issues(_context, source_page, _opts) do
      {:ok,
       %{
         operation: "linear.issues.list",
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
    def current_linear_issue_states(_context, issue_ids, _source_binding, _opts) do
      {:ok, %{requested_issue_ids: issue_ids, missing_issue_ids: []}}
    end
  end

  alias AppKit.Core.RequestContext
  alias AppKit.SourceSurface

  test "delegates source intake through the configured backend" do
    context = request_context()

    assert {:ok, sync} =
             SourceSurface.sync_linear_issues(
               context,
               %{issues: [%{id: "lin-issue-321"}], page_info: %{has_next_page: false}},
               source_backend: FakeSourceBackend
             )

    assert sync.operation == "linear.issues.list"
    assert hd(sync.subjects).payload.external_ref == "linear://inst-1/issue/ENG-321"

    assert {:ok, states} =
             SourceSurface.current_linear_issue_states(
               context,
               ["lin-issue-321"],
               %{source_binding_id: "linear-primary"},
               source_backend: FakeSourceBackend
             )

    assert states.requested_issue_ids == ["lin-issue-321"]
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
