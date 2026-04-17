defmodule Mezzanine.AppKitBridge.WorkControlService do
  @moduledoc """
  Backend-oriented run-start service for the transitional AppKit bridge.
  """

  alias AppKit.Core.{RequestContext, Result, RunRef, RunRequest}
  alias Mezzanine.AppKitBridge.AdapterSupport
  alias Mezzanine.WorkControl

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
    with {:ok, tenant_id} <- fetch_tenant_id(context, opts),
         {:ok, started} <-
           WorkControl.start_run_for_subject(
             tenant_id,
             run_request.subject_ref.id,
             lower_start_attrs(context, run_request)
           ),
         {:ok, run_ref} <-
           build_typed_run_ref(
             context,
             run_request,
             started.work_object,
             started.plan,
             started.run,
             started.review_unit,
             opts
           ),
         {:ok, result} <-
           build_typed_result(
             context,
             run_request,
             started.work_object,
             started.plan,
             run_ref,
             started.review_unit
           ) do
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
         %RequestContext{} = context,
         %RunRequest{} = run_request,
         work_object,
         plan,
         run,
         review_unit,
         opts
       ) do
    RunRef.new(%{
      run_id: run.id,
      scope_id: Keyword.get(opts, :scope_id, "program/#{work_object.program_id}"),
      metadata: %{
        tenant_id: context.tenant_ref.id,
        work_object_id: work_object.id,
        plan_id: plan.id,
        program_id: work_object.program_id,
        review_required: review_required?(plan),
        review_unit_id: review_unit_id(review_unit),
        recipe_ref: run_request.recipe_ref || map_value(first_run_intent(plan), :intent_id),
        trace_id: context.trace_id
      }
    })
    |> normalize_result(:invalid_run_ref)
  end

  defp build_typed_result(
         %RequestContext{} = context,
         %RunRequest{} = run_request,
         work_object,
         plan,
         %RunRef{} = run_ref,
         review_unit
       ) do
    state = if review_required?(plan), do: :waiting_review, else: :scheduled

    Result.new(%{
      surface: :work_control,
      state: state,
      payload: %{
        run_ref: run_ref,
        work_object_id: work_object.id,
        subject_ref: run_request.subject_ref,
        trace_id: context.trace_id,
        plan_id: plan.id,
        recipe_ref: run_request.recipe_ref,
        params: run_request.params,
        run_intent: first_run_intent(plan),
        review_required: review_required?(plan),
        review_unit_id: review_unit_id(review_unit)
      }
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
    %{
      trace_id: context.trace_id,
      actor_ref: context.actor_ref.id,
      recipe_ref: run_request.recipe_ref,
      reviewer_actor:
        Map.get(run_request.metadata, :reviewer_actor) ||
          Map.get(run_request.metadata, "reviewer_actor")
    }
  end

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

  defp normalize_result({:ok, value}, _fallback), do: {:ok, value}
  defp normalize_result({:error, _reason}, fallback), do: {:error, fallback}
end
