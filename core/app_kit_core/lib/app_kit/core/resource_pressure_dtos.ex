defmodule AppKit.Core.QueuePressureProjection do
  @moduledoc """
  Northbound operator DTO for Mezzanine queue pressure and shedding evidence.

  Contract: `AppKit.QueuePressureProjection.v1`.
  """

  alias AppKit.Core.RevisionEpochSupport

  @contract_name "AppKit.QueuePressureProjection.v1"
  @pressure_classes ["nominal", "soft_pressure", "hard_pressure", "queue_saturated"]
  @shed_decisions ["accept", "throttle", "shed"]
  @required_binary_fields RevisionEpochSupport.base_binary_fields() ++
                            [
                              :queue_name,
                              :queue_ref,
                              :budget_ref,
                              :pressure_sample_ref,
                              :threshold_ref,
                              :shed_reason,
                              :operator_message_ref
                            ]
  @required_non_neg_integer_fields [:current_depth, :max_depth, :retry_after_ms]
  @optional_binary_fields RevisionEpochSupport.optional_actor_fields() ++ [:diagnostics_ref]

  defstruct [
    :contract_name,
    :tenant_ref,
    :installation_ref,
    :workspace_ref,
    :project_ref,
    :environment_ref,
    :principal_ref,
    :system_actor_ref,
    :resource_ref,
    :authority_packet_ref,
    :permission_decision_ref,
    :idempotency_key,
    :trace_id,
    :correlation_id,
    :release_manifest_ref,
    :queue_name,
    :queue_ref,
    :budget_ref,
    :pressure_sample_ref,
    :threshold_ref,
    :pressure_class,
    :current_depth,
    :max_depth,
    :shed_decision,
    :shed_reason,
    :retry_after_ms,
    :operator_message_ref,
    :diagnostics_ref
  ]

  @type t :: %__MODULE__{}

  @spec contract_name() :: String.t()
  def contract_name, do: @contract_name

  @spec new(map() | keyword()) ::
          {:ok, t()}
          | {:error, {:missing_required_fields, [atom()]}}
          | {:error, :invalid_queue_pressure_projection}
  def new(attrs) do
    with {:ok, attrs} <- RevisionEpochSupport.normalize_attrs(attrs),
         [] <-
           RevisionEpochSupport.missing_required_fields(
             attrs,
             @required_binary_fields,
             []
           ),
         true <- required_non_neg_integer_fields?(attrs, @required_non_neg_integer_fields),
         true <- RevisionEpochSupport.optional_binary_fields?(attrs, @optional_binary_fields),
         {:ok, pressure_class} <-
           RevisionEpochSupport.enum_string(Map.get(attrs, :pressure_class), @pressure_classes),
         {:ok, shed_decision} <-
           RevisionEpochSupport.enum_string(Map.get(attrs, :shed_decision), @shed_decisions),
         :ok <- validate_pressure_semantics(attrs, shed_decision) do
      {:ok, build(attrs, pressure_class, shed_decision)}
    else
      fields when is_list(fields) -> {:error, {:missing_required_fields, fields}}
      _error -> {:error, :invalid_queue_pressure_projection}
    end
  end

  defp build(attrs, pressure_class, shed_decision) do
    struct!(
      __MODULE__,
      Map.merge(attrs, %{
        contract_name: @contract_name,
        pressure_class: pressure_class,
        shed_decision: shed_decision
      })
    )
  end

  defp validate_pressure_semantics(attrs, "shed") do
    cond do
      Map.fetch!(attrs, :current_depth) <= Map.fetch!(attrs, :max_depth) -> :error
      Map.fetch!(attrs, :retry_after_ms) <= 0 -> :error
      true -> :ok
    end
  end

  defp validate_pressure_semantics(attrs, "throttle") do
    if Map.fetch!(attrs, :retry_after_ms) > 0, do: :ok, else: :error
  end

  defp validate_pressure_semantics(_attrs, "accept"), do: :ok

  defp required_non_neg_integer_fields?(attrs, fields) do
    Enum.all?(fields, fn field -> RevisionEpochSupport.non_neg_integer?(Map.get(attrs, field)) end)
  end
end

defmodule AppKit.Core.RetryPostureProjection do
  @moduledoc """
  Northbound operator DTO for platform retry posture evidence.

  Contract: `AppKit.RetryPostureProjection.v1`.
  """

  alias AppKit.Core.RevisionEpochSupport

  @contract_name "AppKit.RetryPostureProjection.v1"
  @retry_classes [
    "never",
    "safe_idempotent",
    "after_input_change",
    "after_redecision",
    "manual_operator"
  ]
  @required_binary_fields RevisionEpochSupport.base_binary_fields() ++
                            [
                              :operation_ref,
                              :owner_repo,
                              :producer_ref,
                              :consumer_ref,
                              :failure_class,
                              :idempotency_scope,
                              :dead_letter_ref,
                              :safe_action_code
                            ]
  @required_non_neg_integer_fields [:max_attempts]
  @optional_binary_fields RevisionEpochSupport.optional_actor_fields() ++ [:operator_message_ref]

  defstruct [
    :contract_name,
    :tenant_ref,
    :installation_ref,
    :workspace_ref,
    :project_ref,
    :environment_ref,
    :principal_ref,
    :system_actor_ref,
    :resource_ref,
    :authority_packet_ref,
    :permission_decision_ref,
    :idempotency_key,
    :trace_id,
    :correlation_id,
    :release_manifest_ref,
    :operation_ref,
    :owner_repo,
    :producer_ref,
    :consumer_ref,
    :retry_class,
    :failure_class,
    :max_attempts,
    :backoff_policy,
    :idempotency_scope,
    :dead_letter_ref,
    :safe_action_code,
    :retry_after_ms,
    :operator_message_ref
  ]

  @type t :: %__MODULE__{}

  @spec contract_name() :: String.t()
  def contract_name, do: @contract_name

  @spec new(map() | keyword()) ::
          {:ok, t()}
          | {:error, {:missing_required_fields, [atom()]}}
          | {:error, :invalid_retry_posture_projection}
  def new(attrs) do
    with {:ok, attrs} <- RevisionEpochSupport.normalize_attrs(attrs),
         [] <-
           RevisionEpochSupport.missing_required_fields(
             attrs,
             @required_binary_fields,
             []
           ),
         true <- required_non_neg_integer_fields?(attrs, @required_non_neg_integer_fields),
         true <- RevisionEpochSupport.optional_binary_fields?(attrs, @optional_binary_fields),
         {:ok, backoff_policy} <- required_non_empty_map(attrs, :backoff_policy),
         true <- optional_non_neg_integer?(Map.get(attrs, :retry_after_ms)),
         {:ok, retry_class} <-
           RevisionEpochSupport.enum_string(Map.get(attrs, :retry_class), @retry_classes),
         :ok <- validate_retry_semantics(attrs, retry_class) do
      {:ok, build(attrs, retry_class, backoff_policy)}
    else
      fields when is_list(fields) -> {:error, {:missing_required_fields, fields}}
      _error -> {:error, :invalid_retry_posture_projection}
    end
  end

  defp build(attrs, retry_class, backoff_policy) do
    struct!(
      __MODULE__,
      Map.merge(attrs, %{
        contract_name: @contract_name,
        retry_class: retry_class,
        backoff_policy: backoff_policy
      })
    )
  end

  defp validate_retry_semantics(attrs, "never") do
    if Map.fetch!(attrs, :max_attempts) == 0, do: :ok, else: :error
  end

  defp validate_retry_semantics(attrs, _retry_class) do
    if Map.fetch!(attrs, :max_attempts) > 0, do: :ok, else: :error
  end

  defp required_non_empty_map(attrs, field) do
    case Map.get(attrs, field) do
      value when is_map(value) and map_size(value) > 0 -> {:ok, value}
      _other -> :error
    end
  end

  defp optional_non_neg_integer?(nil), do: true
  defp optional_non_neg_integer?(value), do: RevisionEpochSupport.non_neg_integer?(value)

  defp required_non_neg_integer_fields?(attrs, fields) do
    Enum.all?(fields, fn field -> RevisionEpochSupport.non_neg_integer?(Map.get(attrs, field)) end)
  end
end
