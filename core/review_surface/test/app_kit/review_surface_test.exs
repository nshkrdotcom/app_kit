defmodule AppKit.ReviewSurfaceTest do
  use ExUnit.Case, async: true

  defmodule FakeReviewBackend do
    @behaviour AppKit.Core.Backends.ReviewBackend

    alias AppKit.Core.{
      ActionResult,
      DecisionRef,
      DecisionSummary,
      PageRequest,
      PageResult,
      RequestContext
    }

    @impl true
    def list_pending(%RequestContext{} = _context, %PageRequest{} = _page_request, _opts) do
      with {:ok, decision_ref} <- DecisionRef.new(%{id: "dec-1", decision_kind: "approval"}),
           {:ok, summary} <-
             DecisionSummary.new(%{
               decision_ref: decision_ref,
               status: "pending",
               summary: "backend summary"
             }) do
        PageResult.new(%{
          entries: [summary],
          total_count: 1,
          has_more: false,
          metadata: %{backend: :fake}
        })
      end
    end

    @impl true
    def get_review(%RequestContext{} = _context, %DecisionRef{} = decision_ref, _opts) do
      {:ok, %{decision_ref: decision_ref, backend: :fake}}
    end

    @impl true
    def record_decision(%RequestContext{} = _context, %DecisionRef{} = decision_ref, attrs, _opts) do
      ActionResult.new(%{
        status: :completed,
        action_ref: %{
          id: "#{decision_ref.id}:accept",
          action_kind: "review_accept",
          subject_ref: decision_ref.subject_ref
        },
        message: Map.get(attrs, :reason),
        metadata: %{backend: :fake}
      })
    end
  end

  alias AppKit.Core.{DecisionRef, PageRequest, RequestContext, SubjectRef}
  alias AppKit.ReviewSurface

  test "delegates review listing, detail, and decision flows" do
    context = request_context()

    assert {:ok, page_request} = PageRequest.new(%{limit: 25})

    assert {:ok, page_result} =
             ReviewSurface.list_pending(
               context,
               page_request,
               review_backend: FakeReviewBackend
             )

    assert {:ok, subject_ref} = SubjectRef.new(%{id: "subject-1", subject_kind: "work_object"})

    assert {:ok, decision_ref} =
             DecisionRef.new(%{
               id: "dec-1",
               decision_kind: "approval",
               subject_ref: subject_ref
             })

    assert {:ok, review} =
             ReviewSurface.get_review(
               context,
               decision_ref,
               review_backend: FakeReviewBackend
             )

    assert {:ok, action_result} =
             ReviewSurface.record_decision(
               context,
               decision_ref,
               %{reason: "looks good"},
               review_backend: FakeReviewBackend
             )

    assert page_result.metadata.backend == :fake
    assert review.backend == :fake
    assert action_result.metadata.backend == :fake
    assert action_result.message == "looks good"
  end

  defp request_context do
    {:ok, context} =
      RequestContext.new(%{
        trace_id: "trace-review-surface",
        actor_ref: %{id: "reviewer-1", kind: :human},
        tenant_ref: %{id: "tenant-1"},
        metadata: %{program_id: "program-1"}
      })

    context
  end
end
