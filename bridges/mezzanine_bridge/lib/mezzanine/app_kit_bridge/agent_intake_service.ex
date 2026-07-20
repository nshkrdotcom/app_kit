defmodule Mezzanine.AppKitBridge.AgentIntakeService do
  @moduledoc """
  Narrow bridge service for canonical durable agent-run acceptance and readback.

  The workflow-runtime store owns all mutations and projection truth. This
  module deliberately exposes no adapter selector: production always reaches
  the configured Postgres owner through `Mezzanine.WorkflowRuntime.Store`.
  """

  alias Mezzanine.WorkflowRuntime.Store

  @preserved_errors [
    :cursor_run_mismatch,
    :idempotency_conflict,
    :invalid_accept_command,
    :invalid_event_cursor,
    :not_found
  ]

  def accept_run(command, _opts \\ []), do: owner_call(fn -> Store.accept_run(command) end)

  def fetch_projection(run_ref, _opts \\ []) when is_binary(run_ref),
    do: owner_call(fn -> Store.fetch_projection(run_ref) end)

  def list_events(run_ref, cursor, opts \\ []) when is_binary(run_ref) and is_list(opts) do
    limit = Keyword.get(opts, :limit, 100)
    owner_call(fn -> Store.list_events(run_ref, cursor, limit: limit) end)
  end

  def read_cursor(run_ref, _opts \\ []) when is_binary(run_ref),
    do: owner_call(fn -> Store.read_cursor(run_ref) end)

  defp owner_call(fun) do
    case fun.() do
      {:ok, _value} = success -> success
      {:error, reason} when reason in @preserved_errors -> {:error, reason}
      {:error, _reason} -> {:error, :agent_run_owner_unavailable}
      _other -> {:error, :agent_run_owner_unavailable}
    end
  rescue
    _error -> {:error, :agent_run_owner_unavailable}
  catch
    :exit, _reason -> {:error, :agent_run_owner_unavailable}
  end
end
