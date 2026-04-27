defmodule AppKit.Core.Conformance.BackendConformanceTest do
  use ExUnit.Case, async: true

  alias AppKit.Core.AgentIntake.RunOutcomeFuture
  alias AppKit.Core.Backends.{AgentIntakeBackendConformance, HeadlessBackendConformance}

  alias AppKit.Core.RuntimeReadback.{
    CommandResult,
    RuntimeRunDetail,
    RuntimeStateSnapshot,
    RuntimeSubjectDetail
  }

  defmodule HeadlessFixtureBackend do
    @behaviour AppKit.Core.Backends.HeadlessBackend

    def state_snapshot(_context, _request, _opts) do
      RuntimeStateSnapshot.new(%{
        tenant_ref: "tenant://fixture",
        installation_ref: "installation://fixture",
        rows: [
          %{
            subject_ref: "subject://fixture",
            run_ref: "run://fixture",
            state: :running,
            updated_at: "2026-04-27T00:00:00Z"
          }
        ]
      })
    end

    def runtime_subject_detail(_context, subject_ref, _request, _opts) do
      RuntimeSubjectDetail.new(%{subject_ref: subject_ref, events: fixture_events()})
    end

    def runtime_run_detail(_context, run_ref, _request, _opts) do
      RuntimeRunDetail.new(%{run_ref: run_ref, events: Enum.reverse(fixture_events())})
    end

    def request_runtime_refresh(_context, request, _opts) do
      CommandResult.new(%{
        command_ref: "command://#{request.idempotency_key}",
        command_kind: :refresh,
        accepted?: true,
        coalesced?: false,
        status: :accepted,
        workflow_effect_state: "pending_signal"
      })
    end

    def request_runtime_control(_context, request, _opts) do
      CommandResult.new(%{
        command_ref: "command://#{request.idempotency_key}",
        command_kind: request.action,
        accepted?: true,
        coalesced?: false,
        status: :accepted,
        workflow_effect_state: "pending_signal"
      })
    end

    defp fixture_events do
      [
        %{
          event_ref: "event://1",
          event_seq: 1,
          event_kind: :run_started,
          observed_at: "2026-04-27T00:00:00Z"
        },
        %{
          event_ref: "event://2",
          event_seq: 2,
          event_kind: "future_event",
          observed_at: "2026-04-27T00:00:01Z"
        }
      ]
    end
  end

  defmodule AgentUnavailableBackend do
    @behaviour AppKit.Core.Backends.AgentIntakeBackend

    def start_agent_run(_context, _request, _opts),
      do: {:error, :agent_turn_runtime_not_available}

    def submit_agent_turn(_context, _submission, _opts),
      do: {:error, :agent_turn_runtime_not_available}

    def cancel_agent_run(_context, _run_ref, _opts),
      do: {:error, :agent_turn_runtime_not_available}

    def await_agent_outcome(_context, _run_ref, _request, _opts),
      do: {:error, :agent_turn_runtime_not_available}
  end

  defmodule AgentAvailableBackend do
    @behaviour AppKit.Core.Backends.AgentIntakeBackend

    def start_agent_run(_context, request, _opts) do
      RunOutcomeFuture.new(%{
        run_ref: "run://fixture",
        workflow_ref: "workflow://fixture",
        accepted?: true,
        command_ref: "command://#{request.idempotency_key}",
        correlation_id: request.correlation_id
      })
    end

    def submit_agent_turn(_context, submission, _opts),
      do: command(submission.idempotency_key, :submit_turn)

    def cancel_agent_run(_context, _run_ref, _opts), do: command("cancel-run", :cancel)

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

  test "headless backend conformance suite passes for fixture backend" do
    fixtures = %{
      context: %{},
      subject_ref: "subject://fixture",
      run_ref: "run://fixture",
      refresh_request: HeadlessBackendConformance.fixture_refresh_request(),
      control_request: HeadlessBackendConformance.fixture_control_request()
    }

    assert :ok = HeadlessBackendConformance.assert_conforms!(HeadlessFixtureBackend, fixtures)
  end

  test "agent intake conformance suite passes for unavailable and available fixture backends" do
    fixtures = %{
      context: %{},
      run_ref: "run://fixture",
      agent_run_request: AgentIntakeBackendConformance.fixture_agent_run_request(),
      turn_submission: AgentIntakeBackendConformance.fixture_turn_submission()
    }

    assert :ok =
             AgentIntakeBackendConformance.assert_unavailable_conforms!(
               AgentUnavailableBackend,
               fixtures
             )

    assert :ok =
             AgentIntakeBackendConformance.assert_available_conforms!(
               AgentAvailableBackend,
               fixtures
             )
  end
end
