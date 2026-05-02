defmodule Mezzanine.AppKitBridge.OperatorActionService do
  @moduledoc """
  Backend-oriented operator actions and review-decision writes.
  """

  alias AppKit.Core.RunRef
  alias Mezzanine.AppKitBridge.AdapterSupport
  alias Mezzanine.AppKitBridge.ReviewActionService
  alias Mezzanine.Audit.AuditAppend
  alias Mezzanine.ConfigRegistry.Installation
  alias Mezzanine.DecisionCommands
  alias Mezzanine.Decisions.DecisionRecord
  alias Mezzanine.Execution.LifecycleContinuation
  alias Mezzanine.Objects.SubjectRecord
  alias Mezzanine.OperatorActions
  alias Mezzanine.OperatorCommands
  alias Mezzanine.SourceEngine.SourceRefreshRequest

  @supported_actions [
    :accept,
    :pause,
    :resume,
    :cancel,
    :refresh,
    :replan,
    :rework,
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
    if subject_record_control?(params) do
      dispatch_subject_cancel(tenant_id, subject_id, params, actor)
    else
      OperatorActions.cancel_work(tenant_id, subject_id, actor_ref(actor, []), params)
    end
  end

  defp dispatch_action(:accept, tenant_id, subject_id, params, actor) do
    dispatch_decision_resolution(:accept, tenant_id, subject_id, params, actor)
  end

  defp dispatch_action(:rework, tenant_id, subject_id, params, actor) do
    dispatch_decision_resolution(:rework, tenant_id, subject_id, params, actor)
  end

  defp dispatch_action(:refresh, tenant_id, subject_id, params, actor) do
    dispatch_source_refresh(tenant_id, subject_id, params, actor)
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

  defp dispatch_decision_resolution(action, tenant_id, subject_id, params, actor) do
    with {:ok, decision_id} <- required_param(params, :decision_id, :missing_decision_id),
         {:ok, decision} <- load_decision(decision_id),
         :ok <- ensure_decision_subject(decision, subject_id),
         {:ok, scope} <- command_scope(tenant_id, decision.installation_id, params, actor),
         command_attrs <- decision_command_attrs(action, decision, scope, params),
         {:ok, updated_decision} <- resolve_decision(action, decision, command_attrs) do
      {:ok,
       %{
         decision: updated_decision,
         decision_id: updated_decision.id,
         subject_id: updated_decision.subject_id,
         installation_id: updated_decision.installation_id,
         lifecycle_state: updated_decision.lifecycle_state,
         decision_value: updated_decision.decision_value,
         idempotency_key: command_attrs.idempotency_key,
         authority: authority_payload(scope, command_attrs)
       }}
    end
  end

  defp dispatch_subject_cancel(tenant_id, subject_id, params, actor) do
    with {:ok, subject} <- load_subject(subject_id),
         {:ok, scope} <- command_scope(tenant_id, subject.installation_id, params, actor),
         opts <- subject_command_opts(:cancel, subject, scope, params),
         {:ok, result} <- OperatorCommands.cancel(subject.id, opts) do
      {:ok, Map.put(result, :authority, authority_payload(scope, Map.new(opts)))}
    end
  end

  defp dispatch_source_refresh(tenant_id, subject_id, params, actor) do
    with {:ok, subject} <- load_subject(subject_id),
         {:ok, scope} <- command_scope(tenant_id, subject.installation_id, params, actor),
         {:ok, source_binding_id} <-
           refresh_source_binding_id(subject, params),
         refresh_attrs <- refresh_attrs(subject, source_binding_id, scope, params),
         {:ok, refresh} <- SourceRefreshRequest.request(refresh_attrs),
         {:ok, audit} <-
           append_operator_audit(:source_refresh_requested, subject, nil, refresh_attrs) do
      {:ok,
       refresh
       |> Map.put(:audit, audit)
       |> Map.put(:authority, authority_payload(scope, refresh_attrs))}
    end
  end

  defp resolve_decision(:accept, decision, command_attrs),
    do: DecisionCommands.accept(decision, command_attrs)

  defp resolve_decision(:rework, decision, command_attrs),
    do: DecisionCommands.decide(decision, Map.put(command_attrs, :decision_value, "rework"))

  defp subject_record_control?(params) do
    owner = param(params, :control_owner, nil)

    owner in ["subject_record", :subject_record]
  end

  defp load_decision(decision_id) do
    case Ash.get(DecisionRecord, decision_id, authorize?: false, domain: Mezzanine.Decisions) do
      {:ok, %DecisionRecord{} = decision} -> {:ok, decision}
      {:ok, nil} -> {:error, :decision_not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  defp load_subject(subject_id) do
    case Ash.get(SubjectRecord, subject_id, authorize?: false, domain: Mezzanine.Objects) do
      {:ok, %SubjectRecord{} = subject} -> {:ok, subject}
      {:ok, nil} -> {:error, :subject_not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  defp ensure_decision_subject(%DecisionRecord{subject_id: subject_id}, subject_id), do: :ok
  defp ensure_decision_subject(_decision, _subject_id), do: {:error, :decision_subject_mismatch}

  defp command_scope(tenant_id, installation_id, params, actor) do
    context = operator_context(params)
    actor_ref = command_actor_ref(context, actor, tenant_id)

    with :ok <- ensure_context_tenant(context, tenant_id),
         :ok <- ensure_actor_tenant(actor_ref, tenant_id),
         :ok <- ensure_installation_authorized(tenant_id, installation_id, context) do
      {:ok,
       %{
         tenant_id: tenant_id,
         installation_id: installation_id,
         actor_ref: actor_ref,
         trace_id: context_value(context, :trace_id) || "operator-actions:#{installation_id}",
         causation_id:
           context_value(context, :causation_id) ||
             "operator-actions:#{installation_id}:#{System.unique_integer([:positive])}",
         idempotency_key: context_value(context, :idempotency_key)
       }}
    end
  end

  defp ensure_context_tenant(context, tenant_id) do
    case context_value(context, :tenant_id) do
      nil -> :ok
      ^tenant_id -> :ok
      _other -> {:error, :cross_tenant_operator_command_denied}
    end
  end

  defp ensure_actor_tenant(actor_ref, tenant_id) do
    case Map.get(actor_ref, "tenant_id") do
      nil -> :ok
      ^tenant_id -> :ok
      _other -> {:error, :operator_actor_tenant_mismatch}
    end
  end

  defp ensure_installation_authorized(tenant_id, installation_id, context) do
    with :ok <- ensure_requested_installation(installation_id, context) do
      cond do
        installation_id == tenant_id ->
          :ok

        installation_belongs_to_tenant?(installation_id, tenant_id) ->
          :ok

        true ->
          {:error, :cross_tenant_operator_command_denied}
      end
    end
  end

  defp ensure_requested_installation(installation_id, context) do
    case context_value(context, :installation_id) do
      nil -> :ok
      ^installation_id -> :ok
      _other -> {:error, :cross_tenant_operator_command_denied}
    end
  end

  defp installation_belongs_to_tenant?(installation_id, tenant_id) do
    case Ash.get(Installation, installation_id,
           authorize?: false,
           domain: Mezzanine.ConfigRegistry
         ) do
      {:ok, %Installation{tenant_id: ^tenant_id}} -> true
      _other -> false
    end
  end

  defp decision_command_attrs(action, decision, scope, params) do
    %{
      tenant_id: scope.tenant_id,
      authorized_installation_id: decision.installation_id,
      reason: param(params, :reason, nil),
      trace_id: scope.trace_id,
      causation_id: scope.causation_id,
      actor_ref: scope.actor_ref,
      expected_row_version: optional_param(params, :expected_row_version),
      attempt_id: command_attempt_id(action, decision, scope),
      idempotency_key:
        scope.idempotency_key ||
          "decision-terminal:#{scope.tenant_id}:#{decision.id}:#{action}:#{scope.causation_id}"
    }
    |> Map.reject(fn {_key, value} -> is_nil(value) end)
  end

  defp subject_command_opts(action, subject, scope, params) do
    [
      tenant_id: scope.tenant_id,
      authorized_installation_id: subject.installation_id,
      reason: param(params, :reason, nil),
      trace_id: scope.trace_id,
      causation_id: scope.causation_id,
      actor_ref: scope.actor_ref,
      idempotency_key:
        scope.idempotency_key ||
          "subject-command:#{scope.tenant_id}:#{subject.id}:#{action}:#{scope.causation_id}"
    ]
  end

  defp refresh_attrs(subject, source_binding_id, scope, params) do
    %{
      tenant_id: scope.tenant_id,
      installation_id: subject.installation_id,
      subject_id: subject.id,
      source_binding_id: source_binding_id,
      cursor: param(params, :cursor, nil),
      trace_id: scope.trace_id,
      causation_id: scope.causation_id,
      actor_ref: scope.actor_ref,
      reason: param(params, :reason, nil),
      idempotency_key:
        scope.idempotency_key ||
          "source-refresh:#{scope.tenant_id}:#{subject.id}:#{source_binding_id}:#{scope.causation_id}"
    }
    |> Map.reject(fn {_key, value} -> is_nil(value) end)
  end

  defp refresh_source_binding_id(subject, params) do
    case param(params, :source_binding_id, nil) || subject.source_binding_id do
      value when is_binary(value) and value != "" -> {:ok, value}
      _other -> {:error, :missing_source_binding_id}
    end
  end

  defp append_operator_audit(fact_kind, subject, decision, attrs) do
    AuditAppend.append_fact(%{
      installation_id: attrs.installation_id,
      subject_id: subject.id,
      decision_id: decision && decision.id,
      trace_id: attrs.trace_id,
      causation_id: attrs.causation_id,
      fact_kind: fact_kind,
      actor_ref: attrs.actor_ref,
      idempotency_key: attrs.idempotency_key,
      payload: %{
        tenant_id: attrs.tenant_id,
        installation_id: attrs.installation_id,
        subject_id: subject.id,
        decision_id: decision && decision.id,
        reason: Map.get(attrs, :reason),
        safe_action: Atom.to_string(fact_kind)
      }
    })
  end

  defp authority_payload(scope, attrs) do
    %{
      tenant_id: scope.tenant_id,
      installation_id: scope.installation_id,
      actor_ref: scope.actor_ref,
      trace_id: scope.trace_id,
      causation_id: scope.causation_id,
      idempotency_key: Map.get(attrs, :idempotency_key)
    }
  end

  defp command_attempt_id(action, decision, scope),
    do: "operator-action:#{scope.tenant_id}:#{decision.id}:#{action}:#{scope.causation_id}"

  defp operator_context(params) do
    case param(params, :operator_context, %{}) do
      context when is_map(context) -> stringify_keys(context)
      _other -> %{}
    end
  end

  defp context_value(context, key),
    do: Map.get(context, Atom.to_string(key)) || Map.get(context, key)

  defp command_actor_ref(context, actor, tenant_id) do
    case context_value(context, :actor_ref) do
      actor_ref when is_map(actor_ref) ->
        actor_ref
        |> stringify_keys()
        |> Map.put_new("tenant_id", tenant_id)

      _other ->
        %{
          "kind" => "operator",
          "id" => actor_ref(actor, []),
          "tenant_id" => tenant_id
        }
    end
  end

  defp required_param(params, key, error) do
    case param(params, key, nil) do
      value when is_binary(value) and value != "" -> {:ok, value}
      _other -> {:error, error}
    end
  end

  defp optional_param(params, key), do: param(params, key, nil)

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
  defp action_message(:accept), do: "Review accepted"
  defp action_message(:cancel), do: "Work cancelled"
  defp action_message(:refresh), do: "Source refresh requested"
  defp action_message(:replan), do: "Replan requested"
  defp action_message(:rework), do: "Review sent for rework"
  defp action_message(:grant_override), do: "Grant override applied"
  defp action_message(:retry_continuation), do: "Lifecycle continuation retry requested"
  defp action_message(:waive_continuation), do: "Lifecycle continuation waived"

  defp actor_ref(attrs, opts), do: AdapterSupport.actor_ref(attrs, opts)
  defp normalize_value(value), do: AdapterSupport.normalize_value(value)
  defp normalize_error(reason), do: AdapterSupport.normalize_error(reason)

  defp stringify_keys(value) when is_map(value) do
    Map.new(value, fn {key, nested} -> {to_string(key), nested} end)
  end
end
