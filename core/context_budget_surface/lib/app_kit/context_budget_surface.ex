defmodule AppKit.ContextBudgetSurface do
  @moduledoc """
  DTO-only context-budget surface.
  """

  alias OuterBrain.MemoryContracts

  defmodule BudgetSetRequest do
    @moduledoc "Budget set request DTO."
    @enforce_keys [:request_ref, :budget_ref, :limit_units, :unit_class]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            request_ref: String.t(),
            budget_ref: MemoryContracts.ContextBudgetRef.t(),
            limit_units: pos_integer(),
            unit_class: atom()
          }
  end

  defmodule BudgetViewProjection do
    @moduledoc "Redacted budget view projection."
    @enforce_keys [:budget_ref, :unit_class, :limit_units, :used_units, :residual_units]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            budget_ref: MemoryContracts.ContextBudgetRef.t(),
            unit_class: atom(),
            limit_units: non_neg_integer(),
            used_units: non_neg_integer(),
            residual_units: non_neg_integer()
          }
  end

  defmodule BudgetExhaustionRecord do
    @moduledoc "Budget exhaustion DTO."
    @enforce_keys [:budget_ref, :locus, :decision, :trace_ref]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            budget_ref: MemoryContracts.ContextBudgetRef.t(),
            locus: atom(),
            decision: MemoryContracts.ContextBudgetDecision.t(),
            trace_ref: String.t()
          }
  end

  defmodule BudgetOverrideRequest do
    @moduledoc "Bounded operator override request DTO."
    @enforce_keys [
      :request_ref,
      :budget_ref,
      :permission_ref,
      :reason_ref,
      :duration_seconds,
      :added_units
    ]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            request_ref: String.t(),
            budget_ref: MemoryContracts.ContextBudgetRef.t(),
            permission_ref: String.t(),
            reason_ref: String.t(),
            duration_seconds: pos_integer(),
            added_units: pos_integer()
          }
  end

  @unit_classes [:token, :byte, :turn]
  @loci [:preflight, :append, :stream, :runtime_admission, :reconciliation]
  @raw_keys [:amount, :raw_amount, :secret, :payload, "amount", "raw_amount", "secret", "payload"]

  @spec set_request(map()) :: {:ok, BudgetSetRequest.t()} | {:error, term()}
  def set_request(attrs) when is_map(attrs) do
    with :ok <- reject_raw_values(attrs),
         {:ok, request_ref} <- required_string(attrs, :request_ref),
         {:ok, budget_ref} <- attrs |> fetch(:budget_ref) |> MemoryContracts.budget_ref(),
         {:ok, unit_class} <- required_member(attrs, :unit_class, @unit_classes),
         {:ok, limit_units} <- required_positive_integer(attrs, :limit_units) do
      {:ok,
       %BudgetSetRequest{
         request_ref: request_ref,
         budget_ref: budget_ref,
         unit_class: unit_class,
         limit_units: limit_units
       }}
    end
  end

  @spec view_projection(map()) :: {:ok, BudgetViewProjection.t()} | {:error, term()}
  def view_projection(attrs) when is_map(attrs) do
    with :ok <- reject_raw_values(attrs),
         {:ok, budget_ref} <- attrs |> fetch(:budget_ref) |> MemoryContracts.budget_ref(),
         {:ok, unit_class} <- required_member(attrs, :unit_class, @unit_classes),
         {:ok, limit_units} <- required_non_negative_integer(attrs, :limit_units),
         {:ok, used_units} <- required_non_negative_integer(attrs, :used_units),
         {:ok, residual_units} <- required_non_negative_integer(attrs, :residual_units) do
      {:ok,
       %BudgetViewProjection{
         budget_ref: budget_ref,
         unit_class: unit_class,
         limit_units: limit_units,
         used_units: used_units,
         residual_units: residual_units
       }}
    end
  end

  @spec exhaustion_record(map()) :: {:ok, BudgetExhaustionRecord.t()} | {:error, term()}
  def exhaustion_record(attrs) when is_map(attrs) do
    with :ok <- reject_raw_values(attrs),
         {:ok, budget_ref} <- attrs |> fetch(:budget_ref) |> MemoryContracts.budget_ref(),
         {:ok, locus} <- required_member(attrs, :locus, @loci),
         {:ok, decision} <- attrs |> fetch(:decision) |> MemoryContracts.budget_decision(),
         {:ok, trace_ref} <- required_string(attrs, :trace_ref) do
      {:ok,
       %BudgetExhaustionRecord{
         budget_ref: budget_ref,
         locus: locus,
         decision: decision,
         trace_ref: trace_ref
       }}
    end
  end

  @spec override_request(map()) :: {:ok, BudgetOverrideRequest.t()} | {:error, term()}
  def override_request(attrs) when is_map(attrs) do
    with :ok <- reject_raw_values(attrs),
         {:ok, request_ref} <- required_string(attrs, :request_ref),
         {:ok, budget_ref} <- attrs |> fetch(:budget_ref) |> MemoryContracts.budget_ref(),
         {:ok, permission_ref} <- required_string(attrs, :permission_ref),
         {:ok, reason_ref} <- required_string(attrs, :reason_ref),
         {:ok, duration_seconds} <- required_positive_integer(attrs, :duration_seconds),
         {:ok, added_units} <- required_positive_integer(attrs, :added_units),
         :ok <- bounded_duration(duration_seconds) do
      {:ok,
       %BudgetOverrideRequest{
         request_ref: request_ref,
         budget_ref: budget_ref,
         permission_ref: permission_ref,
         reason_ref: reason_ref,
         duration_seconds: duration_seconds,
         added_units: added_units
       }}
    end
  end

  defp bounded_duration(duration_seconds) when duration_seconds <= 3600, do: :ok
  defp bounded_duration(_duration_seconds), do: {:error, :budget_override_duration_unbounded}

  defp required_member(attrs, field, allowed) do
    value = fetch(attrs, field)
    if value in allowed, do: {:ok, value}, else: {:error, {:invalid_field, field}}
  end

  defp required_string(attrs, field) do
    case fetch(attrs, field) do
      value when is_binary(value) ->
        if String.trim(value) == "", do: {:error, {:missing_field, field}}, else: {:ok, value}

      _other ->
        {:error, {:missing_field, field}}
    end
  end

  defp required_positive_integer(attrs, field) do
    case fetch(attrs, field) do
      value when is_integer(value) and value > 0 -> {:ok, value}
      _other -> {:error, {:invalid_field, field}}
    end
  end

  defp required_non_negative_integer(attrs, field) do
    case fetch(attrs, field) do
      value when is_integer(value) and value >= 0 -> {:ok, value}
      _other -> {:error, {:invalid_field, field}}
    end
  end

  defp reject_raw_values(attrs) do
    case Enum.find(@raw_keys, &Map.has_key?(attrs, &1)) do
      nil -> :ok
      key -> {:error, {:raw_budget_surface_payload_forbidden, key}}
    end
  end

  defp fetch(attrs, field), do: Map.get(attrs, field) || Map.get(attrs, Atom.to_string(field))
end
