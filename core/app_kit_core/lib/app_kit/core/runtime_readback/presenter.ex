defmodule AppKit.Core.RuntimeReadback.Presenter do
  @moduledoc "Pure presenter helpers for runtime readback DTOs."

  alias AppKit.Core.RuntimeReadback.{
    CommandResult,
    RuntimeRunDetail,
    RuntimeStateSnapshot,
    RuntimeSubjectDetail
  }

  def present(dto, opts \\ [])

  def present(%RuntimeStateSnapshot{} = snapshot, opts) do
    envelope(
      snapshot.schema_ref,
      snapshot.schema_version,
      RuntimeStateSnapshot.dump(snapshot),
      opts
    )
  end

  def present(%RuntimeSubjectDetail{} = detail, opts) do
    envelope(detail.schema_ref, detail.schema_version, RuntimeSubjectDetail.dump(detail), opts)
  end

  def present(%RuntimeRunDetail{} = detail, opts) do
    envelope(detail.schema_ref, detail.schema_version, RuntimeRunDetail.dump(detail), opts)
  end

  def present(%CommandResult{} = result, opts) do
    envelope("runtime_readback/command_result.v1", 1, CommandResult.dump(result), opts)
  end

  def error_envelope(code, message, opts \\ []) when is_binary(code) and is_binary(message) do
    %{
      "schema_ref" => "runtime_readback/error.v1",
      "schema_version" => 1,
      "generated_at" => Keyword.get(opts, :generated_at),
      "correlation_id" => Keyword.get(opts, :correlation_id),
      "error" => %{"code" => code, "message" => message}
    }
  end

  def page(page_size, cursor \\ nil, total_entries \\ 0) do
    %{"page_size" => page_size, "cursor" => cursor, "total_entries" => total_entries}
  end

  defp envelope(schema_ref, schema_version, data, opts) do
    %{
      "schema_ref" => schema_ref,
      "schema_version" => schema_version,
      "generated_at" => Keyword.get(opts, :generated_at),
      "correlation_id" => Keyword.get(opts, :correlation_id),
      "data" => data
    }
  end
end

defmodule AppKit.Core.RuntimeReadback.CommandReconciliation do
  @moduledoc """
  Documents and constrains `:database_first` command reconciliation.

  A command is first persisted as a `CommandResult` with
  `workflow_effect_state: "pending_signal"`. A relay then delivers the workflow
  signal/update idempotently. Runtime readback only reports the user-visible
  state transition after reducers observe lower workflow facts and move the
  command to `applied`, `signal_rejected`, `timed_out`, or another terminal
  command state.

  The relay/sweeper must rescan stale `pending_signal` rows. Closed workflows,
  continued-as-new attempts, and invalid workflow state are terminal delivery
  failures and are recorded as `signal_rejected` with a bounded reason.
  """

  @terminal_effect_states ~w[applied rejected_by_authority signal_rejected timed_out not_available]
  @bounded_signal_rejection_reasons AppKit.Core.RuntimeReadback.CommandResult.terminal_signal_rejection_reasons()

  def terminal_effect_states, do: @terminal_effect_states
  def bounded_signal_rejection_reasons, do: @bounded_signal_rejection_reasons

  def terminal?(state), do: to_string(state) in @terminal_effect_states
  def stale_pending?(%{workflow_effect_state: "pending_signal"}), do: true
  def stale_pending?(%{workflow_effect_state: :pending_signal}), do: true
  def stale_pending?(_command_result), do: false

  def terminal_signal_rejected(command_attrs, reason)
      when reason in @bounded_signal_rejection_reasons do
    command_attrs
    |> Map.new()
    |> Map.merge(%{
      workflow_effect_state: "signal_rejected",
      status: :rejected,
      accepted?: false,
      terminal_reason: reason
    })
  end
end
