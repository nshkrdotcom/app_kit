defmodule AppKit.Core.RuntimeReadback.CommandResult do
  @moduledoc """
  Synchronous AppKit command acknowledgement.

  M1 controls default to `:database_first`: the command row is durable and the
  workflow effect starts as `pending_signal` until a reducer confirms a terminal
  effect such as `applied`, `signal_rejected`, or `timed_out`.
  """

  alias AppKit.Core.PersistencePosture
  alias AppKit.Core.RuntimeReadback.{Diagnostic, Support}

  @command_kinds [
    :refresh,
    :pause,
    :resume,
    :cancel,
    :retry,
    :rework,
    :read_lease,
    :stream_attach_lease,
    :review_decision,
    :inspect_trace,
    :inspect_memory_proof,
    :submit_turn,
    "refresh",
    "pause",
    "resume",
    "cancel",
    "retry",
    "rework",
    "read_lease",
    "stream_attach_lease",
    "review_decision",
    "inspect_trace",
    "inspect_memory_proof",
    "submit_turn"
  ]
  @workflow_effect_states ~w[pending_signal applied rejected_by_authority queued_signal signal_delivered signal_rejected timed_out unknown not_available]
  @terminal_rejection_reasons ~w[workflow_closed continued_as_new invalid_state authority_denied unavailable]

  @enforce_keys [
    :command_ref,
    :command_kind,
    :accepted?,
    :coalesced?,
    :status,
    :workflow_effect_state
  ]
  defstruct [
    :command_ref,
    :command_kind,
    :accepted?,
    :coalesced?,
    :status,
    :authority_state,
    :authority_refs,
    :workflow_effect_state,
    :projection_state,
    :trace_id,
    :correlation_id,
    :receipt_ref,
    :idempotency_key,
    :message,
    :terminal_reason,
    persistence_posture: PersistencePosture.memory(:runtime_projection),
    diagnostics: []
  ]

  def terminal_signal_rejection_reasons, do: @terminal_rejection_reasons

  def new(%__MODULE__{} = value), do: {:ok, value}

  def new(attrs) do
    with {:ok, attrs, nil} <- Support.normalize(attrs),
         :ok <- Support.reject_selectors(attrs, :invalid_command_result),
         command_ref when is_binary(command_ref) <- Support.required(attrs, :command_ref),
         true <- Support.safe_ref?(command_ref),
         command_kind <- Support.required(attrs, :command_kind),
         true <- command_kind in @command_kinds,
         accepted? <- Support.required(attrs, :accepted?),
         true <- is_boolean(accepted?),
         coalesced? <- Support.required(attrs, :coalesced?),
         true <- is_boolean(coalesced?),
         status <- Support.required(attrs, :status),
         true <- Support.atomish?(status),
         authority_state <- Support.optional(attrs, :authority_state),
         true <- Support.optional_atomish?(authority_state),
         authority_refs <- Support.optional(attrs, :authority_refs, []),
         true <- is_list(authority_refs) and Enum.all?(authority_refs, &Support.safe_ref?/1),
         workflow_effect_state <- Support.required(attrs, :workflow_effect_state),
         true <- workflow_state?(workflow_effect_state),
         projection_state <- Support.optional(attrs, :projection_state),
         true <- Support.optional_atomish?(projection_state),
         trace_id <- Support.optional(attrs, :trace_id),
         true <- Support.optional_ref?(trace_id),
         correlation_id <- Support.optional(attrs, :correlation_id),
         true <- Support.optional_ref?(correlation_id),
         receipt_ref <- Support.optional(attrs, :receipt_ref),
         true <- Support.optional_ref?(receipt_ref),
         idempotency_key <- Support.optional(attrs, :idempotency_key),
         true <- is_nil(idempotency_key) or Support.present_binary?(idempotency_key),
         message <- Support.optional(attrs, :message),
         true <- is_nil(message) or is_binary(message),
         terminal_reason <- Support.optional(attrs, :terminal_reason),
         true <- terminal_reason?(workflow_effect_state, terminal_reason),
         persistence_posture <- Support.persistence_posture(attrs),
         {:ok, diagnostics} <-
           Support.nested_list(Support.optional(attrs, :diagnostics, []), Diagnostic) do
      {:ok,
       %__MODULE__{
         command_ref: command_ref,
         command_kind: command_kind,
         accepted?: accepted?,
         coalesced?: coalesced?,
         status: status,
         authority_state: authority_state,
         authority_refs: authority_refs,
         workflow_effect_state: to_string(workflow_effect_state),
         projection_state: projection_state,
         trace_id: trace_id,
         correlation_id: correlation_id,
         receipt_ref: receipt_ref,
         idempotency_key: idempotency_key,
         message: message,
         terminal_reason: terminal_reason,
         persistence_posture: persistence_posture,
         diagnostics: diagnostics
       }}
    else
      _ -> {:error, :invalid_command_result}
    end
  end

  def dump(%__MODULE__{} = value), do: Support.dump_struct(value)

  defp workflow_state?(value), do: to_string(value) in @workflow_effect_states

  defp terminal_reason?("signal_rejected", reason),
    do: is_binary(reason) and reason in @terminal_rejection_reasons

  defp terminal_reason?(:signal_rejected, reason), do: terminal_reason?("signal_rejected", reason)
  defp terminal_reason?(_state, nil), do: true
  defp terminal_reason?(_state, _reason), do: false
end
