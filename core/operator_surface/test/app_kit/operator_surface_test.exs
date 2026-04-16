defmodule AppKit.OperatorSurfaceTest do
  use ExUnit.Case, async: true

  defmodule FakeOperatorBackend do
    @behaviour AppKit.Core.Backends.OperatorBackend

    alias AppKit.Core.{
      ActionResult,
      OperatorAction,
      OperatorProjection,
      RequestContext,
      RunRef,
      SubjectRef,
      TimelineEvent,
      UnifiedTrace
    }

    @impl true
    def run_status(%RunRef{} = run_ref, attrs, _opts) do
      {:ok, %{run_id: run_ref.run_id, backend: :fake, attrs: attrs}}
    end

    @impl true
    def review_run(%RunRef{} = run_ref, evidence_attrs, opts) do
      {:ok,
       %{
         backend: :fake,
         run_id: run_ref.run_id,
         evidence_attrs: evidence_attrs,
         reason: Keyword.get(opts, :reason)
       }}
    end

    @impl true
    def subject_status(%RequestContext{} = context, %SubjectRef{} = subject_ref, _opts) do
      OperatorProjection.new(%{
        subject_ref: subject_ref,
        lifecycle_state: "processing",
        current_execution_ref: %{id: "exec-1", dispatch_state: :accepted},
        available_actions: [
          %{
            action_ref: %{
              id: "#{subject_ref.id}:pause",
              action_kind: "pause",
              subject_ref: subject_ref
            },
            label: "Pause"
          }
        ],
        payload: %{trace_id: context.trace_id}
      })
    end

    @impl true
    def timeline(%RequestContext{} = _context, %SubjectRef{} = _subject_ref, _opts) do
      {:ok,
       [
         TimelineEvent.new!(%{
           ref: "evt-1",
           event_kind: "run_scheduled",
           occurred_at: ~U[2026-04-18 12:00:00Z],
           summary: "Run scheduled"
         })
       ]}
    end

    @impl true
    def get_unified_trace(%RequestContext{} = context, execution_ref, _opts) do
      UnifiedTrace.new(%{
        trace_id: context.trace_id,
        join_keys: %{"execution_id" => execution_ref.id},
        steps: [
          %{
            ref: "step-1",
            source: "execution_record",
            occurred_at: ~U[2026-04-18 12:05:00Z],
            trace_id: context.trace_id,
            freshness: "lower_authoritative_unreconciled",
            operator_actionable?: false,
            diagnostic?: false,
            payload: %{"dispatch_state" => "dispatching"}
          }
        ]
      })
    end

    @impl true
    def available_actions(%RequestContext{} = _context, %SubjectRef{} = subject_ref, _opts) do
      {:ok,
       [
         OperatorAction.new!(%{
           action_ref: %{
             id: "#{subject_ref.id}:cancel",
             action_kind: "cancel",
             subject_ref: subject_ref
           },
           label: "Cancel",
           dangerous?: true,
           requires_confirmation?: true
         })
       ]}
    end

    @impl true
    def apply_action(
          %RequestContext{} = _context,
          %SubjectRef{} = _subject_ref,
          action_request,
          _opts
        ) do
      ActionResult.new(%{
        status: :completed,
        action_ref: action_request.action_ref,
        message: "action applied"
      })
    end
  end

  alias AppKit.Core.{OperatorActionRequest, RequestContext, RunRef, SubjectRef}
  alias AppKit.OperatorSurface

  test "projects run status and review output" do
    assert {:ok, run_ref} = RunRef.new(%{run_id: "run-1", scope_id: "workspace/main"})

    assert {:ok, projection} =
             OperatorSurface.run_status(run_ref, %{
               route_name: :compile_workspace,
               state: :waiting_review
             })

    assert {:ok, review} =
             OperatorSurface.review_run(run_ref, %{kind: :operator_note, summary: "looks good"})

    assert projection.run_id == "run-1"
    assert review.decision.state == :approved
  end

  test "delegates projection and review through a configured backend" do
    assert {:ok, run_ref} = RunRef.new(%{run_id: "run-2", scope_id: "workspace/main"})

    assert {:ok, projection} =
             OperatorSurface.run_status(
               run_ref,
               %{route_name: :compile_workspace},
               operator_backend: FakeOperatorBackend
             )

    assert {:ok, review} =
             OperatorSurface.review_run(
               run_ref,
               %{kind: :operator_note, summary: "needs context"},
               operator_backend: FakeOperatorBackend,
               reason: "operator requested detail"
             )

    assert projection.backend == :fake
    assert review.backend == :fake
    assert review.reason == "operator requested detail"
  end

  test "projects subject status, timeline, unified trace, actions, and action application" do
    context = request_context()
    subject_ref = subject_ref()

    assert {:ok, projection} =
             OperatorSurface.subject_status(
               context,
               subject_ref,
               operator_backend: FakeOperatorBackend
             )

    assert {:ok, timeline} =
             OperatorSurface.timeline(
               context,
               subject_ref,
               operator_backend: FakeOperatorBackend
             )

    assert {:ok, actions} =
             OperatorSurface.available_actions(
               context,
               subject_ref,
               operator_backend: FakeOperatorBackend
             )

    assert {:ok, action_request} =
             OperatorActionRequest.new(%{
               action_ref: hd(actions).action_ref,
               params: %{"reason" => "needs manual stop"}
             })

    assert {:ok, action_result} =
             OperatorSurface.apply_action(
               context,
               subject_ref,
               action_request,
               operator_backend: FakeOperatorBackend
             )

    assert {:ok, trace} =
             OperatorSurface.get_unified_trace(
               context,
               projection.current_execution_ref,
               operator_backend: FakeOperatorBackend
             )

    assert projection.payload.trace_id == context.trace_id
    assert hd(timeline).event_kind == "run_scheduled"
    assert hd(actions).action_ref.action_kind == "cancel"
    assert action_result.action_ref.action_kind == "cancel"
    assert hd(trace.steps).source == "execution_record"
  end

  defp request_context do
    {:ok, context} =
      RequestContext.new(%{
        trace_id: "trace-operator-surface",
        actor_ref: %{id: "user-1", kind: :human},
        tenant_ref: %{id: "tenant-1"},
        installation_ref: %{id: "inst-1", pack_slug: "expense_approval", status: :active}
      })

    context
  end

  defp subject_ref do
    {:ok, subject_ref} =
      SubjectRef.new(%{
        id: "subj-1",
        subject_kind: "expense_request"
      })

    subject_ref
  end
end
