defmodule AppKit.WorkSurfaceTest do
  use ExUnit.Case, async: true

  defmodule FakeWorkQueryBackend do
    @behaviour AppKit.Core.Backends.WorkQueryBackend

    alias AppKit.Core.{
      FilterSet,
      PageRequest,
      PageResult,
      ProjectionRef,
      RequestContext,
      SubjectDetail,
      SubjectRef,
      SubjectRuntimeProjection,
      SubjectSummary
    }

    @impl true
    def ingest_subject(%RequestContext{} = _context, attrs, _opts) do
      SubjectRef.new(%{
        id: "subject/#{Map.get(attrs, :external_ref, "new")}",
        subject_kind: "work_object"
      })
    end

    @impl true
    def list_subjects(
          %RequestContext{} = _context,
          filters,
          %PageRequest{} = _page_request,
          _opts
        ) do
      filter_mode = if match?(%FilterSet{}, filters), do: filters.mode, else: :none

      with {:ok, subject_ref} <- SubjectRef.new(%{id: "subject-1", subject_kind: "work_object"}),
           {:ok, summary} <-
             SubjectSummary.new(%{
               subject_ref: subject_ref,
               lifecycle_state: "planned",
               title: "Queue item",
               summary: "backend summary"
             }) do
        PageResult.new(%{
          entries: [summary],
          total_count: 1,
          has_more: false,
          metadata: %{backend: :fake, filter_mode: filter_mode}
        })
      end
    end

    @impl true
    def get_subject(%RequestContext{} = _context, %SubjectRef{} = subject_ref, _opts) do
      SubjectDetail.new(%{
        subject_ref: subject_ref,
        lifecycle_state: "planned",
        title: "Queue item"
      })
    end

    @impl true
    def get_projection(%RequestContext{} = _context, %ProjectionRef{} = projection_ref, _opts) do
      {:ok, %{projection: projection_ref.name, backend: :fake}}
    end

    @impl true
    def get_runtime_projection(
          %RequestContext{} = _context,
          %SubjectRef{} = subject_ref,
          _opts
        ) do
      SubjectRuntimeProjection.new(%{
        subject_ref: subject_ref,
        lifecycle_state: "awaiting_review",
        source_bindings: [
          %{
            binding_ref: "linear_primary",
            source_ref: "source://linear/tenant-1/#{subject_ref.id}",
            source_kind: "linear_issue"
          }
        ],
        runtime: %{events: [%{event_kind: "tool_call", count: 2}]},
        execution_state: %{
          execution_ref: %{id: "execution-1", subject_ref: subject_ref},
          lifecycle_state: "running",
          dispatch_state: "running"
        },
        lower_receipts: [
          %{
            receipt_ref: "receipt-1",
            receipt_state: "accepted",
            lower_receipt_ref: "lower-receipt-1",
            execution_ref: %{id: "execution-1", subject_ref: subject_ref}
          }
        ],
        updated_at: ~U[2026-04-25 12:00:00Z],
        schema_ref: "app_kit.subject_runtime_projection.v1",
        schema_version: 1
      })
    end

    @impl true
    def queue_stats(%RequestContext{} = _context, _filters, _opts) do
      {:ok, %{active_count: 1, backend: :fake}}
    end
  end

  alias AppKit.Core.{FilterSet, PageRequest, ProjectionRef, RequestContext, SubjectRef}
  alias AppKit.WorkSurface

  test "delegates work queries through the configured backend" do
    context = request_context()
    {:ok, subject_ref} = SubjectRef.new(%{id: "subject-1", subject_kind: "work_object"})

    assert {:ok, created_ref} =
             WorkSurface.ingest_subject(
               context,
               %{external_ref: "ENG-401"},
               work_query_backend: FakeWorkQueryBackend
             )

    assert {:ok, filter_set} = FilterSet.new(%{clauses: [], mode: :and})
    assert {:ok, page_request} = PageRequest.new(%{limit: 25, filters: filter_set})

    assert {:ok, page_result} =
             WorkSurface.list_subjects(
               context,
               page_request,
               work_query_backend: FakeWorkQueryBackend
             )

    assert {:ok, detail} =
             WorkSurface.get_subject(
               context,
               subject_ref,
               work_query_backend: FakeWorkQueryBackend
             )

    assert {:ok, projection_ref} =
             ProjectionRef.new(%{
               name: "review_queue",
               subject_ref: subject_ref
             })

    assert {:ok, projection} =
             WorkSurface.get_projection(
               context,
               projection_ref,
               work_query_backend: FakeWorkQueryBackend
             )

    assert {:ok, runtime_projection} =
             WorkSurface.get_runtime_projection(
               context,
               subject_ref,
               work_query_backend: FakeWorkQueryBackend
             )

    assert {:ok, stats} =
             WorkSurface.queue_stats(
               context,
               filter_set,
               work_query_backend: FakeWorkQueryBackend
             )

    assert created_ref.id == "subject/ENG-401"
    assert page_result.metadata.backend == :fake
    assert page_result.metadata.filter_mode == :and
    assert detail.subject_ref.id == "subject-1"
    assert projection.projection == "review_queue"

    assert hd(runtime_projection.source_bindings).source_ref ==
             "source://linear/tenant-1/subject-1"

    assert hd(runtime_projection.runtime.events).event_kind == "tool_call"
    assert stats.backend == :fake
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
