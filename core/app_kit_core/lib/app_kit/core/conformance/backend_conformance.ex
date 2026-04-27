defmodule AppKit.Core.Backends.HeadlessBackendConformance do
  @moduledoc "Reusable conformance checks for `AppKit.Core.Backends.HeadlessBackend`."

  alias AppKit.Core.RuntimeReadback.{
    CommandResult,
    ControlRequest,
    RefreshRequest,
    RuntimeEventRow,
    RuntimeRunDetail,
    RuntimeStateSnapshot,
    RuntimeSubjectDetail
  }

  def assert_conforms!(backend, fixtures) do
    context = Map.fetch!(fixtures, :context)

    with {:ok, %RuntimeStateSnapshot{}} <-
           backend.state_snapshot(context, Map.get(fixtures, :snapshot_request, %{}), []),
         {:ok, %RuntimeSubjectDetail{}} <-
           backend.runtime_subject_detail(
             context,
             Map.fetch!(fixtures, :subject_ref),
             Map.get(fixtures, :subject_request, %{}),
             []
           ),
         {:ok, %RuntimeRunDetail{events: events}} <-
           backend.runtime_run_detail(
             context,
             Map.fetch!(fixtures, :run_ref),
             Map.get(fixtures, :run_request, %{}),
             []
           ),
         true <- ordered_events?(events),
         {:ok, %CommandResult{workflow_effect_state: "pending_signal"}} <-
           backend.request_runtime_refresh(context, Map.fetch!(fixtures, :refresh_request), []),
         {:ok, %CommandResult{}} <-
           backend.request_runtime_control(context, Map.fetch!(fixtures, :control_request), []) do
      :ok
    else
      false ->
        raise ArgumentError, "headless backend returned unordered runtime events"

      {:error, reason} ->
        raise ArgumentError, "headless backend conformance failed: #{inspect(reason)}"

      other ->
        raise ArgumentError, "headless backend conformance failed: #{inspect(other)}"
    end
  end

  def fixture_refresh_request(attrs \\ %{}) do
    RefreshRequest.new!(
      Map.merge(
        %{
          idempotency_key: "idem-refresh",
          actor_ref: "actor://fixture",
          scope_ref: "scope://fixture"
        },
        attrs
      )
    )
  end

  def fixture_control_request(attrs \\ %{}) do
    ControlRequest.new!(
      Map.merge(
        %{
          idempotency_key: "idem-control",
          actor_ref: "actor://fixture",
          action: :pause,
          run_ref: "run://fixture"
        },
        attrs
      )
    )
  end

  defp ordered_events?(events), do: events == Enum.sort_by(events, &RuntimeEventRow.sort_key/1)
end

defmodule AppKit.Core.Backends.AgentIntakeBackendConformance do
  @moduledoc "Reusable conformance checks for `AppKit.Core.Backends.AgentIntakeBackend`."

  alias AppKit.Core.AgentIntake.{AgentRunRequest, RunOutcomeFuture, TurnSubmission}
  alias AppKit.Core.RuntimeReadback.CommandResult

  def assert_unavailable_conforms!(backend, fixtures) do
    context = Map.fetch!(fixtures, :context)

    with {:error, :agent_turn_runtime_not_available} <-
           backend.start_agent_run(context, Map.fetch!(fixtures, :agent_run_request), []),
         {:error, :agent_turn_runtime_not_available} <-
           backend.submit_agent_turn(context, Map.fetch!(fixtures, :turn_submission), []),
         {:error, :agent_turn_runtime_not_available} <-
           backend.cancel_agent_run(context, Map.fetch!(fixtures, :run_ref), []),
         {:error, :agent_turn_runtime_not_available} <-
           backend.await_agent_outcome(context, Map.fetch!(fixtures, :run_ref), %{}, []) do
      :ok
    else
      other ->
        raise ArgumentError, "agent intake unavailable conformance failed: #{inspect(other)}"
    end
  end

  def assert_available_conforms!(backend, fixtures) do
    context = Map.fetch!(fixtures, :context)

    with {:ok, %RunOutcomeFuture{}} <-
           backend.start_agent_run(context, Map.fetch!(fixtures, :agent_run_request), []),
         {:ok, %CommandResult{}} <-
           backend.submit_agent_turn(context, Map.fetch!(fixtures, :turn_submission), []),
         {:ok, %CommandResult{}} <-
           backend.cancel_agent_run(context, Map.fetch!(fixtures, :run_ref), []),
         {:ok, %RunOutcomeFuture{}} <-
           backend.await_agent_outcome(context, Map.fetch!(fixtures, :run_ref), %{}, []) do
      :ok
    else
      other -> raise ArgumentError, "agent intake available conformance failed: #{inspect(other)}"
    end
  end

  def fixture_agent_run_request(attrs \\ %{}) do
    AgentRunRequest.new!(
      Map.merge(
        %{
          tenant_ref: "tenant://fixture",
          installation_ref: "installation://fixture",
          subject_ref: "subject://fixture",
          actor_ref: "actor://fixture",
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
          tool_catalog_ref: "tool-catalog://fixture",
          budget_ref: "budget://fixture",
          recall_scope_ref: "recall://fixture",
          idempotency_key: "idem-agent-run",
          trace_id: "trace://fixture",
          correlation_id: "corr://fixture",
          submission_dedupe_key: "dedupe-agent-run",
          initial_input_ref: "input://fixture"
        },
        attrs
      )
    )
  end

  def fixture_turn_submission(attrs \\ %{}) do
    TurnSubmission.new!(
      Map.merge(
        %{
          idempotency_key: "idem-turn",
          actor_ref: "actor://fixture",
          run_ref: "run://fixture",
          kind: :user_input,
          payload_ref: "payload://fixture"
        },
        attrs
      )
    )
  end
end
