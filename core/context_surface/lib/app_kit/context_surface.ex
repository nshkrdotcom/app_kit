defmodule AppKit.ContextSurface.ContextCompileRequest do
  @moduledoc "Product-safe context compile request."
  @enforce_keys [
    :request_ref,
    :tenant_ref,
    :authority_ref,
    :user_request_ref,
    :system_instruction_ref,
    :memory_refs,
    :budget_ref,
    :model_class_allowlist,
    :route_policy_ref,
    :trace_ref,
    :idempotency_key,
    :redaction_policy_ref
  ]
  defstruct @enforce_keys
  @type t :: %__MODULE__{}
end

defmodule AppKit.ContextSurface.ContextPacketProjection do
  @moduledoc "Product-safe context packet summary."
  @enforce_keys [
    :context_packet_ref,
    :tenant_ref,
    :packet_hash,
    :user_request_ref,
    :system_instruction_ref,
    :memory_refs,
    :budget_ref,
    :model_class_allowlist,
    :route_policy_ref,
    :receipt_ref,
    :admission_status,
    :trace_ref,
    :redaction_posture
  ]
  defstruct [:failure_ref | @enforce_keys]
  @type t :: %__MODULE__{}
end

defmodule AppKit.ContextSurface.RouteDecisionProjection do
  @moduledoc "Product-safe route decision projection."
  @enforce_keys [
    :route_decision_ref,
    :context_packet_ref,
    :route_policy_ref,
    :selected_route_kind,
    :selected_model_profile_ref,
    :provider_or_runtime_ref,
    :verifier_ref,
    :fallback_plan_ref,
    :cost_estimate_ref,
    :budget_status_ref,
    :authority_ref,
    :trace_ref,
    :reason_codes,
    :redaction_posture
  ]
  defstruct @enforce_keys
  @type t :: %__MODULE__{}
end

defmodule AppKit.ContextSurface.ModelInvocationProjection do
  @moduledoc "Product-safe model invocation projection."
  @enforce_keys [
    :model_invocation_ref,
    :model_receipt_ref,
    :context_packet_ref,
    :route_decision_ref,
    :prompt_artifact_ref,
    :provider_payload_ref,
    :payload_hash,
    :model_profile_ref,
    :endpoint_ref,
    :provider_ref,
    :credential_lease_ref,
    :cost_ref,
    :trace_ref,
    :redaction_posture
  ]
  defstruct @enforce_keys
  @type t :: %__MODULE__{}
end

defmodule AppKit.ContextSurface.EvalVerdictProjection do
  @moduledoc "Product-safe eval verdict projection."
  @enforce_keys [
    :eval_verdict_ref,
    :context_packet_ref,
    :route_decision_ref,
    :model_receipt_ref,
    :verdict,
    :severity_class,
    :decision_evidence_ref,
    :trace_ref,
    :redaction_posture
  ]
  defstruct @enforce_keys
  @type t :: %__MODULE__{}
end

defmodule AppKit.ContextSurface.OperatorReviewProjection do
  @moduledoc "Product-safe operator review state for context execution."
  @enforce_keys [
    :review_ref,
    :context_packet_ref,
    :route_decision_ref,
    :eval_verdict_ref,
    :promotion_refs,
    :rollback_refs,
    :operator_state,
    :trace_refs,
    :redaction_posture
  ]
  defstruct @enforce_keys
  @type t :: %__MODULE__{}
end

defmodule AppKit.ContextSurface do
  @moduledoc """
  DTO-only context packet and AI execution projection surface.
  """

  alias AppKit.ContextSurface.{
    ContextCompileRequest,
    ContextPacketProjection,
    EvalVerdictProjection,
    ModelInvocationProjection,
    OperatorReviewProjection,
    RouteDecisionProjection
  }

  alias OuterBrain.ContextABI.ContextPacket

  @admission_statuses [:compiled, :admitted, :rejected, :denied]
  @route_kinds [
    :fixture,
    :single_provider,
    :local_model,
    :frontier_model,
    :ensemble,
    :verify_then_escalate,
    :trinity_coordinated
  ]
  @verdicts [:pass, :regress, :improve, :inconclusive, :blocked]
  @operator_states [:pending, :approved, :rejected, :changes_requested, :auto_accepted]
  @raw_keys [
    :api_key,
    :auth_header,
    :body,
    :credential,
    :credential_material,
    :execution_plane_lane,
    :jido_provider_module,
    :mezzanine_module,
    :memory_body,
    :model_output,
    :provider_payload,
    :provider_response,
    :raw_body,
    :raw_memory,
    :raw_model_output,
    :raw_payload,
    :raw_prompt,
    :secret,
    :token,
    "api_key",
    "auth_header",
    "body",
    "credential",
    "credential_material",
    "execution_plane_lane",
    "jido_provider_module",
    "mezzanine_module",
    "memory_body",
    "model_output",
    "provider_payload",
    "provider_response",
    "raw_body",
    "raw_memory",
    "raw_model_output",
    "raw_payload",
    "raw_prompt",
    "secret",
    "token"
  ]

  @spec compile_request(map()) :: {:ok, ContextCompileRequest.t()} | {:error, term()}
  def compile_request(attrs) when is_map(attrs) do
    with :ok <- reject_raw(attrs),
         :ok <-
           required_strings(attrs, [
             :request_ref,
             :tenant_ref,
             :authority_ref,
             :user_request_ref,
             :system_instruction_ref,
             :budget_ref,
             :route_policy_ref,
             :trace_ref,
             :idempotency_key,
             :redaction_policy_ref
           ]),
         {:ok, memory_refs} <- string_list(attrs, :memory_refs, []),
         {:ok, model_class_allowlist} <- non_empty_string_list(attrs, :model_class_allowlist) do
      {:ok,
       %ContextCompileRequest{
         request_ref: fetch!(attrs, :request_ref),
         tenant_ref: fetch!(attrs, :tenant_ref),
         authority_ref: fetch!(attrs, :authority_ref),
         user_request_ref: fetch!(attrs, :user_request_ref),
         system_instruction_ref: fetch!(attrs, :system_instruction_ref),
         memory_refs: memory_refs,
         budget_ref: fetch!(attrs, :budget_ref),
         model_class_allowlist: model_class_allowlist,
         route_policy_ref: fetch!(attrs, :route_policy_ref),
         trace_ref: fetch!(attrs, :trace_ref),
         idempotency_key: fetch!(attrs, :idempotency_key),
         redaction_policy_ref: fetch!(attrs, :redaction_policy_ref)
       }}
    end
  end

  def compile_request(_attrs), do: {:error, :invalid_context_compile_request}

  @spec packet_projection(map()) :: {:ok, ContextPacketProjection.t()} | {:error, term()}
  def packet_projection(attrs) when is_map(attrs) do
    with :ok <- reject_raw(attrs),
         {:ok, packet} <- packet(attrs),
         :ok <- required_strings(attrs, [:receipt_ref]),
         {:ok, admission_status} <- member(attrs, :admission_status, @admission_statuses) do
      {:ok,
       %ContextPacketProjection{
         context_packet_ref: packet.context_packet_ref,
         tenant_ref: packet.tenant_ref,
         packet_hash: packet.packet_hash,
         user_request_ref: packet.user_request_ref,
         system_instruction_ref: packet.system_instruction_ref,
         memory_refs: packet.memory_refs,
         budget_ref: packet.budget_ref,
         model_class_allowlist: packet.model_class_allowlist,
         route_policy_ref: packet.route_policy_ref,
         receipt_ref: fetch!(attrs, :receipt_ref),
         admission_status: admission_status,
         trace_ref: packet.trace_ref,
         failure_ref: optional_string(attrs, :failure_ref),
         redaction_posture: :refs_only
       }}
    end
  end

  def packet_projection(_attrs), do: {:error, :invalid_context_packet_projection}

  @spec route_decision_projection(map()) ::
          {:ok, RouteDecisionProjection.t()} | {:error, term()}
  def route_decision_projection(attrs) when is_map(attrs) do
    with :ok <- reject_raw(attrs),
         :ok <-
           required_strings(attrs, [
             :route_decision_ref,
             :context_packet_ref,
             :route_policy_ref,
             :selected_model_profile_ref,
             :provider_or_runtime_ref,
             :verifier_ref,
             :fallback_plan_ref,
             :cost_estimate_ref,
             :budget_status_ref,
             :authority_ref,
             :trace_ref
           ]),
         {:ok, route_kind} <- member(attrs, :selected_route_kind, @route_kinds),
         {:ok, reason_codes} <- string_list(attrs, :reason_codes, []) do
      {:ok,
       %RouteDecisionProjection{
         route_decision_ref: fetch!(attrs, :route_decision_ref),
         context_packet_ref: fetch!(attrs, :context_packet_ref),
         route_policy_ref: fetch!(attrs, :route_policy_ref),
         selected_route_kind: route_kind,
         selected_model_profile_ref: fetch!(attrs, :selected_model_profile_ref),
         provider_or_runtime_ref: fetch!(attrs, :provider_or_runtime_ref),
         verifier_ref: fetch!(attrs, :verifier_ref),
         fallback_plan_ref: fetch!(attrs, :fallback_plan_ref),
         cost_estimate_ref: fetch!(attrs, :cost_estimate_ref),
         budget_status_ref: fetch!(attrs, :budget_status_ref),
         authority_ref: fetch!(attrs, :authority_ref),
         trace_ref: fetch!(attrs, :trace_ref),
         reason_codes: reason_codes,
         redaction_posture: :refs_only
       }}
    end
  end

  @spec model_invocation_projection(map()) ::
          {:ok, ModelInvocationProjection.t()} | {:error, term()}
  def model_invocation_projection(attrs) when is_map(attrs) do
    with :ok <- reject_raw(attrs),
         :ok <-
           required_strings(attrs, [
             :model_invocation_ref,
             :model_receipt_ref,
             :context_packet_ref,
             :route_decision_ref,
             :prompt_artifact_ref,
             :provider_payload_ref,
             :payload_hash,
             :model_profile_ref,
             :endpoint_ref,
             :provider_ref,
             :credential_lease_ref,
             :cost_ref,
             :trace_ref
           ]),
         :ok <- sha256(attrs, :payload_hash) do
      {:ok,
       %ModelInvocationProjection{
         model_invocation_ref: fetch!(attrs, :model_invocation_ref),
         model_receipt_ref: fetch!(attrs, :model_receipt_ref),
         context_packet_ref: fetch!(attrs, :context_packet_ref),
         route_decision_ref: fetch!(attrs, :route_decision_ref),
         prompt_artifact_ref: fetch!(attrs, :prompt_artifact_ref),
         provider_payload_ref: fetch!(attrs, :provider_payload_ref),
         payload_hash: fetch!(attrs, :payload_hash),
         model_profile_ref: fetch!(attrs, :model_profile_ref),
         endpoint_ref: fetch!(attrs, :endpoint_ref),
         provider_ref: fetch!(attrs, :provider_ref),
         credential_lease_ref: fetch!(attrs, :credential_lease_ref),
         cost_ref: fetch!(attrs, :cost_ref),
         trace_ref: fetch!(attrs, :trace_ref),
         redaction_posture: :refs_only
       }}
    end
  end

  @spec eval_verdict_projection(map()) ::
          {:ok, EvalVerdictProjection.t()} | {:error, term()}
  def eval_verdict_projection(attrs) when is_map(attrs) do
    with :ok <- reject_raw(attrs),
         :ok <-
           required_strings(attrs, [
             :eval_verdict_ref,
             :context_packet_ref,
             :route_decision_ref,
             :model_receipt_ref,
             :severity_class,
             :decision_evidence_ref,
             :trace_ref
           ]),
         {:ok, verdict} <- member(attrs, :verdict, @verdicts) do
      {:ok,
       %EvalVerdictProjection{
         eval_verdict_ref: fetch!(attrs, :eval_verdict_ref),
         context_packet_ref: fetch!(attrs, :context_packet_ref),
         route_decision_ref: fetch!(attrs, :route_decision_ref),
         model_receipt_ref: fetch!(attrs, :model_receipt_ref),
         verdict: verdict,
         severity_class: fetch!(attrs, :severity_class),
         decision_evidence_ref: fetch!(attrs, :decision_evidence_ref),
         trace_ref: fetch!(attrs, :trace_ref),
         redaction_posture: :refs_only
       }}
    end
  end

  @spec operator_review_projection(map()) ::
          {:ok, OperatorReviewProjection.t()} | {:error, term()}
  def operator_review_projection(attrs) when is_map(attrs) do
    with :ok <- reject_raw(attrs),
         :ok <-
           required_strings(attrs, [
             :review_ref,
             :context_packet_ref,
             :route_decision_ref,
             :eval_verdict_ref
           ]),
         {:ok, promotion_refs} <- string_list(attrs, :promotion_refs, []),
         {:ok, rollback_refs} <- string_list(attrs, :rollback_refs, []),
         {:ok, trace_refs} <- non_empty_string_list(attrs, :trace_refs),
         {:ok, operator_state} <- member(attrs, :operator_state, @operator_states) do
      {:ok,
       %OperatorReviewProjection{
         review_ref: fetch!(attrs, :review_ref),
         context_packet_ref: fetch!(attrs, :context_packet_ref),
         route_decision_ref: fetch!(attrs, :route_decision_ref),
         eval_verdict_ref: fetch!(attrs, :eval_verdict_ref),
         promotion_refs: promotion_refs,
         rollback_refs: rollback_refs,
         operator_state: operator_state,
         trace_refs: trace_refs,
         redaction_posture: :refs_only
       }}
    end
  end

  defp packet(attrs) do
    case fetch(attrs, :context_packet) do
      nil -> ContextPacket.new(attrs)
      %ContextPacket{} = packet -> ContextPacket.new(packet)
      packet_attrs when is_map(packet_attrs) -> ContextPacket.new(packet_attrs)
      _other -> {:error, {:invalid_context_surface_ref, :context_packet}}
    end
  end

  defp reject_raw(attrs) do
    case raw_key(attrs) do
      nil -> :ok
      key -> {:error, {:raw_context_surface_payload_forbidden, key}}
    end
  end

  defp raw_key(%_struct{} = value), do: value |> Map.from_struct() |> raw_key()

  defp raw_key(value) when is_map(value) do
    Enum.find_value(value, fn {key, nested} ->
      key_string = key |> to_string() |> String.downcase()

      cond do
        key in @raw_keys -> key
        String.starts_with?(key_string, "raw_") -> key
        true -> raw_key(nested)
      end
    end)
  end

  defp raw_key(value) when is_list(value), do: Enum.find_value(value, &raw_key/1)
  defp raw_key(_value), do: nil

  defp required_strings(attrs, fields) do
    case Enum.find(fields, &(not present_string?(fetch(attrs, &1)))) do
      nil -> :ok
      field -> {:error, {:missing_context_surface_ref, field}}
    end
  end

  defp non_empty_string_list(attrs, field) do
    case string_list(attrs, field, []) do
      {:ok, [_value | _rest] = values} -> {:ok, values}
      {:ok, []} -> {:error, {:missing_context_surface_refs, field}}
      error -> error
    end
  end

  defp string_list(attrs, field, default) do
    values = fetch(attrs, field, default)

    if is_list(values) and Enum.all?(values, &present_string?/1) do
      {:ok, values}
    else
      {:error, {:invalid_context_surface_refs, field}}
    end
  end

  defp member(attrs, field, allowed) do
    value = fetch(attrs, field)

    cond do
      value in allowed ->
        {:ok, value}

      is_binary(value) ->
        case Enum.find(allowed, &(Atom.to_string(&1) == value)) do
          nil -> {:error, {:invalid_context_surface_field, field}}
          atom -> {:ok, atom}
        end

      true ->
        {:error, {:invalid_context_surface_field, field}}
    end
  end

  defp sha256(attrs, field) do
    case fetch(attrs, field) do
      "sha256:" <> hash when byte_size(hash) == 64 ->
        if String.match?(hash, ~r/^[0-9a-f]{64}$/) do
          :ok
        else
          {:error, {:invalid_context_surface_hash, field}}
        end

      _value ->
        {:error, {:invalid_context_surface_hash, field}}
    end
  end

  defp optional_string(attrs, field) do
    case fetch(attrs, field) do
      value when is_binary(value) and value != "" -> value
      _value -> nil
    end
  end

  defp present_string?(value) when is_binary(value), do: String.trim(value) != ""
  defp present_string?(_value), do: false
  defp fetch!(attrs, field), do: fetch(attrs, field)
  defp fetch(attrs, field), do: fetch(attrs, field, nil)

  defp fetch(attrs, field, default) do
    string_field = Atom.to_string(field)

    cond do
      Map.has_key?(attrs, field) -> Map.fetch!(attrs, field)
      Map.has_key?(attrs, string_field) -> Map.fetch!(attrs, string_field)
      true -> default
    end
  end
end
