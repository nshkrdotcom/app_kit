defmodule AppKit.AdaptiveControlSurface.OperatorProjection do
  @moduledoc "Operator-visible adaptive-control projection."

  @enforce_keys [
    :fixture_refs,
    :control_run_ref,
    :tenant_ref,
    :authority_ref,
    :actor_ref,
    :shadow_comparison_ref,
    :canary_state_ref,
    :threshold_status_refs,
    :budget_impact_ref,
    :approval_decision_ref,
    :promotion_readiness_ref,
    :rollback_ref,
    :artifact_lock_refs,
    :stale_artifact_rejection_refs,
    :audit_refs,
    :trace_refs,
    :redaction_posture
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          fixture_refs: [String.t()],
          control_run_ref: String.t(),
          tenant_ref: String.t(),
          authority_ref: String.t(),
          actor_ref: String.t(),
          shadow_comparison_ref: String.t(),
          canary_state_ref: String.t(),
          threshold_status_refs: [String.t()],
          budget_impact_ref: String.t(),
          approval_decision_ref: String.t(),
          promotion_readiness_ref: String.t(),
          rollback_ref: String.t(),
          artifact_lock_refs: [String.t()],
          stale_artifact_rejection_refs: [String.t()],
          audit_refs: [String.t()],
          trace_refs: [String.t()],
          redaction_posture: :refs_only
        }
end

defmodule AppKit.AdaptiveControlSurface do
  @moduledoc """
  DTO-only adaptive-control operator projection surface.
  """

  alias AppKit.AdaptiveControlSurface.OperatorProjection

  @fixture_refs ["AOC-037"]
  @required_strings [
    :control_run_ref,
    :tenant_ref,
    :authority_ref,
    :actor_ref,
    :shadow_comparison_ref,
    :canary_state_ref,
    :budget_impact_ref,
    :approval_decision_ref,
    :promotion_readiness_ref,
    :rollback_ref
  ]
  @required_lists [
    :threshold_status_refs,
    :artifact_lock_refs,
    :stale_artifact_rejection_refs,
    :audit_refs,
    :trace_refs
  ]
  @raw_keys [
    :api_key,
    :auth_header,
    :credential_body,
    :memory_body,
    :model_output,
    :operator_private_payload,
    :provider_payload,
    :raw_model_output,
    :raw_payload,
    :raw_prompt,
    :secret,
    :token,
    "api_key",
    "auth_header",
    "credential_body",
    "memory_body",
    "model_output",
    "operator_private_payload",
    "provider_payload",
    "raw_model_output",
    "raw_payload",
    "raw_prompt",
    "secret",
    "token"
  ]

  @spec operator_projection(map()) :: {:ok, OperatorProjection.t()} | {:error, term()}
  def operator_projection(attrs) when is_map(attrs) do
    with :ok <- reject_raw(attrs),
         :ok <- required_strings(attrs),
         :ok <- required_lists(attrs) do
      {:ok,
       %OperatorProjection{
         fixture_refs: @fixture_refs,
         control_run_ref: fetch!(attrs, :control_run_ref),
         tenant_ref: fetch!(attrs, :tenant_ref),
         authority_ref: fetch!(attrs, :authority_ref),
         actor_ref: fetch!(attrs, :actor_ref),
         shadow_comparison_ref: fetch!(attrs, :shadow_comparison_ref),
         canary_state_ref: fetch!(attrs, :canary_state_ref),
         threshold_status_refs: string_list(attrs, :threshold_status_refs),
         budget_impact_ref: fetch!(attrs, :budget_impact_ref),
         approval_decision_ref: fetch!(attrs, :approval_decision_ref),
         promotion_readiness_ref: fetch!(attrs, :promotion_readiness_ref),
         rollback_ref: fetch!(attrs, :rollback_ref),
         artifact_lock_refs: string_list(attrs, :artifact_lock_refs),
         stale_artifact_rejection_refs: string_list(attrs, :stale_artifact_rejection_refs),
         audit_refs: string_list(attrs, :audit_refs),
         trace_refs: string_list(attrs, :trace_refs),
         redaction_posture: :refs_only
       }}
    end
  end

  def operator_projection(_attrs), do: {:error, :invalid_adaptive_control_projection}

  defp required_strings(attrs) do
    Enum.reduce_while(@required_strings, :ok, fn field, :ok ->
      if present_string?(fetch(attrs, field)) do
        {:cont, :ok}
      else
        {:halt, {:error, {:missing_required_ref, field}}}
      end
    end)
  end

  defp required_lists(attrs) do
    Enum.reduce_while(@required_lists, :ok, fn field, :ok ->
      if non_empty_string_list?(fetch(attrs, field)) do
        {:cont, :ok}
      else
        {:halt, {:error, {:missing_required_refs, field}}}
      end
    end)
  end

  defp reject_raw(attrs) do
    case raw_key(attrs) do
      nil -> :ok
      key -> {:error, {:raw_adaptive_control_surface_payload_forbidden, key}}
    end
  end

  defp raw_key(%_struct{} = value), do: value |> Map.from_struct() |> raw_key()

  defp raw_key(value) when is_map(value) do
    Enum.find_value(value, fn {key, nested} ->
      if key in @raw_keys, do: key, else: raw_key(nested)
    end)
  end

  defp raw_key(value) when is_list(value), do: Enum.find_value(value, &raw_key/1)
  defp raw_key(_value), do: nil

  defp string_list(attrs, field) do
    case fetch(attrs, field, []) do
      values when is_list(values) and values != [] ->
        if Enum.all?(values, &present_string?/1), do: values, else: []

      _other ->
        []
    end
  end

  defp non_empty_string_list?(values) when is_list(values) and values != [] do
    Enum.all?(values, &present_string?/1)
  end

  defp non_empty_string_list?(_values), do: false
  defp present_string?(value), do: is_binary(value) and String.trim(value) != ""

  defp fetch!(attrs, field), do: fetch(attrs, field)

  defp fetch(attrs, field, default \\ nil) do
    string_field = Atom.to_string(field)

    cond do
      Map.has_key?(attrs, field) -> Map.fetch!(attrs, field)
      Map.has_key?(attrs, string_field) -> Map.fetch!(attrs, string_field)
      true -> default
    end
  end
end
