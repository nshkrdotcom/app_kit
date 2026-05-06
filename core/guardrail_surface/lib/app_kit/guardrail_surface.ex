defmodule AppKit.GuardrailSurface do
  @moduledoc """
  DTO-only guardrail surface.
  """

  alias OuterBrain.GuardrailContracts

  defmodule GuardChainViewProjection do
    @moduledoc "Guard chain view projection DTO."
    @enforce_keys [
      :guard_chain_ref,
      :detector_refs,
      :redaction_posture_floor,
      :policy_revision_ref
    ]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            guard_chain_ref: String.t(),
            detector_refs: [String.t()],
            redaction_posture_floor: atom(),
            policy_revision_ref: String.t()
          }
  end

  defmodule GuardDecisionProjection do
    @moduledoc "Guard decision projection DTO."
    @enforce_keys [:decision_ref, :decision, :detector_chain_ref, :redaction_posture]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            decision_ref: String.t(),
            decision: GuardrailContracts.GuardrailDecision.t(),
            detector_chain_ref: String.t(),
            redaction_posture: atom()
          }
  end

  defmodule GuardOverrideRequest do
    @moduledoc "Guard override request DTO."
    @enforce_keys [:request_ref, :decision_ref, :permission_ref, :reason_ref, :duration_seconds]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            request_ref: String.t(),
            decision_ref: String.t(),
            permission_ref: String.t(),
            reason_ref: String.t(),
            duration_seconds: pos_integer()
          }
  end

  defmodule GuardAuditProjection do
    @moduledoc "Guard audit projection DTO."
    @enforce_keys [:audit_ref, :decision_ref, :trace_ref, :bounded_violation_refs]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            audit_ref: String.t(),
            decision_ref: String.t(),
            trace_ref: String.t(),
            bounded_violation_refs: [String.t()]
          }
  end

  @raw_keys [
    :payload,
    :raw_payload,
    :body,
    :raw_body,
    :violation_body,
    "payload",
    "raw_payload",
    "body",
    "raw_body",
    "violation_body"
  ]

  @spec chain_view_projection(map()) :: {:ok, GuardChainViewProjection.t()} | {:error, term()}
  def chain_view_projection(attrs) when is_map(attrs) do
    with :ok <- reject_raw(attrs),
         :ok <- required_strings(attrs, [:guard_chain_ref, :policy_revision_ref]),
         detector_refs when is_list(detector_refs) <- fetch(attrs, :detector_refs),
         {:ok, posture} <- redaction_posture(fetch(attrs, :redaction_posture_floor)) do
      {:ok,
       %GuardChainViewProjection{
         guard_chain_ref: fetch!(attrs, :guard_chain_ref),
         detector_refs: detector_refs,
         redaction_posture_floor: posture,
         policy_revision_ref: fetch!(attrs, :policy_revision_ref)
       }}
    else
      _value -> {:error, :invalid_guard_chain_projection}
    end
  end

  defp redaction_posture(posture) do
    if posture in GuardrailContracts.redaction_postures() do
      {:ok, posture}
    else
      {:error, :unknown_guard_surface_redaction_posture}
    end
  end

  @spec decision_projection(map()) :: {:ok, GuardDecisionProjection.t()} | {:error, term()}
  def decision_projection(attrs) when is_map(attrs) do
    with :ok <- reject_raw(attrs),
         :ok <- required_strings(attrs, [:decision_ref]),
         {:ok, decision} <- attrs |> fetch(:decision) |> GuardrailContracts.guardrail_decision() do
      {:ok,
       %GuardDecisionProjection{
         decision_ref: fetch!(attrs, :decision_ref),
         decision: decision,
         detector_chain_ref: decision.detector_chain_ref,
         redaction_posture: decision.redaction_posture
       }}
    end
  end

  @spec override_request(map()) :: {:ok, GuardOverrideRequest.t()} | {:error, term()}
  def override_request(attrs) when is_map(attrs) do
    with :ok <- reject_raw(attrs),
         :ok <-
           required_strings(attrs, [:request_ref, :decision_ref, :permission_ref, :reason_ref]),
         {:ok, duration} <- positive_integer(attrs, :duration_seconds),
         :ok <- bounded_duration(duration) do
      {:ok,
       %GuardOverrideRequest{
         request_ref: fetch!(attrs, :request_ref),
         decision_ref: fetch!(attrs, :decision_ref),
         permission_ref: fetch!(attrs, :permission_ref),
         reason_ref: fetch!(attrs, :reason_ref),
         duration_seconds: duration
       }}
    end
  end

  @spec audit_projection(map()) :: {:ok, GuardAuditProjection.t()} | {:error, term()}
  def audit_projection(attrs) when is_map(attrs) do
    with :ok <- reject_raw(attrs),
         :ok <- required_strings(attrs, [:audit_ref, :decision_ref, :trace_ref]),
         refs when is_list(refs) <- fetch(attrs, :bounded_violation_refs) do
      {:ok,
       %GuardAuditProjection{
         audit_ref: fetch!(attrs, :audit_ref),
         decision_ref: fetch!(attrs, :decision_ref),
         trace_ref: fetch!(attrs, :trace_ref),
         bounded_violation_refs: refs
       }}
    else
      _value -> {:error, :invalid_guard_audit_projection}
    end
  end

  defp reject_raw(attrs) do
    case Enum.find(@raw_keys, &Map.has_key?(attrs, &1)) do
      nil -> :ok
      key -> {:error, {:raw_guardrail_surface_payload_forbidden, key}}
    end
  end

  defp required_strings(attrs, fields) do
    case Enum.find(fields, &(not present_string?(fetch(attrs, &1)))) do
      nil -> :ok
      field -> {:error, {:missing_guardrail_surface_ref, field}}
    end
  end

  defp positive_integer(attrs, field) do
    case fetch(attrs, field) do
      value when is_integer(value) and value > 0 -> {:ok, value}
      _value -> {:error, {:invalid_guardrail_surface_field, field}}
    end
  end

  defp bounded_duration(duration) when duration <= 3600, do: :ok
  defp bounded_duration(_duration), do: {:error, :guard_override_duration_unbounded}

  defp present_string?(value) when is_binary(value), do: String.trim(value) != ""
  defp present_string?(_value), do: false
  defp fetch!(attrs, field), do: fetch(attrs, field)
  defp fetch(attrs, field), do: Map.get(attrs, field) || Map.get(attrs, Atom.to_string(field))
end
