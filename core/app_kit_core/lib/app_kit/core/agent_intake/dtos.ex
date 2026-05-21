defmodule AppKit.Core.AgentIntake.Support do
  @moduledoc false

  alias AppKit.Core.Substrate.Support

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

  def normalize_bounded_atom(nil, _allowed, _lookup), do: {:ok, nil}

  def normalize_bounded_atom(value, allowed, _lookup) when is_atom(value) do
    if value in allowed, do: {:ok, value}, else: :error
  end

  def normalize_bounded_atom(value, _allowed, lookup) when is_binary(value),
    do: Map.fetch(lookup, value)

  def normalize_bounded_atom(_value, _allowed, _lookup), do: :error

  def non_negative_integer?(value), do: is_integer(value) and value >= 0
end

defmodule AppKit.Core.AgentIntake.AgentRunRequest do
  @moduledoc "Typed request to start an M2 agent run through AppKit."

  alias AppKit.Core.AgentIntake.Support
  alias AppKit.Core.Substrate.{Dump, ProfileBundle}

  @enforce_keys [
    :tenant_ref,
    :installation_ref,
    :subject_ref,
    :actor_ref,
    :profile_bundle,
    :tool_catalog_ref,
    :budget_ref,
    :recall_scope_ref,
    :idempotency_key,
    :trace_id,
    :correlation_id,
    :submission_dedupe_key,
    :initial_input_ref
  ]
  @effect_governance_modes [:fixture_backed, :staging_live, :disabled]
  @effect_governance_mode_lookup Map.new(@effect_governance_modes, &{Atom.to_string(&1), &1})
  @diagnostic_lanes [:echo, :probe]
  @diagnostic_lane_lookup Map.new(@diagnostic_lanes, &{Atom.to_string(&1), &1})

  defstruct @enforce_keys ++
              [
                :effect_governance_mode,
                :diagnostic_lane,
                :resume_cursor_ref,
                :pending_ref,
                governed_effect_refs: %{},
                params: %{}
              ]

  def new(%__MODULE__{} = value), do: {:ok, value}

  def new(attrs) do
    with {:ok, attrs, nil} <- Support.normalize(attrs),
         :ok <- Support.reject_selectors(attrs, :invalid_agent_run_request),
         tenant_ref when is_binary(tenant_ref) <- Support.required(attrs, :tenant_ref),
         true <- Support.safe_ref?(tenant_ref),
         installation_ref when is_binary(installation_ref) <-
           Support.required(attrs, :installation_ref),
         true <- Support.safe_ref?(installation_ref),
         subject_ref when is_binary(subject_ref) <- Support.required(attrs, :subject_ref),
         true <- Support.safe_ref?(subject_ref),
         actor_ref when is_binary(actor_ref) <- Support.required(attrs, :actor_ref),
         true <- Support.safe_ref?(actor_ref),
         {:ok, profile_bundle} <- ProfileBundle.new(Support.required(attrs, :profile_bundle)),
         tool_catalog_ref when is_binary(tool_catalog_ref) <-
           Support.required(attrs, :tool_catalog_ref),
         true <- Support.safe_ref?(tool_catalog_ref),
         budget_ref when is_binary(budget_ref) <- Support.required(attrs, :budget_ref),
         true <- Support.safe_ref?(budget_ref),
         recall_scope_ref when is_binary(recall_scope_ref) <-
           Support.required(attrs, :recall_scope_ref),
         true <- Support.safe_ref?(recall_scope_ref),
         idempotency_key when is_binary(idempotency_key) <-
           Support.required(attrs, :idempotency_key),
         trace_id when is_binary(trace_id) <- Support.required(attrs, :trace_id),
         true <- Support.safe_ref?(trace_id),
         correlation_id when is_binary(correlation_id) <- Support.required(attrs, :correlation_id),
         true <- Support.safe_ref?(correlation_id),
         submission_dedupe_key when is_binary(submission_dedupe_key) <-
           Support.required(attrs, :submission_dedupe_key),
         initial_input_ref when is_binary(initial_input_ref) <-
           Support.required(attrs, :initial_input_ref),
         true <- Support.safe_ref?(initial_input_ref),
         resume_cursor_ref <- Support.optional(attrs, :resume_cursor_ref),
         true <- Support.optional_ref?(resume_cursor_ref),
         pending_ref <- Support.optional(attrs, :pending_ref),
         true <- Support.optional_ref?(pending_ref),
         {:ok, effect_governance_mode} <-
           Support.normalize_bounded_atom(
             Support.optional(attrs, :effect_governance_mode),
             @effect_governance_modes,
             @effect_governance_mode_lookup
           ),
         {:ok, diagnostic_lane} <-
           Support.normalize_bounded_atom(
             Support.optional(attrs, :diagnostic_lane),
             @diagnostic_lanes,
             @diagnostic_lane_lookup
           ),
         governed_effect_refs <- Support.optional(attrs, :governed_effect_refs, %{}),
         true <- serializable_map?(governed_effect_refs),
         params <- Support.optional(attrs, :params, %{}),
         true <- is_map(params) do
      {:ok,
       %__MODULE__{
         tenant_ref: tenant_ref,
         installation_ref: installation_ref,
         subject_ref: subject_ref,
         actor_ref: actor_ref,
         profile_bundle: profile_bundle,
         tool_catalog_ref: tool_catalog_ref,
         budget_ref: budget_ref,
         recall_scope_ref: recall_scope_ref,
         idempotency_key: idempotency_key,
         trace_id: trace_id,
         correlation_id: correlation_id,
         submission_dedupe_key: submission_dedupe_key,
         initial_input_ref: initial_input_ref,
         resume_cursor_ref: resume_cursor_ref,
         pending_ref: pending_ref,
         effect_governance_mode: effect_governance_mode,
         diagnostic_lane: diagnostic_lane,
         governed_effect_refs: governed_effect_refs,
         params: params
       }}
    else
      _ -> {:error, :invalid_agent_run_request}
    end
  end

  def dump(%__MODULE__{} = value), do: value |> Map.from_struct() |> Dump.dump_value()
  def new!(attrs), do: new(attrs) |> bang()
  defp bang({:ok, value}), do: value
  defp bang({:error, reason}), do: raise(ArgumentError, Atom.to_string(reason))

  defp serializable_map?(value) when is_map(value) do
    Enum.all?(value, fn
      {key, nested} when is_atom(key) or is_binary(key) -> serializable_value?(nested)
      _other -> false
    end)
  end

  defp serializable_map?(_value), do: false

  defp serializable_value?(value) when is_binary(value) or is_number(value) or is_boolean(value),
    do: true

  defp serializable_value?(nil), do: true
  defp serializable_value?(value) when is_atom(value), do: true

  defp serializable_value?(value) when is_list(value),
    do: Enum.all?(value, &serializable_value?/1)

  defp serializable_value?(value) when is_map(value), do: serializable_map?(value)
  defp serializable_value?(_value), do: false
end

defmodule AppKit.Core.AgentIntake.TurnSubmission do
  @moduledoc "Typed M2 turn submission. Payloads are claim-checked by ref."

  alias AppKit.Core.AgentIntake.Support
  alias AppKit.Core.Substrate.Dump

  @kinds [:user_input, :approval, :denial, :replan_hint, :rework_hint, :cancel]
  @kind_lookup Map.new(@kinds, &{Atom.to_string(&1), &1})

  @enforce_keys [:idempotency_key, :actor_ref, :run_ref, :kind, :payload_ref]
  defstruct [
    :idempotency_key,
    :actor_ref,
    :run_ref,
    :kind,
    :payload_ref,
    :cursor_ref,
    :pending_ref,
    params: %{}
  ]

  def new(%__MODULE__{} = value), do: {:ok, value}

  def new(attrs) do
    with {:ok, attrs, nil} <- Support.normalize(attrs),
         :ok <- Support.reject_selectors(attrs, :invalid_turn_submission),
         idempotency_key when is_binary(idempotency_key) <-
           Support.required(attrs, :idempotency_key),
         actor_ref when is_binary(actor_ref) <- Support.required(attrs, :actor_ref),
         true <- Support.safe_ref?(actor_ref),
         run_ref when is_binary(run_ref) <- Support.required(attrs, :run_ref),
         true <- Support.safe_ref?(run_ref),
         {:ok, kind} <- normalize_kind(Support.required(attrs, :kind)),
         payload_ref when is_binary(payload_ref) <- Support.required(attrs, :payload_ref),
         true <- Support.safe_ref?(payload_ref),
         cursor_ref <- Support.optional(attrs, :cursor_ref),
         true <- Support.optional_ref?(cursor_ref),
         pending_ref <- Support.optional(attrs, :pending_ref),
         true <- Support.optional_ref?(pending_ref),
         params <- Support.optional(attrs, :params, %{}),
         true <- is_map(params) do
      {:ok,
       %__MODULE__{
         idempotency_key: idempotency_key,
         actor_ref: actor_ref,
         run_ref: run_ref,
         kind: kind,
         payload_ref: payload_ref,
         cursor_ref: cursor_ref,
         pending_ref: pending_ref,
         params: params
       }}
    else
      _ -> {:error, :invalid_turn_submission}
    end
  end

  def dump(%__MODULE__{} = value), do: value |> Map.from_struct() |> Dump.dump_value()
  def new!(attrs), do: new(attrs) |> bang()
  defp bang({:ok, value}), do: value
  defp bang({:error, reason}), do: raise(ArgumentError, Atom.to_string(reason))

  defp normalize_kind(kind) when is_atom(kind) do
    if kind in @kinds do
      {:ok, kind}
    else
      :error
    end
  end

  defp normalize_kind(kind) when is_binary(kind), do: Map.fetch(@kind_lookup, kind)
  defp normalize_kind(_kind), do: :error
end

defmodule AppKit.Core.AgentIntake.AgentRunCursor do
  @moduledoc "Product-safe cursor for catching up agent run events without re-executing work."

  alias AppKit.Core.AgentIntake.Support
  alias AppKit.Core.Substrate.Dump

  @visibilities [:product, :operator, :internal]
  @visibility_lookup Map.new(@visibilities, &{Atom.to_string(&1), &1})

  @enforce_keys [
    :cursor_ref,
    :ledger_ref,
    :tenant_ref,
    :actor_ref,
    :last_seq_seen,
    :visibility
  ]
  defstruct @enforce_keys ++ [:issued_at, :expires_at]

  def new(%__MODULE__{} = value), do: {:ok, value}

  def new(attrs) do
    with {:ok, attrs, nil} <- Support.normalize(attrs),
         :ok <- Support.reject_selectors(attrs, :invalid_agent_run_cursor),
         cursor_ref when is_binary(cursor_ref) <- Support.required(attrs, :cursor_ref),
         true <- Support.safe_ref?(cursor_ref),
         ledger_ref when is_binary(ledger_ref) <- Support.required(attrs, :ledger_ref),
         true <- Support.safe_ref?(ledger_ref),
         tenant_ref when is_binary(tenant_ref) <- Support.required(attrs, :tenant_ref),
         true <- Support.safe_ref?(tenant_ref),
         actor_ref when is_binary(actor_ref) <- Support.required(attrs, :actor_ref),
         true <- Support.safe_ref?(actor_ref),
         last_seq_seen <- Support.required(attrs, :last_seq_seen),
         true <- Support.non_negative_integer?(last_seq_seen),
         {:ok, visibility} <-
           Support.normalize_bounded_atom(
             Support.required(attrs, :visibility),
             @visibilities,
             @visibility_lookup
           ),
         issued_at <- Support.optional(attrs, :issued_at),
         true <- optional_binary?(issued_at),
         expires_at <- Support.optional(attrs, :expires_at),
         true <- optional_binary?(expires_at) do
      {:ok,
       %__MODULE__{
         cursor_ref: cursor_ref,
         ledger_ref: ledger_ref,
         tenant_ref: tenant_ref,
         actor_ref: actor_ref,
         last_seq_seen: last_seq_seen,
         visibility: visibility,
         issued_at: issued_at,
         expires_at: expires_at
       }}
    else
      _ -> {:error, :invalid_agent_run_cursor}
    end
  end

  def dump(%__MODULE__{} = value), do: value |> Map.from_struct() |> Dump.dump_value()
  def new!(attrs), do: new(attrs) |> bang()
  defp bang({:ok, value}), do: value
  defp bang({:error, reason}), do: raise(ArgumentError, Atom.to_string(reason))
  defp optional_binary?(nil), do: true
  defp optional_binary?(value), do: is_binary(value)
end

defmodule AppKit.Core.AgentIntake.AgentRunEvent do
  @moduledoc "Product-safe agent event summary returned during cursor catch-up."

  alias AppKit.Core.AgentIntake.Support
  alias AppKit.Core.Substrate.Dump

  @event_kinds [
    :conversation_delta,
    :execution_update,
    :pending_opened,
    :pending_resolved,
    :run_started,
    :run_completed,
    :run_failed
  ]
  @event_kind_lookup Map.new(@event_kinds, &{Atom.to_string(&1), &1})
  @visibilities [:product, :operator, :internal]
  @visibility_lookup Map.new(@visibilities, &{Atom.to_string(&1), &1})

  @enforce_keys [
    :event_ref,
    :ledger_ref,
    :event_seq,
    :event_kind,
    :visibility,
    :observed_at,
    :summary
  ]
  defstruct @enforce_keys ++ [:payload_ref, :pending_ref]

  def new(%__MODULE__{} = value), do: {:ok, value}

  def new(attrs) do
    with {:ok, attrs, nil} <- Support.normalize(attrs),
         :ok <- Support.reject_selectors(attrs, :invalid_agent_run_event),
         event_ref when is_binary(event_ref) <- Support.required(attrs, :event_ref),
         true <- Support.safe_ref?(event_ref),
         ledger_ref when is_binary(ledger_ref) <- Support.required(attrs, :ledger_ref),
         true <- Support.safe_ref?(ledger_ref),
         event_seq <- Support.required(attrs, :event_seq),
         true <- Support.non_negative_integer?(event_seq),
         {:ok, event_kind} <-
           Support.normalize_bounded_atom(
             Support.required(attrs, :event_kind),
             @event_kinds,
             @event_kind_lookup
           ),
         {:ok, visibility} <-
           Support.normalize_bounded_atom(
             Support.required(attrs, :visibility),
             @visibilities,
             @visibility_lookup
           ),
         observed_at when is_binary(observed_at) <- Support.required(attrs, :observed_at),
         summary when is_binary(summary) <- Support.required(attrs, :summary),
         true <- String.trim(summary) != "",
         payload_ref <- Support.optional(attrs, :payload_ref),
         true <- Support.optional_ref?(payload_ref),
         pending_ref <- Support.optional(attrs, :pending_ref),
         true <- Support.optional_ref?(pending_ref) do
      {:ok,
       %__MODULE__{
         event_ref: event_ref,
         ledger_ref: ledger_ref,
         event_seq: event_seq,
         event_kind: event_kind,
         visibility: visibility,
         observed_at: observed_at,
         summary: summary,
         payload_ref: payload_ref,
         pending_ref: pending_ref
       }}
    else
      _ -> {:error, :invalid_agent_run_event}
    end
  end

  def dump(%__MODULE__{} = value), do: value |> Map.from_struct() |> Dump.dump_value()
end

defmodule AppKit.Core.AgentIntake.AgentRunEventPage do
  @moduledoc "Product-safe page of agent events plus the cursor used to request it."

  alias AppKit.Core.AgentIntake.{AgentRunCursor, AgentRunEvent, Support}
  alias AppKit.Core.Substrate.Dump

  @enforce_keys [:cursor, :events, :has_more?]
  defstruct [:cursor, :events, :has_more?, :next_cursor_ref]

  def new(%__MODULE__{} = value), do: {:ok, value}

  def new(attrs) do
    with {:ok, attrs, nil} <- Support.normalize(attrs),
         :ok <- Support.reject_selectors(attrs, :invalid_agent_run_event_page),
         {:ok, cursor} <- AgentRunCursor.new(Support.required(attrs, :cursor)),
         events when is_list(events) <- Support.required(attrs, :events),
         {:ok, events} <- normalize_events(events),
         has_more? <- Support.optional(attrs, :has_more?, false),
         true <- is_boolean(has_more?),
         next_cursor_ref <- Support.optional(attrs, :next_cursor_ref),
         true <- Support.optional_ref?(next_cursor_ref) do
      {:ok,
       %__MODULE__{
         cursor: cursor,
         events: events,
         has_more?: has_more?,
         next_cursor_ref: next_cursor_ref
       }}
    else
      _ -> {:error, :invalid_agent_run_event_page}
    end
  end

  def dump(%__MODULE__{} = value), do: value |> Map.from_struct() |> Dump.dump_value()

  defp normalize_events(events) do
    Enum.reduce_while(events, {:ok, []}, fn event, {:ok, acc} ->
      case AgentRunEvent.new(event) do
        {:ok, event} -> {:cont, {:ok, [event | acc]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, events} -> {:ok, Enum.reverse(events)}
      {:error, reason} -> {:error, reason}
    end
  end
end

defmodule AppKit.Core.AgentIntake.AgentPendingInteraction do
  @moduledoc "Product-safe summary of a pending human or operator interaction."

  alias AppKit.Core.AgentIntake.Support
  alias AppKit.Core.Substrate.Dump

  @kinds [
    :approval_required,
    :denial_confirmation,
    :credential_required,
    :budget_override_required,
    :tool_permission_required,
    :policy_exception_requested,
    :clarification_required
  ]
  @kind_lookup Map.new(@kinds, &{Atom.to_string(&1), &1})
  @statuses [:open, :approved, :denied, :expired, :cancelled]
  @status_lookup Map.new(@statuses, &{Atom.to_string(&1), &1})

  @enforce_keys [
    :pending_ref,
    :ledger_ref,
    :decision_ref,
    :tenant_ref,
    :actor_ref,
    :kind,
    :prompt_summary,
    :requested_action_ref,
    :authority_ref,
    :opened_seq,
    :status
  ]
  defstruct @enforce_keys ++ [:expires_at, :resolved_at]

  def new(%__MODULE__{} = value), do: {:ok, value}

  def new(attrs) do
    with {:ok, attrs, nil} <- Support.normalize(attrs),
         :ok <- Support.reject_selectors(attrs, :invalid_agent_pending_interaction),
         pending_ref when is_binary(pending_ref) <- Support.required(attrs, :pending_ref),
         true <- Support.safe_ref?(pending_ref),
         ledger_ref when is_binary(ledger_ref) <- Support.required(attrs, :ledger_ref),
         true <- Support.safe_ref?(ledger_ref),
         decision_ref when is_binary(decision_ref) <- Support.required(attrs, :decision_ref),
         true <- Support.safe_ref?(decision_ref),
         tenant_ref when is_binary(tenant_ref) <- Support.required(attrs, :tenant_ref),
         true <- Support.safe_ref?(tenant_ref),
         actor_ref when is_binary(actor_ref) <- Support.required(attrs, :actor_ref),
         true <- Support.safe_ref?(actor_ref),
         {:ok, kind} <-
           Support.normalize_bounded_atom(Support.required(attrs, :kind), @kinds, @kind_lookup),
         prompt_summary when is_binary(prompt_summary) <-
           Support.required(attrs, :prompt_summary),
         true <- String.trim(prompt_summary) != "",
         requested_action_ref when is_binary(requested_action_ref) <-
           Support.required(attrs, :requested_action_ref),
         true <- Support.safe_ref?(requested_action_ref),
         authority_ref when is_binary(authority_ref) <- Support.required(attrs, :authority_ref),
         true <- Support.safe_ref?(authority_ref),
         opened_seq <- Support.required(attrs, :opened_seq),
         true <- Support.non_negative_integer?(opened_seq),
         {:ok, status} <-
           Support.normalize_bounded_atom(
             Support.required(attrs, :status),
             @statuses,
             @status_lookup
           ),
         expires_at <- Support.optional(attrs, :expires_at),
         true <- optional_binary?(expires_at),
         resolved_at <- Support.optional(attrs, :resolved_at),
         true <- optional_binary?(resolved_at) do
      {:ok,
       %__MODULE__{
         pending_ref: pending_ref,
         ledger_ref: ledger_ref,
         decision_ref: decision_ref,
         tenant_ref: tenant_ref,
         actor_ref: actor_ref,
         kind: kind,
         prompt_summary: prompt_summary,
         requested_action_ref: requested_action_ref,
         authority_ref: authority_ref,
         opened_seq: opened_seq,
         status: status,
         expires_at: expires_at,
         resolved_at: resolved_at
       }}
    else
      _ -> {:error, :invalid_agent_pending_interaction}
    end
  end

  def dump(%__MODULE__{} = value), do: value |> Map.from_struct() |> Dump.dump_value()
  defp optional_binary?(nil), do: true
  defp optional_binary?(value), do: is_binary(value)
end

defmodule AppKit.Core.AgentIntake.PendingInteractionQuery do
  @moduledoc "Product-safe query for pending agent interactions."

  alias AppKit.Core.AgentIntake.Support
  alias AppKit.Core.Substrate.Dump

  @statuses [:open, :approved, :denied, :expired, :cancelled]
  @status_lookup Map.new(@statuses, &{Atom.to_string(&1), &1})

  @enforce_keys [:tenant_ref, :actor_ref]
  defstruct [:tenant_ref, :actor_ref, :run_ref, :pending_ref, :status, :cursor_ref]

  def new(%__MODULE__{} = value), do: {:ok, value}

  def new(attrs) do
    with {:ok, attrs, nil} <- Support.normalize(attrs),
         :ok <- Support.reject_selectors(attrs, :invalid_pending_interaction_query),
         tenant_ref when is_binary(tenant_ref) <- Support.required(attrs, :tenant_ref),
         true <- Support.safe_ref?(tenant_ref),
         actor_ref when is_binary(actor_ref) <- Support.required(attrs, :actor_ref),
         true <- Support.safe_ref?(actor_ref),
         run_ref <- Support.optional(attrs, :run_ref),
         true <- Support.optional_ref?(run_ref),
         pending_ref <- Support.optional(attrs, :pending_ref),
         true <- Support.optional_ref?(pending_ref),
         cursor_ref <- Support.optional(attrs, :cursor_ref),
         true <- Support.optional_ref?(cursor_ref),
         {:ok, status} <-
           Support.normalize_bounded_atom(
             Support.optional(attrs, :status),
             [nil | @statuses],
             @status_lookup
           ) do
      {:ok,
       %__MODULE__{
         tenant_ref: tenant_ref,
         actor_ref: actor_ref,
         run_ref: run_ref,
         pending_ref: pending_ref,
         cursor_ref: cursor_ref,
         status: status
       }}
    else
      _ -> {:error, :invalid_pending_interaction_query}
    end
  end

  def dump(%__MODULE__{} = value), do: value |> Map.from_struct() |> Dump.dump_value()
  def new!(attrs), do: new(attrs) |> bang()
  defp bang({:ok, value}), do: value
  defp bang({:error, reason}), do: raise(ArgumentError, Atom.to_string(reason))
end

defmodule AppKit.Core.AgentIntake.RunOutcomeFuture do
  @moduledoc "Async handle returned when an agent run is accepted."

  alias AppKit.Core.AgentIntake.Support
  alias AppKit.Core.RuntimeReadback.PollingState
  alias AppKit.Core.Substrate.Dump

  @enforce_keys [:run_ref, :accepted?, :command_ref, :correlation_id]
  defstruct [
    :run_ref,
    :workflow_ref,
    :accepted?,
    :command_ref,
    :correlation_id,
    :polling_hint,
    governed_effect_refs: %{}
  ]

  def new(%__MODULE__{} = value), do: {:ok, value}

  def new(attrs) do
    with {:ok, attrs, nil} <- Support.normalize(attrs),
         :ok <- Support.reject_selectors(attrs, :invalid_run_outcome_future),
         run_ref when is_binary(run_ref) <- Support.required(attrs, :run_ref),
         true <- Support.safe_ref?(run_ref),
         workflow_ref <- Support.optional(attrs, :workflow_ref),
         true <- Support.optional_ref?(workflow_ref),
         accepted? <- Support.required(attrs, :accepted?),
         true <- is_boolean(accepted?),
         command_ref when is_binary(command_ref) <- Support.required(attrs, :command_ref),
         true <- Support.safe_ref?(command_ref),
         correlation_id when is_binary(correlation_id) <- Support.required(attrs, :correlation_id),
         true <- Support.safe_ref?(correlation_id),
         governed_effect_refs <- Support.optional(attrs, :governed_effect_refs, %{}),
         true <- is_map(governed_effect_refs),
         {:ok, polling_hint} <-
           AppKit.Core.RuntimeReadback.Support.nested(
             Support.optional(attrs, :polling_hint),
             PollingState
           ) do
      {:ok,
       %__MODULE__{
         run_ref: run_ref,
         workflow_ref: workflow_ref,
         accepted?: accepted?,
         command_ref: command_ref,
         correlation_id: correlation_id,
         governed_effect_refs: governed_effect_refs,
         polling_hint: polling_hint
       }}
    else
      _ -> {:error, :invalid_run_outcome_future}
    end
  end

  def dump(%__MODULE__{} = value), do: value |> Map.from_struct() |> Dump.dump_value()
end
