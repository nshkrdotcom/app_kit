defmodule Mezzanine.AppKitBridge.OperatorActionService do
  @moduledoc """
  Backend-oriented operator actions and review-decision writes.
  """

  alias AppKit.Core.RunRef
  alias Mezzanine.AppKitBridge.AdapterSupport
  alias Mezzanine.AppKitBridge.ReviewActionService
  alias Mezzanine.Execution.LifecycleContinuation
  alias Mezzanine.OperatorActions

  @supported_actions [
    :pause,
    :resume,
    :cancel,
    :replan,
    :grant_override,
    :retry_continuation,
    :waive_continuation
  ]

  @spec apply_action(String.t(), Ecto.UUID.t(), atom() | String.t(), map(), map()) ::
          {:ok, map()} | {:error, term()}
  def apply_action(tenant_id, subject_id, action, params, actor)
      when is_binary(tenant_id) and is_binary(subject_id) and is_map(params) and is_map(actor) do
    with {:ok, action} <- normalize_action(action),
         {:ok, bridge_result} <- dispatch_action(action, tenant_id, subject_id, params, actor) do
      {:ok,
       %{
         status: :completed,
         action_ref: action_ref(subject_id, action),
         message: action_message(action),
         metadata: normalize_value(bridge_result)
       }}
    else
      {:error, reason} -> {:error, normalize_error(reason)}
    end
  end

  @spec review_run(RunRef.t(), map(), keyword()) :: {:ok, map()} | {:error, atom()}
  def review_run(%RunRef{} = run_ref, evidence_attrs, opts \\ [])
      when is_map(evidence_attrs) and is_list(opts) do
    with {:ok, result} <- ReviewActionService.record_run_review(run_ref, evidence_attrs, opts) do
      {:ok,
       %{
         decision: result.metadata.decision,
         review_unit: result.metadata.review_unit,
         bridge_result: result.metadata.bridge_result
       }}
    end
  end

  @spec record_review_decision(RunRef.t(), map(), keyword()) :: {:ok, map()} | {:error, atom()}
  def record_review_decision(%RunRef{} = run_ref, evidence_attrs, opts \\ [])
      when is_map(evidence_attrs) and is_list(opts) do
    ReviewActionService.record_run_review(run_ref, evidence_attrs, opts)
  end

  defp dispatch_action(:pause, tenant_id, subject_id, params, actor) do
    OperatorActions.pause_work(tenant_id, subject_id, actor_ref(actor, []), params)
  end

  defp dispatch_action(:resume, tenant_id, subject_id, params, actor) do
    OperatorActions.resume_work(tenant_id, subject_id, actor_ref(actor, []), params)
  end

  defp dispatch_action(:cancel, tenant_id, subject_id, params, actor) do
    OperatorActions.cancel_work(tenant_id, subject_id, actor_ref(actor, []), params)
  end

  defp dispatch_action(:replan, tenant_id, subject_id, params, actor) do
    OperatorActions.request_replan(tenant_id, subject_id, actor_ref(actor, []), params)
  end

  defp dispatch_action(:grant_override, tenant_id, subject_id, params, actor) do
    OperatorActions.override_grant_profile(
      tenant_id,
      subject_id,
      actor_ref(actor, []),
      grant_override_payload(params)
    )
  end

  defp dispatch_action(:retry_continuation, _tenant_id, subject_id, params, actor) do
    with {:ok, continuation_id} <- continuation_id(params) do
      LifecycleContinuation.retry(
        continuation_id,
        operator_continuation_opts(
          :retry_continuation,
          subject_id,
          continuation_id,
          params,
          actor
        )
      )
    end
  end

  defp dispatch_action(:waive_continuation, _tenant_id, subject_id, params, actor) do
    with {:ok, continuation_id} <- continuation_id(params) do
      opts =
        :waive_continuation
        |> operator_continuation_opts(subject_id, continuation_id, params, actor)
        |> Keyword.put(:reason, param(params, :reason, "operator waived"))

      LifecycleContinuation.waive(continuation_id, opts)
    end
  end

  defp operator_continuation_opts(action, subject_id, continuation_id, params, actor) do
    [
      operator_action_ref:
        param(
          params,
          :operator_action_ref,
          "operator-action://#{subject_id}/#{action}/#{continuation_id}"
        ),
      operator_actor_ref: actor_ref(actor, []),
      authority_decision_ref:
        param(
          params,
          :authority_decision_ref,
          "authority-decision://#{subject_id}/#{action}/#{continuation_id}"
        ),
      safe_action:
        param(
          params,
          :safe_action,
          default_safe_action(action)
        ),
      blast_radius:
        param(
          params,
          :blast_radius,
          "single_subject"
        )
    ]
  end

  defp default_safe_action(:retry_continuation), do: "operator_retry_lifecycle_continuation"
  defp default_safe_action(:waive_continuation), do: "operator_waive_lifecycle_continuation"

  defp param(params, key, default) do
    Map.get(params, key) || Map.get(params, Atom.to_string(key)) || default
  end

  defp normalize_action(action) when action in @supported_actions, do: {:ok, action}

  defp normalize_action(action) when is_binary(action) do
    case Enum.find(@supported_actions, &(Atom.to_string(&1) == action)) do
      nil -> {:error, :unsupported_action}
      normalized -> {:ok, normalized}
    end
  end

  defp normalize_action(_action), do: {:error, :unsupported_action}

  defp grant_override_payload(params) do
    Map.get(params, :grant_overrides) || Map.get(params, "grant_overrides") ||
      Map.get(params, :active_override_set) || Map.get(params, "active_override_set") || params
  end

  defp continuation_id(params) do
    case Map.get(params, :continuation_id) || Map.get(params, "continuation_id") do
      value when is_binary(value) -> {:ok, value}
      _other -> {:error, :missing_continuation_id}
    end
  end

  defp action_ref(subject_id, action) do
    %{
      id: "#{subject_id}:#{action}",
      action_kind: Atom.to_string(action),
      subject_ref: %{id: subject_id, subject_kind: "work_object"}
    }
  end

  defp action_message(:pause), do: "Work paused"
  defp action_message(:resume), do: "Work resumed"
  defp action_message(:cancel), do: "Work cancelled"
  defp action_message(:replan), do: "Replan requested"
  defp action_message(:grant_override), do: "Grant override applied"
  defp action_message(:retry_continuation), do: "Lifecycle continuation retry requested"
  defp action_message(:waive_continuation), do: "Lifecycle continuation waived"

  defp actor_ref(attrs, opts), do: AdapterSupport.actor_ref(attrs, opts)
  defp normalize_value(value), do: AdapterSupport.normalize_value(value)
  defp normalize_error(reason), do: AdapterSupport.normalize_error(reason)
end
