defmodule AppKit.Bridges.MezzanineBridge.WorkAdapter do
  @moduledoc """
  Work-control backend adapter for the Mezzanine bridge.
  """

  @behaviour AppKit.Core.Backends.WorkBackend

  alias AppKit.Bridges.MezzanineBridge.{Errors, Services, WorkContext, WorkMapping}
  alias AppKit.Core.{RequestContext, RunRef, RunRequest, SubjectRef}

  @impl true
  def start_run(%RequestContext{} = context, %RunRequest{} = run_request, opts)
      when is_list(opts) do
    service = Services.work_control(opts)

    if Services.exports?(service, :start_run, 3) do
      case service.start_run(context, run_request, opts) do
        {:ok, result} -> {:ok, result}
        {:error, reason} -> Errors.normalize(reason)
      end
    else
      with {:ok, bridge_result} <- start_run_via_operator_action(context, run_request, opts),
           {:ok, action_result} <- WorkMapping.action_result_from_bridge(bridge_result),
           {:ok, projection} <- fetch_operator_projection(context, run_request.subject_ref, opts),
           {:ok, run_ref} <-
             WorkMapping.run_ref_from_projection(projection, context, run_request, opts),
           {:ok, result} <-
             WorkMapping.run_result_from_projection(projection, run_ref, action_result) do
        {:ok, result}
      else
        {:error, reason} -> Errors.normalize(reason)
      end
    end
  end

  @impl true
  def retry_run(%RequestContext{} = context, %RunRef{} = run_ref, opts) when is_list(opts) do
    service = Services.work_control(opts)

    if Services.exports?(service, :retry_run, 3) do
      case service.retry_run(context, run_ref, opts) do
        {:ok, result} -> {:ok, result}
        {:error, reason} -> Errors.normalize(reason)
      end
    else
      work_control_action(context, run_ref, :replan, "retry", opts)
    end
  end

  @impl true
  def cancel_run(%RequestContext{} = context, %RunRef{} = run_ref, opts) when is_list(opts) do
    service = Services.work_control(opts)

    if Services.exports?(service, :cancel_run, 3) do
      case service.cancel_run(context, run_ref, opts) do
        {:ok, result} -> {:ok, result}
        {:error, reason} -> Errors.normalize(reason)
      end
    else
      work_control_action(context, run_ref, :cancel, "cancel", opts)
    end
  end

  @impl true
  def start_run(domain_call, opts) when is_map(domain_call) and is_list(opts) do
    Services.work_control(opts).start_run(domain_call, opts)
  end

  defp start_run_via_operator_action(
         %RequestContext{} = context,
         %RunRequest{} = run_request,
         opts
       ) do
    with {:ok, tenant_id} <- WorkContext.tenant_id(context) do
      Services.operator_action(opts).apply_action(
        tenant_id,
        run_request.subject_ref.id,
        :replan,
        WorkContext.run_request_action_params(run_request),
        WorkContext.actor_payload(context)
      )
    end
  end

  defp fetch_operator_projection(%RequestContext{} = context, %SubjectRef{} = subject_ref, opts) do
    with {:ok, tenant_id} <- WorkContext.tenant_id(context),
         {:ok, row} <- Services.operator_query(opts).subject_status(tenant_id, subject_ref.id) do
      WorkMapping.operator_projection_from_row(row, context)
    end
  end

  defp work_control_action(
         %RequestContext{} = context,
         %RunRef{} = run_ref,
         action,
         public_kind,
         opts
       ) do
    with {:ok, tenant_id} <- WorkContext.tenant_id(context),
         {:ok, subject_ref} <- WorkContext.subject_ref_from_run_ref(run_ref),
         {:ok, bridge_result} <-
           Services.operator_action(opts).apply_action(
             tenant_id,
             subject_ref.id,
             action,
             %{requested_by: public_kind},
             WorkContext.actor_payload(context)
           ),
         {:ok, action_result} <- WorkMapping.action_result_from_bridge(bridge_result),
         {:ok, normalized_result} <-
           WorkMapping.normalize_public_action_result(action_result, public_kind) do
      {:ok, normalized_result}
    else
      {:error, reason} -> Errors.normalize(reason)
    end
  end
end
