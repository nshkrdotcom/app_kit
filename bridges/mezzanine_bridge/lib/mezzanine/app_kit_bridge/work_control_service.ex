defmodule Mezzanine.AppKitBridge.WorkControlService do
  @moduledoc """
  Backend-oriented run-start service for the transitional AppKit bridge.
  """

  alias AppKit.Core.{RequestContext, Result, RunRef, RunRequest}
  alias Mezzanine.AppKitBridge.AdapterSupport
  alias Mezzanine.M1M2Runtime.DeterministicLowerCompletion
  alias Mezzanine.M1M2Runtime.WorkflowStartHandoff
  alias Mezzanine.WorkControl
  alias Mezzanine.WorkExecutionHandoff

  @typep request_context_input :: %{
           required(:__struct__) => RequestContext,
           required(:trace_id) => String.t(),
           required(:actor_ref) => %{required(:id) => String.t()},
           required(:tenant_ref) => %{required(:id) => String.t()},
           optional(:installation_ref) => map() | nil,
           optional(:causation_id) => String.t() | nil,
           optional(:request_id) => String.t() | nil,
           optional(:idempotency_key) => String.t() | nil,
           optional(:feature_flags) => %{optional(String.t()) => boolean()},
           optional(:metadata) => map()
         }

  @typep run_request_input :: %{
           required(:__struct__) => RunRequest,
           required(:subject_ref) => %{required(:id) => String.t()},
           optional(:recipe_ref) => String.t() | nil,
           optional(:params) => map(),
           optional(:reason) => String.t() | nil,
           optional(:metadata) => map()
         }

  @spec start_run(map(), keyword()) :: {:ok, Result.t()} | {:error, atom()}
  def start_run(domain_call, opts \\ []) when is_map(domain_call) and is_list(opts) do
    attrs = Map.new(domain_call)

    with {:ok, tenant_id} <- fetch_tenant_id(opts),
         {:ok, program_id} <- fetch_program_id(attrs, opts),
         {:ok, work_class_id} <- fetch_work_class_id(attrs, opts),
         {:ok, prepared} <-
           WorkControl.prepare_run_request(
             tenant_id,
             Map.merge(attrs, %{program_id: program_id, work_class_id: work_class_id})
           ),
         {:ok, run_ref} <- build_run_ref(prepared.plan, prepared.work_object, attrs, opts),
         {:ok, result} <- build_result(run_ref, prepared.work_object, prepared.plan) do
      {:ok, result}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @spec start_run(request_context_input(), run_request_input(), keyword()) ::
          {:ok, Result.t()} | {:error, atom()}
  def start_run(%RequestContext{} = context, %RunRequest{} = run_request, opts)
      when is_list(opts) do
    start_attrs = lower_start_attrs(context, run_request)

    with {:ok, tenant_id} <- fetch_tenant_id(context, opts),
         {:ok, started} <-
           WorkControl.start_run_for_subject(
             tenant_id,
             run_request.subject_ref.id,
             start_attrs
           ),
         {:ok, workflow_handoff} <-
           WorkflowStartHandoff.enqueue_start(
             tenant_id,
             workflow_handoff_started_run(started),
             start_attrs
           ),
         {:ok, execution_handoff} <-
           WorkExecutionHandoff.ensure_current_execution(
             tenant_id,
             workflow_handoff_started_run(started),
             workflow_handoff,
             start_attrs
           ),
         {:ok, execution_handoff} <-
           maybe_complete_deterministic_lower(
             tenant_id,
             workflow_handoff_started_run(started),
             workflow_handoff,
             execution_handoff,
             start_attrs,
             opts
           ),
         typed_context =
           typed_start_context(context, run_request, started, workflow_handoff, execution_handoff),
         {:ok, run_ref} <- build_typed_run_ref(typed_context, opts),
         {:ok, result} <- build_typed_result(typed_context, run_ref) do
      {:ok, result}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp build_run_ref(plan, work_object, attrs, opts) do
    intent = first_run_intent(plan)

    RunRef.new(%{
      run_id: map_value(intent, :intent_id) || "work/#{work_object.id}",
      scope_id: Keyword.get(opts, :scope_id, "program/#{work_object.program_id}"),
      metadata: %{
        tenant_id: Keyword.get(opts, :tenant_id),
        work_object_id: work_object.id,
        plan_id: plan.id,
        review_required: review_required?(plan),
        review_unit_id: Map.get(attrs, :review_unit_id, Map.get(attrs, "review_unit_id")),
        program_id: work_object.program_id
      }
    })
    |> normalize_result(:invalid_run_ref)
  end

  defp build_result(run_ref, work_object, plan) do
    state = if review_required?(plan), do: :waiting_review, else: :scheduled

    Result.new(%{
      surface: :work_control,
      state: state,
      payload: %{
        run_ref: run_ref,
        work_object_id: work_object.id,
        plan_id: plan.id,
        run_intent: first_run_intent(plan),
        review_required: review_required?(plan)
      }
    })
    |> normalize_result(:invalid_result)
  end

  defp build_typed_run_ref(
         %{
           request_context: %RequestContext{} = context,
           run_request: %RunRequest{} = run_request,
           work_object: work_object,
           plan: plan,
           run: run,
           review_unit: review_unit,
           workflow_handoff: workflow_handoff,
           execution_handoff: execution_handoff
         },
         opts
       ) do
    RunRef.new(%{
      run_id: run.id,
      scope_id: Keyword.get(opts, :scope_id, "program/#{work_object.program_id}"),
      metadata:
        %{
          tenant_id: context.tenant_ref.id,
          work_object_id: work_object.id,
          plan_id: plan.id,
          program_id: work_object.program_id,
          review_required: review_required?(plan),
          review_unit_id: review_unit_id(review_unit),
          recipe_ref: run_request.recipe_ref || map_value(first_run_intent(plan), :intent_id),
          trace_id: context.trace_id
        }
        |> Map.merge(run_ref_phase2_metadata(context, run_request, run))
        |> Map.merge(workflow_handoff_metadata(workflow_handoff))
        |> Map.merge(execution_handoff_metadata(execution_handoff))
    })
    |> normalize_result(:invalid_run_ref)
  end

  defp build_typed_result(
         %{
           request_context: %RequestContext{} = context,
           run_request: %RunRequest{} = run_request,
           work_object: work_object,
           plan: plan,
           review_unit: review_unit,
           workflow_handoff: workflow_handoff,
           execution_handoff: execution_handoff
         },
         %RunRef{} = run_ref
       ) do
    state = if review_required?(plan), do: :waiting_review, else: :scheduled

    Result.new(%{
      surface: :work_control,
      state: state,
      payload:
        %{
          run_ref: run_ref,
          work_object_id: work_object.id,
          subject_ref: run_request.subject_ref,
          trace_id: context.trace_id,
          plan_id: plan.id,
          recipe_ref: run_request.recipe_ref,
          params: run_request.params,
          run_request_metadata: run_request_metadata(context, run_request),
          run_intent: first_run_intent(plan),
          review_required: review_required?(plan),
          review_unit_id: review_unit_id(review_unit)
        }
        |> Map.merge(workflow_handoff_metadata(workflow_handoff))
        |> Map.merge(execution_handoff_metadata(execution_handoff))
    })
    |> normalize_result(:invalid_result)
  end

  defp fetch_program_id(attrs, opts),
    do: fetch_string_value(attrs, opts, :program_id, :missing_program_id)

  defp fetch_work_class_id(attrs, opts),
    do: fetch_string_value(attrs, opts, :work_class_id, :missing_work_class_id)

  defp fetch_tenant_id(opts) do
    case Keyword.get(opts, :tenant_id) do
      value when is_binary(value) -> {:ok, value}
      _ -> {:error, :missing_tenant_id}
    end
  end

  defp fetch_tenant_id(%RequestContext{tenant_ref: %{id: tenant_id}}, _opts)
       when is_binary(tenant_id),
       do: {:ok, tenant_id}

  defp fetch_tenant_id(_context, opts), do: fetch_tenant_id(opts)

  defp lower_start_attrs(%RequestContext{} = context, %RunRequest{} = run_request) do
    base = %{
      trace_id: context.trace_id,
      actor_ref: context.actor_ref.id,
      installation_ref: installation_ref(context),
      causation_id: context.causation_id,
      correlation_id: context.request_id || context.causation_id,
      recipe_ref: run_request.recipe_ref,
      reviewer_actor:
        Map.get(run_request.metadata, :reviewer_actor) ||
          Map.get(run_request.metadata, "reviewer_actor")
    }

    base
    |> maybe_put(:idempotency_key, context.idempotency_key)
    |> maybe_put(:runtime_policy_config, map_value(run_request.params, :runtime_policy_config))
    |> Map.merge(run_request.metadata || %{})
  end

  defp run_request_metadata(%RequestContext{} = context, %RunRequest{} = run_request) do
    (run_request.metadata || %{})
    |> maybe_put_new("idempotency_key", context.idempotency_key)
  end

  defp workflow_handoff_started_run(started) do
    %{
      work_object: started.work_object,
      plan: started.plan,
      run: started.run,
      review_unit: started.review_unit
    }
  end

  defp maybe_complete_deterministic_lower(
         tenant_id,
         started_run,
         workflow_handoff,
         execution_handoff,
         start_attrs,
         opts
       ) do
    if Keyword.get(opts, :deterministic_lower_lane?) do
      DeterministicLowerCompletion.complete(
        tenant_id,
        started_run,
        workflow_handoff,
        execution_handoff,
        start_attrs,
        deterministic_lower_opts(opts)
      )
    else
      {:ok, execution_handoff}
    end
  end

  defp deterministic_lower_opts(opts) do
    opts
    |> Keyword.take([:integration_bridge, :invoke_fun])
    |> Keyword.merge(Keyword.get(opts, :deterministic_lower_opts, []))
  end

  defp typed_start_context(
         %RequestContext{} = context,
         %RunRequest{} = run_request,
         started,
         workflow_handoff,
         execution_handoff
       ) do
    %{
      request_context: context,
      run_request: run_request,
      work_object: started.work_object,
      plan: started.plan,
      run: started.run,
      review_unit: started.review_unit,
      workflow_handoff: workflow_handoff,
      execution_handoff: execution_handoff
    }
  end

  defp run_ref_phase2_metadata(
         %RequestContext{} = context,
         %RunRequest{} = run_request,
         run
       ) do
    runtime_profile = Map.get(run, :runtime_profile) || %{}

    %{}
    |> maybe_put(:idempotency_key, context.idempotency_key)
    |> maybe_put(:pack_revision, map_value(run_request.metadata, :pack_revision))
    |> maybe_put(:runtime_profile_ref, map_value(runtime_profile, :runtime_profile_ref))
    |> maybe_put(:runtime_profile_kind, map_value(runtime_profile, :runtime_profile_kind))
    |> maybe_put(:runtime_profile_revision, map_value(runtime_profile, :runtime_profile_revision))
    |> maybe_put(:lower_runtime_kind, map_value(runtime_profile, :lower_runtime_kind))
    |> maybe_put(:requested_action_ids, map_value(runtime_profile, :requested_action_ids))
    |> maybe_put(:requested_capability_ids, map_value(runtime_profile, :requested_capability_ids))
  end

  defp workflow_handoff_metadata(%{
         outbox_row: outbox_row,
         workflow_start_ref: workflow_start_ref,
         evidence_ref: evidence_ref
       }) do
    %{
      workflow_start_ref: workflow_start_ref,
      workflow_start_outbox_id: outbox_row.outbox_id,
      workflow_id: outbox_row.workflow_id,
      workflow_dispatch_state: outbox_row.dispatch_state,
      workflow_start_evidence_ref: evidence_ref
    }
  end

  defp execution_handoff_metadata(%{status: status, execution: execution}) do
    %{
      execution_id: execution.id,
      execution_ref: "execution://#{execution.id}",
      execution_dispatch_state: Atom.to_string(execution.dispatch_state),
      execution_handoff_status: Atom.to_string(status)
    }
  end

  defp installation_ref(%RequestContext{installation_ref: %{id: id}}) when is_binary(id), do: id

  defp installation_ref(%RequestContext{tenant_ref: %{id: tenant_id}}),
    do: "installation://#{tenant_id}/default"

  defp fetch_string_value(attrs, opts, key, error) do
    AdapterSupport.fetch_string(attrs, opts, key, error)
  end

  defp first_run_intent(plan) do
    case plan.derived_run_intents do
      [intent | _] -> intent
      _ -> %{}
    end
  end

  defp review_required?(plan), do: plan.derived_review_intents != []
  defp review_unit_id(nil), do: nil
  defp review_unit_id(%{id: review_unit_id}), do: review_unit_id

  defp map_value(map, key), do: AdapterSupport.map_value(map, key)

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp maybe_put_new(map, _key, nil), do: map
  defp maybe_put_new(map, key, value), do: Map.put_new(map, key, value)

  defp normalize_result({:ok, value}, _fallback), do: {:ok, value}
  defp normalize_result({:error, _reason}, fallback), do: {:error, fallback}
end
