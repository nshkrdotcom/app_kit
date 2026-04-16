defmodule AppKit.WorkControlTest do
  use ExUnit.Case, async: true

  defmodule FakeWorkBackend do
    @behaviour AppKit.Core.Backends.WorkBackend

    alias AppKit.Core.{ActionResult, RequestContext, Result, RunRef, RunRequest}

    @impl true
    def start_run(domain_call, opts) do
      Result.new(%{
        surface: :work_control,
        state: :scheduled,
        payload: %{backend: :fake, domain_call: domain_call, opts: Enum.into(opts, %{})}
      })
    end

    @impl true
    def start_run(%RequestContext{} = context, %RunRequest{} = run_request, opts) do
      Result.new(%{
        surface: :work_control,
        state: :scheduled,
        payload: %{
          backend: :fake,
          trace_id: context.trace_id,
          subject_id: run_request.subject_ref.id,
          recipe_ref: run_request.recipe_ref,
          opts: Enum.into(opts, %{})
        }
      })
    end

    @impl true
    def retry_run(%RequestContext{} = context, %RunRef{} = run_ref, opts) do
      ActionResult.new(%{
        status: :accepted,
        action_ref: %{id: "#{run_ref.run_id}:retry", action_kind: "retry"},
        message: context.trace_id,
        metadata: %{opts: Enum.into(opts, %{})}
      })
    end

    @impl true
    def cancel_run(%RequestContext{} = _context, %RunRef{} = run_ref, _opts) do
      ActionResult.new(%{
        status: :completed,
        action_ref: %{id: "#{run_ref.run_id}:cancel", action_kind: "cancel"},
        message: "cancelled"
      })
    end
  end

  alias AppKit.Core.{RequestContext, RunRef, RunRequest}
  alias AppKit.WorkControl

  test "starts a governed run from a domain call" do
    assert {:ok, result} =
             WorkControl.start_run(
               %{route_name: :compile_workspace, scope_id: "workspace/main"},
               review_required: true
             )

    assert result.state == :waiting_review
  end

  test "delegates to a configured backend" do
    assert {:ok, result} =
             WorkControl.start_run(
               %{route_name: :compile_workspace, scope_id: "workspace/main"},
               work_backend: FakeWorkBackend,
               target: :custom
             )

    assert result.payload.backend == :fake
    assert result.payload.domain_call.route_name == :compile_workspace
    assert result.payload.opts.target == :custom
  end

  test "starts, retries, and cancels through the widened typed work-control contract" do
    context = request_context()
    run_request = run_request()

    assert {:ok, started} =
             WorkControl.start_run(
               context,
               run_request,
               work_backend: FakeWorkBackend,
               target: :custom
             )

    assert started.payload.trace_id == context.trace_id
    assert started.payload.subject_id == "subj-1"

    assert {:ok, run_ref} = RunRef.new(%{run_id: "run-1", scope_id: "program/program-1"})

    assert {:ok, retried} =
             WorkControl.retry_run(
               context,
               run_ref,
               work_backend: FakeWorkBackend,
               attempt: 2
             )

    assert {:ok, cancelled} =
             WorkControl.cancel_run(context, run_ref, work_backend: FakeWorkBackend)

    assert retried.action_ref.action_kind == "retry"
    assert retried.message == context.trace_id
    assert cancelled.action_ref.action_kind == "cancel"
  end

  defp request_context do
    {:ok, context} =
      RequestContext.new(%{
        trace_id: "trace-work-control",
        actor_ref: %{id: "user-1", kind: :human},
        tenant_ref: %{id: "tenant-1"},
        metadata: %{program_id: "program-1"}
      })

    context
  end

  defp run_request do
    {:ok, run_request} =
      RunRequest.new(%{
        subject_ref: %{id: "subj-1", subject_kind: "expense_request"},
        recipe_ref: "expense_capture",
        params: %{"priority" => "high"}
      })

    run_request
  end
end
