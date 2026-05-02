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
  defstruct @enforce_keys ++ [params: %{}]

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
end

defmodule AppKit.Core.AgentIntake.TurnSubmission do
  @moduledoc "Typed M2 turn submission. Payloads are claim-checked by ref."

  alias AppKit.Core.AgentIntake.Support
  alias AppKit.Core.Substrate.Dump

  @kinds [:user_input, :approval, :denial, :replan_hint, :rework_hint, :cancel]
  @kind_lookup Map.new(@kinds, &{Atom.to_string(&1), &1})

  @enforce_keys [:idempotency_key, :actor_ref, :run_ref, :kind, :payload_ref]
  defstruct [:idempotency_key, :actor_ref, :run_ref, :kind, :payload_ref, params: %{}]

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
         params <- Support.optional(attrs, :params, %{}),
         true <- is_map(params) do
      {:ok,
       %__MODULE__{
         idempotency_key: idempotency_key,
         actor_ref: actor_ref,
         run_ref: run_ref,
         kind: kind,
         payload_ref: payload_ref,
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

defmodule AppKit.Core.AgentIntake.RunOutcomeFuture do
  @moduledoc "Async handle returned when an agent run is accepted."

  alias AppKit.Core.AgentIntake.Support
  alias AppKit.Core.RuntimeReadback.PollingState
  alias AppKit.Core.Substrate.Dump

  @enforce_keys [:run_ref, :accepted?, :command_ref, :correlation_id]
  defstruct [:run_ref, :workflow_ref, :accepted?, :command_ref, :correlation_id, :polling_hint]

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
         polling_hint: polling_hint
       }}
    else
      _ -> {:error, :invalid_run_outcome_future}
    end
  end

  def dump(%__MODULE__{} = value), do: value |> Map.from_struct() |> Dump.dump_value()
end
