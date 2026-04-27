defmodule AppKit.HeadlessSurfaceAndAgentIntakeTest do
  use ExUnit.Case, async: true

  alias AppKit.Core.AgentIntake.RunOutcomeFuture

  alias AppKit.Core.RuntimeReadback.{
    CommandResult,
    RuntimeRunDetail,
    RuntimeStateSnapshot,
    RuntimeSubjectDetail
  }

  defmodule Backend do
    @behaviour AppKit.Core.Backends.HeadlessBackend
    @behaviour AppKit.Core.Backends.AgentIntakeBackend

    def state_snapshot(_context, _request, _opts),
      do:
        RuntimeStateSnapshot.new(%{
          tenant_ref: "tenant://one",
          installation_ref: "installation://one"
        })

    def runtime_subject_detail(_context, subject_ref, _request, _opts),
      do: RuntimeSubjectDetail.new(%{subject_ref: subject_ref})

    def runtime_run_detail(_context, run_ref, _request, _opts),
      do: RuntimeRunDetail.new(%{run_ref: run_ref})

    def request_runtime_refresh(_context, request, _opts),
      do: command(request.idempotency_key, :refresh)

    def request_runtime_control(_context, request, _opts),
      do: command(request.idempotency_key, request.action)

    def start_agent_run(_context, request, _opts) do
      RunOutcomeFuture.new(%{
        run_ref: "run://surface",
        accepted?: true,
        command_ref: "command://#{request.idempotency_key}",
        correlation_id: request.correlation_id
      })
    end

    def submit_agent_turn(_context, submission, _opts),
      do: command(submission.idempotency_key, :submit_turn)

    def cancel_agent_run(_context, _run_ref, _opts), do: command("cancel", :cancel)

    def await_agent_outcome(_context, run_ref, _request, _opts) do
      RunOutcomeFuture.new(%{
        run_ref: run_ref,
        accepted?: true,
        command_ref: "command://await",
        correlation_id: "corr://await"
      })
    end

    defp command(idempotency_key, kind) do
      CommandResult.new(%{
        command_ref: "command://#{idempotency_key}",
        command_kind: kind,
        accepted?: true,
        coalesced?: false,
        status: :accepted,
        workflow_effect_state: "pending_signal"
      })
    end
  end

  test "headless surface delegates through configured backend" do
    assert {:ok, %RuntimeStateSnapshot{tenant_ref: "tenant://one"}} =
             AppKit.HeadlessSurface.state_snapshot(%{}, %{}, backend: Backend)

    assert {:ok, %CommandResult{command_kind: :refresh}} =
             AppKit.HeadlessSurface.request_refresh(
               %{},
               %{idempotency_key: "refresh", actor_ref: "actor://one", scope_ref: "scope://one"},
               backend: Backend
             )
  end

  test "agent intake validates DTOs before delegating" do
    request = %{
      tenant_ref: "tenant://one",
      installation_ref: "installation://one",
      subject_ref: "subject://one",
      actor_ref: "actor://one",
      profile_bundle: %{
        source_profile_ref: :fixture_source,
        runtime_profile_ref: :fixture_runtime,
        tool_scope_ref: :fixture_tools,
        evidence_profile_ref: :fixture_evidence,
        publication_profile_ref: :none,
        review_profile_ref: :fixture_review,
        memory_profile_ref: :none,
        projection_profile_ref: :fixture_projection
      },
      tool_catalog_ref: "tool-catalog://one",
      budget_ref: "budget://one",
      recall_scope_ref: "recall://one",
      idempotency_key: "start",
      trace_id: "trace://one",
      correlation_id: "corr://one",
      submission_dedupe_key: "dedupe",
      initial_input_ref: "input://one"
    }

    assert {:ok, %RunOutcomeFuture{run_ref: "run://surface"}} =
             AppKit.AgentIntake.start_agent_run(%{}, request, backend: Backend)

    assert {:error, :invalid_agent_run_request} =
             AppKit.AgentIntake.start_agent_run(%{}, Map.put(request, :prompt, "raw"),
               backend: Backend
             )
  end
end
