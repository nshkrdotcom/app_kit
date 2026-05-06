defmodule AppKit.CoordinationSurface.RunCreateRequest do
  @moduledoc "Coordination run creation request."
  @enforce_keys [
    :request_ref,
    :tenant_ref,
    :authority_ref,
    :actor_ref,
    :coordination_run_ref,
    :router_artifact_ref,
    :role_pack_refs,
    :provider_pool_ref,
    :memory_refs,
    :context_budget_refs,
    :cost_budget_refs,
    :trace_refs,
    :replay_refs,
    :idempotency_ref
  ]
  defstruct @enforce_keys
  @type t :: %__MODULE__{}
end

defmodule AppKit.CoordinationSurface.RouterDecisionProjection do
  @moduledoc "Router decision projection."
  @enforce_keys [
    :router_decision_ref,
    :router_artifact_ref,
    :selected_role_ref,
    :confidence_band,
    :trace_ref,
    :replay_ref
  ]
  defstruct [:fallback_reason | @enforce_keys]
  @type t :: %__MODULE__{}
end

defmodule AppKit.CoordinationSurface.RoleSelectionProjection do
  @moduledoc "Role selection projection."
  @enforce_keys [
    :role_ref,
    :prompt_ref,
    :capability_refs,
    :model_profile_refs,
    :tool_policy_ref,
    :memory_profile_ref,
    :guardrail_profile_ref,
    :verifier_profile_ref,
    :budget_ref,
    :context_budget_ref,
    :handoff_policy_ref,
    :gepa_target_refs
  ]
  defstruct @enforce_keys
  @type t :: %__MODULE__{}
end

defmodule AppKit.CoordinationSurface.ProviderPoolProjection do
  @moduledoc "Provider pool projection."
  @enforce_keys [
    :provider_pool_ref,
    :slot_refs,
    :model_profile_refs,
    :endpoint_profile_refs,
    :operation_policy_refs,
    :readiness_refs
  ]
  defstruct @enforce_keys
  @type t :: %__MODULE__{}
end

defmodule AppKit.CoordinationSurface.VerifierStateProjection do
  @moduledoc "Verifier state projection."
  @enforce_keys [
    :verifier_policy_ref,
    :verifier_result_ref,
    :score_schema_ref,
    :termination_policy_ref,
    :replay_ref,
    :trace_ref
  ]
  defstruct @enforce_keys
  @type t :: %__MODULE__{}
end

defmodule AppKit.CoordinationSurface.TurnTimelineProjection do
  @moduledoc "Turn timeline projection."
  @enforce_keys [
    :turn_refs,
    :agent_refs,
    :inference_call_refs,
    :verifier_refs,
    :handoff_refs,
    :trace_refs
  ]
  defstruct @enforce_keys
  @type t :: %__MODULE__{}
end

defmodule AppKit.CoordinationSurface.ReplayBundleProjection do
  @moduledoc "Replay bundle projection."
  @enforce_keys [
    :replay_bundle_ref,
    :coordination_run_ref,
    :trace_refs,
    :replay_refs,
    :redaction_posture
  ]
  defstruct @enforce_keys
  @type t :: %__MODULE__{}
end

defmodule AppKit.CoordinationSurface.CoordinationProjection do
  @moduledoc "Complete coordination projection."
  @enforce_keys [
    :coordination_run_ref,
    :tenant_ref,
    :authority_ref,
    :router_decision,
    :role_selection,
    :provider_pool,
    :verifier_state,
    :turn_timeline,
    :memory_refs,
    :context_budget_refs,
    :replay_bundle,
    :trace_refs,
    :redaction_posture
  ]
  defstruct @enforce_keys
  @type t :: %__MODULE__{}
end

defmodule AppKit.CoordinationSurface.RunControlRequest do
  @moduledoc "Pause, resume, or cancel coordination request."
  @enforce_keys [
    :request_ref,
    :coordination_run_ref,
    :authority_ref,
    :actor_ref,
    :control_class,
    :trace_refs
  ]
  defstruct @enforce_keys
  @type t :: %__MODULE__{}
end

defmodule AppKit.CoordinationSurface.RetryTurnRequest do
  @moduledoc "Retry failed role turn request."
  @enforce_keys [
    :request_ref,
    :coordination_run_ref,
    :failed_turn_ref,
    :authority_ref,
    :actor_ref,
    :replay_ref,
    :trace_refs
  ]
  defstruct @enforce_keys
  @type t :: %__MODULE__{}
end

defmodule AppKit.CoordinationSurface.HumanInterventionRequest do
  @moduledoc "Human intervention request."
  @enforce_keys [
    :request_ref,
    :coordination_run_ref,
    :authority_ref,
    :operator_action_ref,
    :handoff_ref,
    :trace_refs
  ]
  defstruct @enforce_keys
  @type t :: %__MODULE__{}
end

defmodule AppKit.CoordinationSurface do
  @moduledoc """
  DTO-only TRINITY coordination surface.
  """

  alias AppKit.CoordinationSurface.{
    CoordinationProjection,
    HumanInterventionRequest,
    ProviderPoolProjection,
    ReplayBundleProjection,
    RetryTurnRequest,
    RoleSelectionProjection,
    RouterDecisionProjection,
    RunControlRequest,
    RunCreateRequest,
    TurnTimelineProjection,
    VerifierStateProjection
  }

  @control_classes [:pause, :resume, :cancel]
  @confidence_bands [:high, :medium, :low, :fallback]
  @raw_keys [
    :api_key,
    :auth_header,
    :body,
    :credential_body,
    :memory_body,
    :model_output,
    :provider_payload,
    :raw_body,
    :raw_message,
    :raw_model_output,
    :raw_payload,
    :raw_prompt,
    :secret,
    :token,
    :workflow_history,
    "api_key",
    "auth_header",
    "body",
    "credential_body",
    "memory_body",
    "model_output",
    "provider_payload",
    "raw_body",
    "raw_message",
    "raw_model_output",
    "raw_payload",
    "raw_prompt",
    "secret",
    "token",
    "workflow_history"
  ]

  @spec create_run_request(map()) :: {:ok, RunCreateRequest.t()} | {:error, term()}
  def create_run_request(attrs) when is_map(attrs) do
    with :ok <- reject_raw(attrs),
         :ok <-
           required_strings(attrs, [
             :request_ref,
             :tenant_ref,
             :authority_ref,
             :actor_ref,
             :coordination_run_ref,
             :router_artifact_ref,
             :provider_pool_ref,
             :idempotency_ref
           ]),
         {:ok, role_pack_refs} <- non_empty_string_list(attrs, :role_pack_refs),
         {:ok, memory_refs} <- non_empty_string_list(attrs, :memory_refs),
         {:ok, context_budget_refs} <- non_empty_string_list(attrs, :context_budget_refs),
         {:ok, cost_budget_refs} <- non_empty_string_list(attrs, :cost_budget_refs),
         {:ok, trace_refs} <- non_empty_string_list(attrs, :trace_refs),
         {:ok, replay_refs} <- non_empty_string_list(attrs, :replay_refs) do
      {:ok,
       %RunCreateRequest{
         request_ref: fetch!(attrs, :request_ref),
         tenant_ref: fetch!(attrs, :tenant_ref),
         authority_ref: fetch!(attrs, :authority_ref),
         actor_ref: fetch!(attrs, :actor_ref),
         coordination_run_ref: fetch!(attrs, :coordination_run_ref),
         router_artifact_ref: fetch!(attrs, :router_artifact_ref),
         role_pack_refs: role_pack_refs,
         provider_pool_ref: fetch!(attrs, :provider_pool_ref),
         memory_refs: memory_refs,
         context_budget_refs: context_budget_refs,
         cost_budget_refs: cost_budget_refs,
         trace_refs: trace_refs,
         replay_refs: replay_refs,
         idempotency_ref: fetch!(attrs, :idempotency_ref)
       }}
    end
  end

  def create_run_request(_attrs), do: {:error, :invalid_coordination_run_create_request}

  @spec coordination_projection(map()) :: {:ok, CoordinationProjection.t()} | {:error, term()}
  def coordination_projection(attrs) when is_map(attrs) do
    with :ok <- reject_raw(attrs),
         :ok <- required_strings(attrs, [:coordination_run_ref, :tenant_ref, :authority_ref]),
         {:ok, router_decision} <- nested(attrs, :router_decision, &router_decision/1),
         {:ok, role_selection} <- nested(attrs, :role_selection, &role_selection/1),
         {:ok, provider_pool} <- nested(attrs, :provider_pool, &provider_pool/1),
         {:ok, verifier_state} <- nested(attrs, :verifier_state, &verifier_state/1),
         {:ok, turn_timeline} <- nested(attrs, :turn_timeline, &turn_timeline/1),
         {:ok, replay_bundle} <- nested(attrs, :replay_bundle, &replay_bundle/1),
         {:ok, memory_refs} <- non_empty_string_list(attrs, :memory_refs),
         {:ok, context_budget_refs} <- non_empty_string_list(attrs, :context_budget_refs),
         {:ok, trace_refs} <- non_empty_string_list(attrs, :trace_refs) do
      {:ok,
       %CoordinationProjection{
         coordination_run_ref: fetch!(attrs, :coordination_run_ref),
         tenant_ref: fetch!(attrs, :tenant_ref),
         authority_ref: fetch!(attrs, :authority_ref),
         router_decision: router_decision,
         role_selection: role_selection,
         provider_pool: provider_pool,
         verifier_state: verifier_state,
         turn_timeline: turn_timeline,
         memory_refs: memory_refs,
         context_budget_refs: context_budget_refs,
         replay_bundle: replay_bundle,
         trace_refs: trace_refs,
         redaction_posture: :refs_only
       }}
    end
  end

  def coordination_projection(_attrs), do: {:error, :invalid_coordination_projection}

  @spec router_decision(map()) :: {:ok, RouterDecisionProjection.t()} | {:error, term()}
  def router_decision(attrs) when is_map(attrs) do
    with :ok <- reject_raw(attrs),
         :ok <-
           required_strings(attrs, [
             :router_decision_ref,
             :router_artifact_ref,
             :selected_role_ref,
             :trace_ref,
             :replay_ref
           ]),
         {:ok, confidence_band} <- confidence_band(attrs) do
      {:ok,
       %RouterDecisionProjection{
         router_decision_ref: fetch!(attrs, :router_decision_ref),
         router_artifact_ref: fetch!(attrs, :router_artifact_ref),
         selected_role_ref: fetch!(attrs, :selected_role_ref),
         confidence_band: confidence_band,
         fallback_reason: fetch(attrs, :fallback_reason),
         trace_ref: fetch!(attrs, :trace_ref),
         replay_ref: fetch!(attrs, :replay_ref)
       }}
    end
  end

  def router_decision(_attrs), do: {:error, :invalid_router_decision_projection}

  @spec role_selection(map()) :: {:ok, RoleSelectionProjection.t()} | {:error, term()}
  def role_selection(attrs) when is_map(attrs) do
    with :ok <- reject_raw(attrs),
         :ok <-
           required_strings(attrs, [
             :role_ref,
             :prompt_ref,
             :tool_policy_ref,
             :memory_profile_ref,
             :guardrail_profile_ref,
             :verifier_profile_ref,
             :budget_ref,
             :context_budget_ref,
             :handoff_policy_ref
           ]),
         {:ok, capability_refs} <- non_empty_string_list(attrs, :capability_refs),
         {:ok, model_profile_refs} <- non_empty_string_list(attrs, :model_profile_refs),
         {:ok, gepa_target_refs} <- non_empty_string_list(attrs, :gepa_target_refs) do
      {:ok,
       %RoleSelectionProjection{
         role_ref: fetch!(attrs, :role_ref),
         prompt_ref: fetch!(attrs, :prompt_ref),
         capability_refs: capability_refs,
         model_profile_refs: model_profile_refs,
         tool_policy_ref: fetch!(attrs, :tool_policy_ref),
         memory_profile_ref: fetch!(attrs, :memory_profile_ref),
         guardrail_profile_ref: fetch!(attrs, :guardrail_profile_ref),
         verifier_profile_ref: fetch!(attrs, :verifier_profile_ref),
         budget_ref: fetch!(attrs, :budget_ref),
         context_budget_ref: fetch!(attrs, :context_budget_ref),
         handoff_policy_ref: fetch!(attrs, :handoff_policy_ref),
         gepa_target_refs: gepa_target_refs
       }}
    end
  end

  def role_selection(_attrs), do: {:error, :invalid_role_selection_projection}

  @spec provider_pool(map()) :: {:ok, ProviderPoolProjection.t()} | {:error, term()}
  def provider_pool(attrs) when is_map(attrs) do
    with :ok <- reject_raw(attrs),
         :ok <- required_strings(attrs, [:provider_pool_ref]),
         {:ok, slot_refs} <- non_empty_string_list(attrs, :slot_refs),
         {:ok, model_profile_refs} <- non_empty_string_list(attrs, :model_profile_refs),
         {:ok, endpoint_profile_refs} <- non_empty_string_list(attrs, :endpoint_profile_refs),
         {:ok, operation_policy_refs} <- non_empty_string_list(attrs, :operation_policy_refs),
         {:ok, readiness_refs} <- non_empty_string_list(attrs, :readiness_refs) do
      {:ok,
       %ProviderPoolProjection{
         provider_pool_ref: fetch!(attrs, :provider_pool_ref),
         slot_refs: slot_refs,
         model_profile_refs: model_profile_refs,
         endpoint_profile_refs: endpoint_profile_refs,
         operation_policy_refs: operation_policy_refs,
         readiness_refs: readiness_refs
       }}
    end
  end

  def provider_pool(_attrs), do: {:error, :invalid_provider_pool_projection}

  @spec verifier_state(map()) :: {:ok, VerifierStateProjection.t()} | {:error, term()}
  def verifier_state(attrs) when is_map(attrs) do
    with :ok <- reject_raw(attrs),
         :ok <-
           required_strings(attrs, [
             :verifier_policy_ref,
             :verifier_result_ref,
             :score_schema_ref,
             :termination_policy_ref,
             :replay_ref,
             :trace_ref
           ]) do
      {:ok,
       %VerifierStateProjection{
         verifier_policy_ref: fetch!(attrs, :verifier_policy_ref),
         verifier_result_ref: fetch!(attrs, :verifier_result_ref),
         score_schema_ref: fetch!(attrs, :score_schema_ref),
         termination_policy_ref: fetch!(attrs, :termination_policy_ref),
         replay_ref: fetch!(attrs, :replay_ref),
         trace_ref: fetch!(attrs, :trace_ref)
       }}
    end
  end

  def verifier_state(_attrs), do: {:error, :invalid_verifier_state_projection}

  @spec turn_timeline(map()) :: {:ok, TurnTimelineProjection.t()} | {:error, term()}
  def turn_timeline(attrs) when is_map(attrs) do
    with :ok <- reject_raw(attrs),
         {:ok, turn_refs} <- non_empty_string_list(attrs, :turn_refs),
         {:ok, agent_refs} <- non_empty_string_list(attrs, :agent_refs),
         {:ok, inference_call_refs} <- non_empty_string_list(attrs, :inference_call_refs),
         {:ok, verifier_refs} <- non_empty_string_list(attrs, :verifier_refs),
         {:ok, handoff_refs} <- non_empty_string_list(attrs, :handoff_refs),
         {:ok, trace_refs} <- non_empty_string_list(attrs, :trace_refs) do
      {:ok,
       %TurnTimelineProjection{
         turn_refs: turn_refs,
         agent_refs: agent_refs,
         inference_call_refs: inference_call_refs,
         verifier_refs: verifier_refs,
         handoff_refs: handoff_refs,
         trace_refs: trace_refs
       }}
    end
  end

  def turn_timeline(_attrs), do: {:error, :invalid_turn_timeline_projection}

  @spec replay_bundle(map()) :: {:ok, ReplayBundleProjection.t()} | {:error, term()}
  def replay_bundle(attrs) when is_map(attrs) do
    with :ok <- reject_raw(attrs),
         :ok <- required_strings(attrs, [:replay_bundle_ref, :coordination_run_ref]),
         {:ok, trace_refs} <- non_empty_string_list(attrs, :trace_refs),
         {:ok, replay_refs} <- non_empty_string_list(attrs, :replay_refs),
         :ok <- require_refs_only(attrs) do
      {:ok,
       %ReplayBundleProjection{
         replay_bundle_ref: fetch!(attrs, :replay_bundle_ref),
         coordination_run_ref: fetch!(attrs, :coordination_run_ref),
         trace_refs: trace_refs,
         replay_refs: replay_refs,
         redaction_posture: :refs_only
       }}
    end
  end

  def replay_bundle(_attrs), do: {:error, :invalid_replay_bundle_projection}

  @spec run_control(map()) :: {:ok, RunControlRequest.t()} | {:error, term()}
  def run_control(attrs) when is_map(attrs) do
    with :ok <- reject_raw(attrs),
         :ok <-
           required_strings(attrs, [
             :request_ref,
             :coordination_run_ref,
             :authority_ref,
             :actor_ref
           ]),
         {:ok, control_class} <- control_class(attrs),
         {:ok, trace_refs} <- non_empty_string_list(attrs, :trace_refs) do
      {:ok,
       %RunControlRequest{
         request_ref: fetch!(attrs, :request_ref),
         coordination_run_ref: fetch!(attrs, :coordination_run_ref),
         authority_ref: fetch!(attrs, :authority_ref),
         actor_ref: fetch!(attrs, :actor_ref),
         control_class: control_class,
         trace_refs: trace_refs
       }}
    end
  end

  def run_control(_attrs), do: {:error, :invalid_coordination_control_request}

  @spec retry_turn(map()) :: {:ok, RetryTurnRequest.t()} | {:error, term()}
  def retry_turn(attrs) when is_map(attrs) do
    with :ok <- reject_raw(attrs),
         :ok <-
           required_strings(attrs, [
             :request_ref,
             :coordination_run_ref,
             :failed_turn_ref,
             :authority_ref,
             :actor_ref,
             :replay_ref
           ]),
         {:ok, trace_refs} <- non_empty_string_list(attrs, :trace_refs) do
      {:ok,
       %RetryTurnRequest{
         request_ref: fetch!(attrs, :request_ref),
         coordination_run_ref: fetch!(attrs, :coordination_run_ref),
         failed_turn_ref: fetch!(attrs, :failed_turn_ref),
         authority_ref: fetch!(attrs, :authority_ref),
         actor_ref: fetch!(attrs, :actor_ref),
         replay_ref: fetch!(attrs, :replay_ref),
         trace_refs: trace_refs
       }}
    end
  end

  def retry_turn(_attrs), do: {:error, :invalid_retry_turn_request}

  @spec human_intervention_request(map()) ::
          {:ok, HumanInterventionRequest.t()} | {:error, term()}
  def human_intervention_request(attrs) when is_map(attrs) do
    with :ok <- reject_raw(attrs),
         :ok <-
           required_strings(attrs, [
             :request_ref,
             :coordination_run_ref,
             :authority_ref,
             :operator_action_ref,
             :handoff_ref
           ]),
         {:ok, trace_refs} <- non_empty_string_list(attrs, :trace_refs) do
      {:ok,
       %HumanInterventionRequest{
         request_ref: fetch!(attrs, :request_ref),
         coordination_run_ref: fetch!(attrs, :coordination_run_ref),
         authority_ref: fetch!(attrs, :authority_ref),
         operator_action_ref: fetch!(attrs, :operator_action_ref),
         handoff_ref: fetch!(attrs, :handoff_ref),
         trace_refs: trace_refs
       }}
    end
  end

  def human_intervention_request(_attrs), do: {:error, :invalid_human_intervention_request}

  defp nested(attrs, field, fun) do
    case fetch(attrs, field) do
      nested_attrs when is_map(nested_attrs) -> fun.(nested_attrs)
      _other -> {:error, {:missing_required_projection, field}}
    end
  end

  defp confidence_band(attrs) do
    value = fetch(attrs, :confidence_band)
    if value in @confidence_bands, do: {:ok, value}, else: {:error, :invalid_confidence_band}
  end

  defp control_class(attrs) do
    value = fetch(attrs, :control_class)
    if value in @control_classes, do: {:ok, value}, else: {:error, :invalid_control_class}
  end

  defp require_refs_only(attrs) do
    if fetch(attrs, :redaction_posture) == :refs_only do
      :ok
    else
      {:error, :replay_bundle_must_be_refs_only}
    end
  end

  defp required_strings(attrs, fields) do
    case Enum.find(fields, &(present_string?(fetch(attrs, &1)) == false)) do
      nil -> :ok
      field -> {:error, {:missing_required_ref, field}}
    end
  end

  defp non_empty_string_list(attrs, field) do
    values = fetch(attrs, field, [])

    if is_list(values) and values != [] and Enum.all?(values, &present_string?/1) do
      {:ok, values}
    else
      {:error, {:invalid_ref_list, field}}
    end
  end

  defp reject_raw(value) do
    case raw_key(value) do
      nil -> :ok
      key -> {:error, {:raw_coordination_surface_payload_forbidden, key}}
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

  defp fetch!(attrs, field), do: fetch(attrs, field)

  defp fetch(attrs, field, default \\ nil) do
    string_field = Atom.to_string(field)

    cond do
      Map.has_key?(attrs, field) -> Map.fetch!(attrs, field)
      Map.has_key?(attrs, string_field) -> Map.fetch!(attrs, string_field)
      true -> default
    end
  end

  defp present_string?(value), do: is_binary(value) and String.trim(value) != ""
end
