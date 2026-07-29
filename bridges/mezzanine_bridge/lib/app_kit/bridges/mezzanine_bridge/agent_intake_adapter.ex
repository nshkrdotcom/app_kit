defmodule AppKit.Bridges.MezzanineBridge.AgentIntakeAdapter do
  @moduledoc false

  @behaviour AppKit.Core.Backends.AgentIntakeBackend

  alias AppKit.Bridges.MezzanineBridge.{
    AgentIntakeMapping,
    Errors,
    Services
  }

  alias AppKit.Core.AgentIntake.TurnSubmission
  alias AppKit.Core.RequestContext

  @impl true
  def start_agent_run(%RequestContext{} = context, request, opts) do
    with {:ok, command} <- AgentIntakeMapping.accept_command(context, request, opts),
         {:ok, acceptance} <- Services.agent_intake(opts).accept_run(command, opts),
         {:ok, future} <- AgentIntakeMapping.future(acceptance, request) do
      {:ok, future}
    else
      {:error, reason} -> Errors.normalize(reason)
    end
  end

  @impl true
  def submit_agent_turn(
        %RequestContext{} = context,
        %TurnSubmission{} = turn_submission,
        opts
      ) do
    with {:ok, command} <-
           AgentIntakeMapping.turn_command(context, turn_submission, opts),
         {:ok, acceptance} <- Services.agent_intake(opts).submit_turn(command, opts),
         {:ok, result} <-
           AgentIntakeMapping.turn_result(context, command, acceptance) do
      {:ok, result}
    else
      {:error, reason} -> Errors.normalize(reason)
    end
  end

  @impl true
  def cancel_agent_run(%RequestContext{} = context, run_ref, opts) do
    with {:ok, request} <- AgentIntakeMapping.cancel_request(context, run_ref, opts),
         {:ok, result} <- Services.work_control(opts).control_run(context, request, opts) do
      {:ok, result}
    else
      {:error, reason} -> Errors.normalize(reason)
    end
  end

  @impl true
  def await_agent_outcome(%RequestContext{} = context, run_ref, request, opts) do
    with {:ok, projection} <- Services.agent_intake(opts).fetch_projection(run_ref, opts),
         :ok <- AgentIntakeMapping.authorize_projection(context, run_ref, projection),
         {:ok, future} <- AgentIntakeMapping.future_from_projection(projection, request) do
      {:ok, future}
    else
      {:error, reason} -> Errors.normalize(reason)
    end
  end

  @impl true
  def catch_up_agent_events(%RequestContext{} = context, cursor, opts) do
    limit = AgentIntakeMapping.event_limit(opts)

    with :ok <- AgentIntakeMapping.authorize_cursor(context, cursor),
         {:ok, lower_cursor} <- AgentIntakeMapping.lower_cursor(cursor),
         {:ok, events} <-
           Services.agent_intake(opts).list_events(
             cursor.ledger_ref,
             lower_cursor,
             Keyword.put(opts, :limit, limit + 1)
           ),
         {:ok, page} <- AgentIntakeMapping.event_page(cursor, events, limit) do
      {:ok, page}
    else
      {:error, reason} -> Errors.normalize(reason)
    end
  end

  @impl true
  def list_pending_interactions(%RequestContext{}, _request, _opts),
    do: Errors.normalize(:agent_pending_interactions_not_available)
end
