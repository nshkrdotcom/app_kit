defmodule AppKit.Core.RuntimeReadback.Support do
  @moduledoc false

  alias AppKit.Core.Substrate.{Dump, Support}

  @type error :: {:error, atom()}

  def normalize(%module{} = value), do: {:ok, value, module}

  def normalize(attrs) do
    case Support.normalize_attrs(attrs) do
      {:ok, attrs} -> {:ok, attrs, nil}
      {:error, _reason} -> {:error, :invalid_attrs}
    end
  end

  def reject_selectors(attrs, reason), do: Support.reject_selectors(attrs, reason)
  def required(attrs, key), do: Support.required(attrs, key)
  def optional(attrs, key, default \\ nil), do: Support.optional(attrs, key, default)

  def present_binary?(value), do: is_binary(value) and String.trim(value) != ""
  def safe_ref?(value), do: Support.safe_ref?(value)
  def optional_ref?(nil), do: true
  def optional_ref?(value), do: safe_ref?(value)
  def optional_map?(nil), do: true
  def optional_map?(value), do: is_map(value)
  def optional_list?(nil), do: true
  def optional_list?(value), do: is_list(value)
  def bool?(value), do: is_boolean(value)
  def optional_bool?(nil), do: true
  def optional_bool?(value), do: is_boolean(value)
  def non_neg_integer?(value), do: is_integer(value) and value >= 0
  def optional_non_neg_integer?(nil), do: true
  def optional_non_neg_integer?(value), do: non_neg_integer?(value)
  def timestamp?(%DateTime{}), do: true
  def timestamp?(value), do: present_binary?(value)
  def optional_timestamp?(nil), do: true
  def optional_timestamp?(value), do: timestamp?(value)

  def atomish?(value), do: is_atom(value) or present_binary?(value)
  def optional_atomish?(nil), do: true
  def optional_atomish?(value), do: atomish?(value)

  def nested(nil, _module), do: {:ok, nil}
  def nested(%module{} = value, module), do: {:ok, value}
  def nested(value, module) when is_map(value) or is_list(value), do: module.new(value)
  def nested(_value, _module), do: {:error, :invalid_nested}

  def nested_list(nil, _module), do: {:ok, []}

  def nested_list(values, module) when is_list(values) do
    Enum.reduce_while(values, {:ok, []}, fn value, {:ok, acc} ->
      case nested(value, module) do
        {:ok, nil} -> {:halt, {:error, :invalid_nested}}
        {:ok, struct} -> {:cont, {:ok, [struct | acc]}}
        {:error, _reason} -> {:halt, {:error, :invalid_nested}}
      end
    end)
    |> case do
      {:ok, values} -> {:ok, Enum.reverse(values)}
      error -> error
    end
  end

  def nested_list(_values, _module), do: {:error, :invalid_nested}

  def dump_struct(%_{} = value) do
    value
    |> Map.from_struct()
    |> Dump.dump_value()
    |> Dump.drop_nil_values()
  end
end

defmodule AppKit.Core.RuntimeReadback.SessionRef do
  @moduledoc "Opaque runtime session ref for public readback DTOs."

  alias AppKit.Core.RuntimeReadback.Support

  @enforce_keys [:id]
  defstruct [:id, :kind, metadata: %{}]

  def new(%__MODULE__{} = value), do: {:ok, value}

  def new(attrs) when is_binary(attrs), do: new(%{id: attrs})

  def new(attrs) do
    with {:ok, attrs, nil} <- Support.normalize(attrs),
         :ok <- Support.reject_selectors(attrs, :invalid_session_ref),
         id when is_binary(id) <- Support.required(attrs, :id),
         true <- Support.safe_ref?(id),
         kind <- Support.optional(attrs, :kind),
         true <- Support.optional_atomish?(kind),
         metadata <- Support.optional(attrs, :metadata, %{}),
         true <- is_map(metadata) do
      {:ok, %__MODULE__{id: id, kind: kind, metadata: metadata}}
    else
      _ -> {:error, :invalid_session_ref}
    end
  end

  def new!(attrs), do: new(attrs) |> bang()
  def dump(%__MODULE__{} = value), do: Support.dump_struct(value)
  defp bang({:ok, value}), do: value
  defp bang({:error, reason}), do: raise(ArgumentError, Atom.to_string(reason))
end

defmodule AppKit.Core.RuntimeReadback.WorkspaceRef do
  @moduledoc "Workspace identity for public readback DTOs. Raw paths are never exposed."

  alias AppKit.Core.RuntimeReadback.Support

  @enforce_keys [:id, :path_redacted?]
  defstruct [:id, :display_label, :path_redacted?, metadata: %{}]

  def new(%__MODULE__{} = value), do: {:ok, value}

  def new(attrs) when is_binary(attrs), do: new(%{id: attrs, path_redacted?: true})

  def new(attrs) do
    with {:ok, attrs, nil} <- Support.normalize(attrs),
         :ok <- Support.reject_selectors(attrs, :invalid_workspace_ref),
         id when is_binary(id) <- Support.required(attrs, :id),
         true <- Support.safe_ref?(id),
         true <- Support.required(attrs, :path_redacted?),
         label <- Support.optional(attrs, :display_label),
         true <- is_nil(label) or is_binary(label),
         metadata <- Support.optional(attrs, :metadata, %{}),
         true <- is_map(metadata) do
      {:ok, %__MODULE__{id: id, display_label: label, path_redacted?: true, metadata: metadata}}
    else
      _ -> {:error, :invalid_workspace_ref}
    end
  end

  def new!(attrs), do: new(attrs) |> bang()
  def dump(%__MODULE__{} = value), do: Support.dump_struct(value)
  defp bang({:ok, value}), do: value
  defp bang({:error, reason}), do: raise(ArgumentError, Atom.to_string(reason))
end

defmodule AppKit.Core.RuntimeReadback.Diagnostic do
  @moduledoc "Operator-safe runtime diagnostic DTO."

  alias AppKit.Core.RuntimeReadback.Support

  @severity_atoms [:debug, :info, :warning, :error]
  @severity_lookup Map.new(@severity_atoms, &{Atom.to_string(&1), &1})
  defstruct [:severity, :code, :message, :source_ref, :trace_ref, :semantic_failure_ref]

  def new(%__MODULE__{} = value), do: {:ok, value}

  def new(attrs) do
    with {:ok, attrs, nil} <- Support.normalize(attrs),
         :ok <- Support.reject_selectors(attrs, :invalid_diagnostic),
         {:ok, severity} <- normalize_severity(Support.optional(attrs, :severity, :info)),
         code <- Support.optional(attrs, :code),
         true <- is_nil(code) or Support.present_binary?(code),
         message <- Support.optional(attrs, :message),
         true <- is_nil(message) or is_binary(message),
         source_ref <- Support.optional(attrs, :source_ref),
         true <- Support.optional_ref?(source_ref),
         trace_ref <- Support.optional(attrs, :trace_ref),
         true <- Support.optional_ref?(trace_ref),
         semantic_failure_ref <- Support.optional(attrs, :semantic_failure_ref),
         true <- Support.optional_ref?(semantic_failure_ref) do
      {:ok,
       %__MODULE__{
         severity: severity,
         code: code,
         message: message,
         source_ref: source_ref,
         trace_ref: trace_ref,
         semantic_failure_ref: semantic_failure_ref
       }}
    else
      _ -> {:error, :invalid_diagnostic}
    end
  end

  def dump(%__MODULE__{} = value), do: Support.dump_struct(value)

  defp normalize_severity(value) when is_atom(value) do
    if value in @severity_atoms do
      {:ok, value}
    else
      :error
    end
  end

  defp normalize_severity(value) when is_binary(value), do: Map.fetch(@severity_lookup, value)
  defp normalize_severity(_value), do: :error
end

defmodule AppKit.Core.RuntimeReadback.TokenTotals do
  @moduledoc "Token aggregate readback without provider payloads."

  alias AppKit.Core.RuntimeReadback.Support

  defstruct total_input_tokens: 0,
            total_output_tokens: 0,
            total_tokens: 0,
            cached_input_tokens: 0,
            source: nil

  def new(%__MODULE__{} = value), do: {:ok, value}

  def new(attrs) do
    with {:ok, attrs, nil} <- Support.normalize(attrs),
         :ok <- Support.reject_selectors(attrs, :invalid_token_totals),
         input <- Support.optional(attrs, :total_input_tokens, 0),
         true <- Support.non_neg_integer?(input),
         output <- Support.optional(attrs, :total_output_tokens, 0),
         true <- Support.non_neg_integer?(output),
         total <- Support.optional(attrs, :total_tokens, input + output),
         true <- Support.non_neg_integer?(total),
         cached <- Support.optional(attrs, :cached_input_tokens, 0),
         true <- Support.non_neg_integer?(cached),
         source <- Support.optional(attrs, :source),
         true <- Support.optional_ref?(source) do
      {:ok,
       %__MODULE__{
         total_input_tokens: input,
         total_output_tokens: output,
         total_tokens: total,
         cached_input_tokens: cached,
         source: source
       }}
    else
      _ -> {:error, :invalid_token_totals}
    end
  end

  def dump(%__MODULE__{} = value), do: Support.dump_struct(value)
end

defmodule AppKit.Core.RuntimeReadback.RateLimitSnapshot do
  @moduledoc "Bounded rate-limit readback DTO."

  alias AppKit.Core.RuntimeReadback.Support

  @enforce_keys [:limit_id, :remaining]
  defstruct [:limit_id, :name, :remaining, :reset_at, :window, :source_event_ref]

  def new(%__MODULE__{} = value), do: {:ok, value}

  def new(attrs) do
    with {:ok, attrs, nil} <- Support.normalize(attrs),
         :ok <- Support.reject_selectors(attrs, :invalid_rate_limit_snapshot),
         limit_id when is_binary(limit_id) <- Support.required(attrs, :limit_id),
         true <- Support.safe_ref?(limit_id),
         name <- Support.optional(attrs, :name),
         true <- is_nil(name) or is_binary(name),
         remaining <- Support.required(attrs, :remaining),
         true <- Support.non_neg_integer?(remaining),
         reset_at <- Support.optional(attrs, :reset_at),
         true <- Support.optional_timestamp?(reset_at),
         window <- Support.optional(attrs, :window),
         true <- is_nil(window) or is_binary(window),
         source_event_ref <- Support.optional(attrs, :source_event_ref),
         true <- Support.optional_ref?(source_event_ref) do
      {:ok,
       %__MODULE__{
         limit_id: limit_id,
         name: name,
         remaining: remaining,
         reset_at: reset_at,
         window: window,
         source_event_ref: source_event_ref
       }}
    else
      _ -> {:error, :invalid_rate_limit_snapshot}
    end
  end

  def dump(%__MODULE__{} = value), do: Support.dump_struct(value)
end

defmodule AppKit.Core.RuntimeReadback.PollingState do
  @moduledoc "Explicit polling readback state used by headless hosts."

  alias AppKit.Core.RuntimeReadback.Support

  @enforce_keys [:checking?, :poll_interval_ms, :staleness_ms]
  defstruct [
    :checking?,
    :next_poll_at,
    :poll_interval_ms,
    :last_refresh_command_ref,
    :staleness_ms
  ]

  def new(%__MODULE__{} = value), do: {:ok, value}

  def new(attrs) do
    with {:ok, attrs, nil} <- Support.normalize(attrs),
         :ok <- Support.reject_selectors(attrs, :invalid_polling_state),
         checking? <- Support.required(attrs, :checking?),
         true <- Support.bool?(checking?),
         next_poll_at <- Support.optional(attrs, :next_poll_at),
         true <- Support.optional_timestamp?(next_poll_at),
         poll_interval_ms <- Support.required(attrs, :poll_interval_ms),
         true <- Support.non_neg_integer?(poll_interval_ms),
         last_refresh_command_ref <- Support.optional(attrs, :last_refresh_command_ref),
         true <- Support.optional_ref?(last_refresh_command_ref),
         staleness_ms <- Support.required(attrs, :staleness_ms),
         true <- Support.non_neg_integer?(staleness_ms) do
      {:ok,
       %__MODULE__{
         checking?: checking?,
         next_poll_at: next_poll_at,
         poll_interval_ms: poll_interval_ms,
         last_refresh_command_ref: last_refresh_command_ref,
         staleness_ms: staleness_ms
       }}
    else
      _ -> {:error, :invalid_polling_state}
    end
  end

  def dump(%__MODULE__{} = value), do: Support.dump_struct(value)
end

defmodule AppKit.Core.RuntimeReadback.RuntimeEventRow do
  @moduledoc "M1-readable runtime event row. Future M2 event kinds pass through safely."

  alias AppKit.Core.RuntimeReadback.Support

  @enforce_keys [:event_ref, :event_seq, :event_kind, :observed_at]
  defstruct [
    :event_ref,
    :event_seq,
    :event_kind,
    :observed_at,
    :tenant_ref,
    :installation_ref,
    :subject_ref,
    :run_ref,
    :execution_ref,
    :workflow_ref,
    :attempt_ref,
    :session_ref,
    :turn_ref,
    :level,
    :message_summary,
    :payload_ref,
    :extensions,
    :trace_id,
    :profile_ref,
    :source_contract_ref
  ]

  def new(%__MODULE__{} = value), do: {:ok, value}

  def new(attrs) do
    with {:ok, attrs, nil} <- Support.normalize(attrs),
         :ok <- Support.reject_selectors(attrs, :invalid_runtime_event_row),
         event_ref when is_binary(event_ref) <- Support.required(attrs, :event_ref),
         true <- Support.safe_ref?(event_ref),
         event_seq <- Support.required(attrs, :event_seq),
         true <- Support.non_neg_integer?(event_seq),
         event_kind <- Support.required(attrs, :event_kind),
         true <- Support.atomish?(event_kind),
         observed_at <- Support.required(attrs, :observed_at),
         true <- Support.timestamp?(observed_at),
         fields <- optional_fields(attrs),
         true <-
           Enum.all?(
             [
               :tenant_ref,
               :installation_ref,
               :subject_ref,
               :run_ref,
               :execution_ref,
               :workflow_ref,
               :attempt_ref,
               :session_ref,
               :turn_ref,
               :payload_ref,
               :trace_id,
               :profile_ref,
               :source_contract_ref
             ],
             &Support.optional_ref?(Map.get(fields, &1))
           ),
         true <- is_nil(fields.level) or Support.atomish?(fields.level),
         true <- is_nil(fields.message_summary) or is_binary(fields.message_summary),
         true <- is_map(fields.extensions) do
      {:ok,
       struct!(
         __MODULE__,
         Map.merge(fields, %{
           event_ref: event_ref,
           event_seq: event_seq,
           event_kind: normalize_atomish(event_kind),
           observed_at: observed_at
         })
       )}
    else
      _ -> {:error, :invalid_runtime_event_row}
    end
  end

  def dump(%__MODULE__{} = value), do: Support.dump_struct(value)

  def sort_key(%__MODULE__{} = value),
    do: {value.event_seq, observed_key(value.observed_at), value.event_ref}

  defp optional_fields(attrs) do
    %{
      tenant_ref: Support.optional(attrs, :tenant_ref),
      installation_ref: Support.optional(attrs, :installation_ref),
      subject_ref: Support.optional(attrs, :subject_ref),
      run_ref: Support.optional(attrs, :run_ref),
      execution_ref: Support.optional(attrs, :execution_ref),
      workflow_ref: Support.optional(attrs, :workflow_ref),
      attempt_ref: Support.optional(attrs, :attempt_ref),
      session_ref: Support.optional(attrs, :session_ref),
      turn_ref: Support.optional(attrs, :turn_ref),
      level: Support.optional(attrs, :level),
      message_summary: Support.optional(attrs, :message_summary),
      payload_ref: Support.optional(attrs, :payload_ref),
      extensions: Support.optional(attrs, :extensions, %{}),
      trace_id: Support.optional(attrs, :trace_id),
      profile_ref: Support.optional(attrs, :profile_ref),
      source_contract_ref: Support.optional(attrs, :source_contract_ref)
    }
  end

  defp observed_key(%DateTime{} = value), do: DateTime.to_iso8601(value)
  defp observed_key(value), do: to_string(value)
  defp normalize_atomish(value) when is_binary(value), do: value
  defp normalize_atomish(value), do: value
end

defmodule AppKit.Core.RuntimeReadback.RetryRow do
  @moduledoc "Retry attempt readback row."

  alias AppKit.Core.RuntimeReadback.Support

  @enforce_keys [:attempt_ref, :status]
  defstruct [:retry_ref, :attempt_ref, :status, :reason, :scheduled_at, :last_error_ref]

  def new(%__MODULE__{} = value), do: {:ok, value}

  def new(attrs) do
    with {:ok, attrs, nil} <- Support.normalize(attrs),
         :ok <- Support.reject_selectors(attrs, :invalid_retry_row),
         retry_ref <- Support.optional(attrs, :retry_ref),
         true <- Support.optional_ref?(retry_ref),
         attempt_ref when is_binary(attempt_ref) <- Support.required(attrs, :attempt_ref),
         true <- Support.safe_ref?(attempt_ref),
         status <- Support.required(attrs, :status),
         true <- Support.atomish?(status),
         reason <- Support.optional(attrs, :reason),
         true <- is_nil(reason) or is_binary(reason),
         scheduled_at <- Support.optional(attrs, :scheduled_at),
         true <- Support.optional_timestamp?(scheduled_at),
         last_error_ref <- Support.optional(attrs, :last_error_ref),
         true <- Support.optional_ref?(last_error_ref) do
      {:ok,
       %__MODULE__{
         retry_ref: retry_ref,
         attempt_ref: attempt_ref,
         status: status,
         reason: reason,
         scheduled_at: scheduled_at,
         last_error_ref: last_error_ref
       }}
    else
      _ -> {:error, :invalid_retry_row}
    end
  end

  def dump(%__MODULE__{} = value), do: Support.dump_struct(value)
end

defmodule AppKit.Core.RuntimeReadback.RuntimeRow do
  @moduledoc "State-list row for runtime readback."

  alias AppKit.Core.RuntimeReadback.{PollingState, SessionRef, Support, TokenTotals, WorkspaceRef}

  @enforce_keys [:subject_ref, :run_ref, :state, :updated_at]
  defstruct [
    :subject_ref,
    :run_ref,
    :execution_ref,
    :workflow_ref,
    :state,
    :status_reason,
    :updated_at,
    :session_ref,
    :workspace_ref,
    :polling_state,
    :token_totals,
    provider_refs: %{},
    extensions: %{}
  ]

  def new(%__MODULE__{} = value), do: {:ok, value}

  def new(attrs) do
    with {:ok, attrs, nil} <- Support.normalize(attrs),
         :ok <- Support.reject_selectors(attrs, :invalid_runtime_row),
         subject_ref when is_binary(subject_ref) <- Support.required(attrs, :subject_ref),
         true <- Support.safe_ref?(subject_ref),
         run_ref when is_binary(run_ref) <- Support.required(attrs, :run_ref),
         true <- Support.safe_ref?(run_ref),
         execution_ref <- Support.optional(attrs, :execution_ref),
         true <- Support.optional_ref?(execution_ref),
         workflow_ref <- Support.optional(attrs, :workflow_ref),
         true <- Support.optional_ref?(workflow_ref),
         state <- Support.required(attrs, :state),
         true <- Support.atomish?(state),
         status_reason <- Support.optional(attrs, :status_reason),
         true <- is_nil(status_reason) or is_binary(status_reason),
         updated_at <- Support.required(attrs, :updated_at),
         true <- Support.timestamp?(updated_at),
         {:ok, session_ref} <- Support.nested(Support.optional(attrs, :session_ref), SessionRef),
         {:ok, workspace_ref} <-
           Support.nested(Support.optional(attrs, :workspace_ref), WorkspaceRef),
         {:ok, polling_state} <-
           Support.nested(Support.optional(attrs, :polling_state), PollingState),
         {:ok, token_totals} <-
           Support.nested(Support.optional(attrs, :token_totals), TokenTotals),
         provider_refs <- Support.optional(attrs, :provider_refs, %{}),
         true <- is_map(provider_refs),
         extensions <- Support.optional(attrs, :extensions, %{}),
         true <- is_map(extensions) do
      {:ok,
       %__MODULE__{
         subject_ref: subject_ref,
         run_ref: run_ref,
         execution_ref: execution_ref,
         workflow_ref: workflow_ref,
         state: state,
         status_reason: status_reason,
         updated_at: updated_at,
         session_ref: session_ref,
         workspace_ref: workspace_ref,
         polling_state: polling_state,
         token_totals: token_totals,
         provider_refs: provider_refs,
         extensions: extensions
       }}
    else
      _ -> {:error, :invalid_runtime_row}
    end
  end

  def dump(%__MODULE__{} = value), do: Support.dump_struct(value)

  def sort_key(%__MODULE__{updated_at: updated_at, subject_ref: subject_ref, run_ref: run_ref}),
    do: {updated_key(updated_at), subject_ref, run_ref}

  defp updated_key(%DateTime{} = value), do: DateTime.to_iso8601(value)
  defp updated_key(value), do: to_string(value)
end

defmodule AppKit.Core.RuntimeReadback.CommandResult do
  @moduledoc """
  Synchronous AppKit command acknowledgement.

  M1 controls default to `:database_first`: the command row is durable and the
  workflow effect starts as `pending_signal` until a reducer confirms a terminal
  effect such as `applied`, `signal_rejected`, or `timed_out`.
  """

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

defmodule AppKit.Core.RuntimeReadback.RefreshRequest do
  @moduledoc "Typed refresh request for M1 readback reconciliation."

  alias AppKit.Core.RuntimeReadback.Support

  @enforce_keys [:idempotency_key, :actor_ref, :scope_ref]
  defstruct [:idempotency_key, :actor_ref, :scope_ref, operations: [], reason: nil]

  def new(%__MODULE__{} = value), do: {:ok, value}

  def new(attrs) do
    with {:ok, attrs, nil} <- Support.normalize(attrs),
         :ok <- Support.reject_selectors(attrs, :invalid_refresh_request),
         idempotency_key when is_binary(idempotency_key) <-
           Support.required(attrs, :idempotency_key),
         actor_ref when is_binary(actor_ref) <- Support.required(attrs, :actor_ref),
         true <- Support.safe_ref?(actor_ref),
         scope_ref when is_binary(scope_ref) <- Support.required(attrs, :scope_ref),
         true <- Support.safe_ref?(scope_ref),
         operations <- Support.optional(attrs, :operations, []),
         true <- is_list(operations) and Enum.all?(operations, &Support.atomish?/1),
         reason <- Support.optional(attrs, :reason),
         true <- is_nil(reason) or is_binary(reason) do
      {:ok,
       %__MODULE__{
         idempotency_key: idempotency_key,
         actor_ref: actor_ref,
         scope_ref: scope_ref,
         operations: operations,
         reason: reason
       }}
    else
      _ -> {:error, :invalid_refresh_request}
    end
  end

  def dump(%__MODULE__{} = value), do: Support.dump_struct(value)
  def new!(attrs), do: new(attrs) |> bang()
  defp bang({:ok, value}), do: value
  defp bang({:error, reason}), do: raise(ArgumentError, Atom.to_string(reason))
end

defmodule AppKit.Core.RuntimeReadback.ControlRequest do
  @moduledoc "Typed control request for M1 command submission."

  alias AppKit.Core.RuntimeReadback.Support

  @actions [
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
    "pause",
    "resume",
    "cancel",
    "retry",
    "rework",
    "read_lease",
    "stream_attach_lease",
    "review_decision",
    "inspect_trace",
    "inspect_memory_proof"
  ]

  @enforce_keys [:idempotency_key, :actor_ref, :action]
  defstruct [
    :idempotency_key,
    :actor_ref,
    :subject_ref,
    :run_ref,
    :execution_ref,
    :action,
    params: %{}
  ]

  def new(%__MODULE__{} = value), do: {:ok, value}

  def new(attrs) do
    with {:ok, attrs, nil} <- Support.normalize(attrs),
         :ok <- Support.reject_selectors(attrs, :invalid_control_request),
         idempotency_key when is_binary(idempotency_key) <-
           Support.required(attrs, :idempotency_key),
         actor_ref when is_binary(actor_ref) <- Support.required(attrs, :actor_ref),
         true <- Support.safe_ref?(actor_ref),
         subject_ref <- Support.optional(attrs, :subject_ref),
         true <- Support.optional_ref?(subject_ref),
         run_ref <- Support.optional(attrs, :run_ref),
         true <- Support.optional_ref?(run_ref),
         execution_ref <- Support.optional(attrs, :execution_ref),
         true <- Support.optional_ref?(execution_ref),
         action <- Support.required(attrs, :action),
         true <- action in @actions,
         params <- Support.optional(attrs, :params, %{}),
         true <- is_map(params) do
      {:ok,
       %__MODULE__{
         idempotency_key: idempotency_key,
         actor_ref: actor_ref,
         subject_ref: subject_ref,
         run_ref: run_ref,
         execution_ref: execution_ref,
         action: action,
         params: params
       }}
    else
      _ -> {:error, :invalid_control_request}
    end
  end

  def dump(%__MODULE__{} = value), do: Support.dump_struct(value)
  def new!(attrs), do: new(attrs) |> bang()
  defp bang({:ok, value}), do: value
  defp bang({:error, reason}), do: raise(ArgumentError, Atom.to_string(reason))
end

defmodule AppKit.Core.RuntimeReadback.RuntimeStateSnapshot do
  @moduledoc "Aggregate M1 state snapshot exposed by `AppKit.HeadlessSurface`."

  alias AppKit.Core.RuntimeReadback.{
    Diagnostic,
    PollingState,
    RateLimitSnapshot,
    RuntimeRow,
    Support,
    TokenTotals
  }

  @enforce_keys [:schema_ref, :schema_version, :tenant_ref, :installation_ref]
  defstruct [
    :schema_ref,
    :schema_version,
    :tenant_ref,
    :installation_ref,
    :generated_at,
    :polling_state,
    :token_totals,
    rows: [],
    retry_rows: [],
    rate_limits: [],
    diagnostics: [],
    page: %{page_size: 25, cursor: nil, total_entries: 0}
  ]

  def new(%__MODULE__{} = value), do: {:ok, value}

  def new(attrs) do
    with {:ok, attrs, nil} <- Support.normalize(attrs),
         :ok <- Support.reject_selectors(attrs, :invalid_runtime_state_snapshot),
         schema_ref <- Support.optional(attrs, :schema_ref, "runtime_readback/state_snapshot.v1"),
         true <- Support.present_binary?(schema_ref),
         schema_version <- Support.optional(attrs, :schema_version, 1),
         true <- schema_version == 1,
         tenant_ref when is_binary(tenant_ref) <- Support.required(attrs, :tenant_ref),
         true <- Support.safe_ref?(tenant_ref),
         installation_ref when is_binary(installation_ref) <-
           Support.required(attrs, :installation_ref),
         true <- Support.safe_ref?(installation_ref),
         generated_at <- Support.optional(attrs, :generated_at),
         true <- Support.optional_timestamp?(generated_at),
         {:ok, polling_state} <-
           Support.nested(Support.optional(attrs, :polling_state), PollingState),
         {:ok, token_totals} <-
           Support.nested(Support.optional(attrs, :token_totals), TokenTotals),
         {:ok, rows} <- Support.nested_list(Support.optional(attrs, :rows, []), RuntimeRow),
         {:ok, rate_limits} <-
           Support.nested_list(Support.optional(attrs, :rate_limits, []), RateLimitSnapshot),
         {:ok, diagnostics} <-
           Support.nested_list(Support.optional(attrs, :diagnostics, []), Diagnostic),
         retry_rows <- Support.optional(attrs, :retry_rows, []),
         true <- is_list(retry_rows),
         page <-
           Support.optional(attrs, :page, %{
             page_size: 25,
             cursor: nil,
             total_entries: length(rows)
           }),
         true <- is_map(page) do
      {:ok,
       %__MODULE__{
         schema_ref: schema_ref,
         schema_version: schema_version,
         tenant_ref: tenant_ref,
         installation_ref: installation_ref,
         generated_at: generated_at,
         polling_state: polling_state,
         token_totals: token_totals,
         rows: Enum.sort_by(rows, &RuntimeRow.sort_key/1, :desc),
         retry_rows: retry_rows,
         rate_limits: rate_limits,
         diagnostics: diagnostics,
         page: page
       }}
    else
      _ -> {:error, :invalid_runtime_state_snapshot}
    end
  end

  def dump(%__MODULE__{} = value), do: Support.dump_struct(value)
end

defmodule AppKit.Core.RuntimeReadback.RuntimeSubjectDetail do
  @moduledoc "Subject detail readback DTO."

  alias AppKit.Core.RuntimeReadback.{Diagnostic, RuntimeEventRow, RuntimeRow, Support}

  @enforce_keys [:schema_ref, :schema_version, :subject_ref]
  defstruct [
    :schema_ref,
    :schema_version,
    :subject_ref,
    :summary,
    :runtime_row,
    events: [],
    runs: [],
    diagnostics: []
  ]

  def new(%__MODULE__{} = value), do: {:ok, value}

  def new(attrs) do
    with {:ok, attrs, nil} <- Support.normalize(attrs),
         :ok <- Support.reject_selectors(attrs, :invalid_runtime_subject_detail),
         schema_ref <- Support.optional(attrs, :schema_ref, "runtime_readback/subject_detail.v1"),
         true <- Support.present_binary?(schema_ref),
         schema_version <- Support.optional(attrs, :schema_version, 1),
         true <- schema_version == 1,
         subject_ref when is_binary(subject_ref) <- Support.required(attrs, :subject_ref),
         true <- Support.safe_ref?(subject_ref),
         summary <- Support.optional(attrs, :summary, %{}),
         true <- is_map(summary),
         {:ok, runtime_row} <- Support.nested(Support.optional(attrs, :runtime_row), RuntimeRow),
         {:ok, events} <-
           Support.nested_list(Support.optional(attrs, :events, []), RuntimeEventRow),
         runs <- Support.optional(attrs, :runs, []),
         true <- is_list(runs),
         {:ok, diagnostics} <-
           Support.nested_list(Support.optional(attrs, :diagnostics, []), Diagnostic) do
      {:ok,
       %__MODULE__{
         schema_ref: schema_ref,
         schema_version: schema_version,
         subject_ref: subject_ref,
         summary: summary,
         runtime_row: runtime_row,
         events: Enum.sort_by(events, &RuntimeEventRow.sort_key/1),
         runs: runs,
         diagnostics: diagnostics
       }}
    else
      _ -> {:error, :invalid_runtime_subject_detail}
    end
  end

  def dump(%__MODULE__{} = value), do: Support.dump_struct(value)
end

defmodule AppKit.Core.RuntimeReadback.RuntimeRunDetail do
  @moduledoc "Run detail readback DTO with deterministic event ordering."

  alias AppKit.Core.RuntimeReadback.{Diagnostic, RetryRow, RuntimeEventRow, RuntimeRow, Support}

  @enforce_keys [:schema_ref, :schema_version, :run_ref]
  defstruct [
    :schema_ref,
    :schema_version,
    :run_ref,
    :runtime_row,
    events: [],
    retries: [],
    turns: [],
    budget_state: nil,
    candidate_fact_refs: [],
    memory_proof_refs: [],
    agent_loop_diagnostics: [],
    diagnostics: []
  ]

  def new(%__MODULE__{} = value), do: {:ok, value}

  def new(attrs) do
    with {:ok, attrs, nil} <- Support.normalize(attrs),
         :ok <- Support.reject_selectors(attrs, :invalid_runtime_run_detail),
         schema_ref <- Support.optional(attrs, :schema_ref, "runtime_readback/run_detail.v1"),
         true <- Support.present_binary?(schema_ref),
         schema_version <- Support.optional(attrs, :schema_version, 1),
         true <- schema_version == 1,
         run_ref when is_binary(run_ref) <- Support.required(attrs, :run_ref),
         true <- Support.safe_ref?(run_ref),
         {:ok, runtime_row} <- Support.nested(Support.optional(attrs, :runtime_row), RuntimeRow),
         {:ok, events} <-
           Support.nested_list(Support.optional(attrs, :events, []), RuntimeEventRow),
         {:ok, retries} <- Support.nested_list(Support.optional(attrs, :retries, []), RetryRow),
         turns <- Support.optional(attrs, :turns, []),
         true <- is_list(turns),
         budget_state <- Support.optional(attrs, :budget_state),
         true <- is_nil(budget_state) or is_map(budget_state),
         candidate_fact_refs <- Support.optional(attrs, :candidate_fact_refs, []),
         true <-
           is_list(candidate_fact_refs) and Enum.all?(candidate_fact_refs, &Support.safe_ref?/1),
         memory_proof_refs <- Support.optional(attrs, :memory_proof_refs, []),
         true <- is_list(memory_proof_refs) and Enum.all?(memory_proof_refs, &Support.safe_ref?/1),
         {:ok, agent_loop_diagnostics} <-
           Support.nested_list(Support.optional(attrs, :agent_loop_diagnostics, []), Diagnostic),
         {:ok, diagnostics} <-
           Support.nested_list(Support.optional(attrs, :diagnostics, []), Diagnostic) do
      {:ok,
       %__MODULE__{
         schema_ref: schema_ref,
         schema_version: schema_version,
         run_ref: run_ref,
         runtime_row: runtime_row,
         events: Enum.sort_by(events, &RuntimeEventRow.sort_key/1),
         retries: retries,
         turns: turns,
         budget_state: budget_state,
         candidate_fact_refs: candidate_fact_refs,
         memory_proof_refs: memory_proof_refs,
         agent_loop_diagnostics: agent_loop_diagnostics,
         diagnostics: diagnostics
       }}
    else
      _ -> {:error, :invalid_runtime_run_detail}
    end
  end

  def dump(%__MODULE__{} = value), do: Support.dump_struct(value)
end
