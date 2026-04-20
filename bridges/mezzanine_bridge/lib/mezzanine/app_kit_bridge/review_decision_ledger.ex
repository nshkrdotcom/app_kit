defmodule Mezzanine.AppKitBridge.ReviewDecisionLedger do
  @moduledoc false

  require Ash.Query

  alias Mezzanine.DecisionCommands
  alias Mezzanine.Decisions.DecisionRecord
  alias Mezzanine.Execution.ExecutionRecord

  @spec ensure_pending_for_recovery(map(), keyword()) ::
          {:ok, DecisionRecord.t()} | {:ok, nil} | {:error, term()}
  def ensure_pending_for_recovery(%{execution: execution, review_unit: review_unit}, opts \\ [])
      when is_list(opts) do
    with {:ok, %ExecutionRecord{} = execution} <- load_execution(execution),
         {:ok, context} <- decision_context(review_unit, execution),
         {:ok, decision} <- fetch_or_create_pending_decision(context, opts) do
      {:ok, decision}
    else
      {:error, :missing_execution_context} -> {:ok, nil}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec resolve_review_decision(atom(), map(), keyword()) ::
          {:ok, DecisionRecord.t()} | {:ok, nil} | {:error, term()}
  def resolve_review_decision(decision, bridge_result, opts \\ [])

  def resolve_review_decision(decision, %{review_unit: review_unit} = _bridge_result, opts)
      when decision in [:accept, :reject, :waive] and is_list(opts) do
    with {:ok, %ExecutionRecord{} = execution} <- load_execution_from_review(review_unit),
         {:ok, context} <- decision_context(review_unit, execution),
         {:ok, pending_decision} <- fetch_or_create_pending_decision(context, opts) do
      apply_resolution(decision, pending_decision, context, opts)
    else
      {:error, :missing_execution_context} -> {:ok, nil}
      {:error, reason} -> {:error, reason}
    end
  end

  def resolve_review_decision(_decision, _bridge_result, _opts), do: {:ok, nil}

  defp apply_resolution(:accept, decision_record, context, opts) do
    DecisionCommands.decide(decision_record, %{
      decision_value: "accept",
      reason: Keyword.get(opts, :reason),
      trace_id: context.trace_id,
      causation_id: causation_id(context.review_unit.id, :accept),
      actor_ref: actor_ref(opts)
    })
  end

  defp apply_resolution(:reject, decision_record, context, opts) do
    DecisionCommands.decide(decision_record, %{
      decision_value: "reject",
      reason: Keyword.get(opts, :reason),
      trace_id: context.trace_id,
      causation_id: causation_id(context.review_unit.id, :reject),
      actor_ref: actor_ref(opts)
    })
  end

  defp apply_resolution(:waive, decision_record, context, opts) do
    DecisionCommands.waive(decision_record, %{
      reason: Keyword.get(opts, :reason),
      trace_id: context.trace_id,
      causation_id: causation_id(context.review_unit.id, :waive),
      actor_ref: actor_ref(opts)
    })
  end

  defp fetch_or_create_pending_decision(context, opts) do
    case fetch_decision_record(context) do
      {:ok, %DecisionRecord{} = decision} ->
        {:ok, decision}

      {:ok, nil} ->
        create_pending_decision(context, opts)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp create_pending_decision(context, opts) do
    DecisionCommands.create_pending(%{
      installation_id: context.execution.installation_id,
      subject_id: context.execution.subject_id,
      execution_id: context.execution.id,
      decision_kind: context.decision_kind,
      required_by: context.review_unit.required_by,
      trace_id: context.trace_id,
      causation_id: causation_id(context.review_unit.id, :create),
      actor_ref: actor_ref(opts, %{kind: "system", ref: "review_decision_ledger"})
    })
    |> case do
      {:ok, %DecisionRecord{} = decision} ->
        {:ok, decision}

      {:error, reason} ->
        case fetch_decision_record(context) do
          {:ok, %DecisionRecord{} = decision} -> {:ok, decision}
          {:ok, nil} -> {:error, reason}
          {:error, fetch_reason} -> {:error, fetch_reason}
        end
    end
  end

  defp fetch_decision_record(context) do
    DecisionCommands.fetch_by_identity(%{
      installation_id: context.execution.installation_id,
      subject_id: context.execution.subject_id,
      execution_id: context.execution.id,
      decision_kind: context.decision_kind
    })
  end

  defp decision_context(review_unit, execution) do
    trace_id =
      profile_value(review_unit.decision_profile, :trace_id) ||
        execution.trace_id

    if is_binary(trace_id) and trace_id != "" do
      {:ok,
       %{
         review_unit: review_unit,
         execution: execution,
         trace_id: trace_id,
         decision_kind: review_unit.review_kind |> Atom.to_string()
       }}
    else
      {:error, :missing_execution_context}
    end
  end

  defp load_execution(%ExecutionRecord{} = execution), do: {:ok, execution}

  defp load_execution(execution_id) when is_binary(execution_id) do
    ExecutionRecord
    |> Ash.Query.filter(id == ^execution_id)
    |> Ash.read_one(authorize?: false, domain: Mezzanine.Execution)
    |> case do
      {:ok, %ExecutionRecord{} = execution} -> {:ok, execution}
      {:ok, nil} -> {:error, :missing_execution_context}
      {:error, reason} -> {:error, reason}
    end
  end

  defp load_execution(_other), do: {:error, :missing_execution_context}

  defp load_execution_from_review(review_unit) do
    case profile_value(review_unit.decision_profile, :execution_id) do
      execution_id when is_binary(execution_id) -> load_execution(execution_id)
      _other -> {:error, :missing_execution_context}
    end
  end

  defp profile_value(profile, key) when is_map(profile) do
    Map.get(profile, key) || Map.get(profile, Atom.to_string(key))
  end

  defp actor_ref(opts, default \\ %{kind: "human", ref: "reviewer"}) do
    actor_ref =
      Keyword.get(opts, :actor_ref) ||
        Keyword.get(opts, :actor) ||
        default

    case actor_ref do
      value when is_map(value) -> stringify_keys(value)
      value when is_binary(value) -> %{"ref" => value}
      _other -> stringify_keys(default)
    end
  end

  defp stringify_keys(value) when is_map(value) do
    value
    |> Enum.map(fn {key, nested} -> {to_string(key), nested} end)
    |> Map.new()
  end

  defp causation_id(review_unit_id, stage), do: "review-unit:#{review_unit_id}:#{stage}"
end
