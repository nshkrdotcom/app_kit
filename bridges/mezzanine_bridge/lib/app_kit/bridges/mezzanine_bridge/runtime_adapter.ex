defmodule AppKit.Bridges.MezzanineBridge.RuntimeAdapter do
  @moduledoc false

  @behaviour AppKit.Core.Backends.RuntimeBackend

  alias AppKit.Bridges.MezzanineBridge.{
    Common,
    Errors,
    RuntimeMapping,
    RuntimeProjectionStore,
    Services,
    WorkContext
  }

  alias AppKit.Core.AgentIntake.{AgentRunRequest, RunOutcomeFuture}
  alias AppKit.Core.RequestContext
  alias AppKit.Core.RuntimeSurface.{LiveEffectReceipt, RuntimeLogPage, RuntimeStatusSnapshot}

  def invoke_runtime_operation(
        %RequestContext{} = context,
        runtime_role_ref,
        operation_role_ref,
        request,
        opts
      )
      when (is_atom(runtime_role_ref) or is_binary(runtime_role_ref)) and
             (is_atom(operation_role_ref) or is_binary(operation_role_ref)) and is_map(request) and
             is_list(opts) do
    with {:ok, agent_request} <- AgentRunRequest.new(request),
         {:ok, spec_attrs} <- RuntimeMapping.agent_run_spec_attrs(context, agent_request),
         {:ok, projection} <-
           Services.runtime_gateway(opts).invoke_runtime_operation(
             context,
             runtime_role_ref,
             operation_role_ref,
             spec_attrs,
             RuntimeMapping.runtime_binding(agent_request, opts),
             opts
           ),
         run_ref when is_binary(run_ref) <- Common.fetch_value(projection, :run_ref),
         :ok <- RuntimeProjectionStore.put(run_ref, projection),
         {:ok, future} <-
           RunOutcomeFuture.new(%{
             run_ref: run_ref,
             workflow_ref: Common.fetch_value(projection, :workflow_ref),
             accepted?: true,
             command_ref: "command://#{agent_request.idempotency_key}",
             correlation_id: agent_request.correlation_id,
             polling_hint: %{checking?: false, poll_interval_ms: 1_000, staleness_ms: 0}
           }) do
      {:ok, future}
    else
      {:error, reason} -> Errors.normalize(reason)
      _other -> Errors.normalize(:runtime_operation_not_configured)
    end
  end

  def invoke_runtime_tool(
        %RequestContext{} = context,
        tool_role_ref,
        operation_role_ref,
        request,
        opts
      )
      when (is_atom(tool_role_ref) or is_binary(tool_role_ref)) and
             (is_atom(operation_role_ref) or is_binary(operation_role_ref)) and is_map(request) and
             is_list(opts) do
    service = Services.runtime_gateway(opts)

    if Services.exports?(service, :invoke_runtime_tool, 5) do
      case service.invoke_runtime_tool(context, tool_role_ref, operation_role_ref, request, opts) do
        {:ok, result} -> {:ok, result}
        {:error, reason} -> Errors.normalize(reason)
      end
    else
      Errors.normalize(:runtime_tool_not_configured)
    end
  end

  @impl true
  def apply_runtime_profile(%RequestContext{} = context, runtime_profile, opts)
      when is_map(runtime_profile) and is_list(opts) do
    with {:ok, tenant_id} <- WorkContext.tenant_id(context),
         {:ok, bridge_result} <-
           apply_runtime_profile_via_service(
             Services.runtime_profile(opts),
             tenant_id,
             runtime_profile
           ),
         {:ok, result} <-
           RuntimeMapping.runtime_profile_apply_result_from_bridge(bridge_result, tenant_id) do
      {:ok, result}
    else
      {:error, reason} -> Errors.normalize(reason)
    end
  end

  @impl true
  def runtime_status(%RequestContext{} = context, request, opts)
      when is_map(request) and is_list(opts) do
    service = Services.operator_query(opts)

    with {:ok, tenant_id} <- WorkContext.tenant_id(context),
         {:ok, program_id} <- RuntimeMapping.runtime_program_id(context, request, opts),
         {:ok, bridge_result} <- system_health_via_service(service, tenant_id, program_id),
         {:ok, snapshot} <-
           RuntimeStatusSnapshot.new(%{
             tenant_ref: tenant_id,
             program_ref: program_id,
             health: bridge_result,
             preflight:
               Common.fetch_value(request, :preflight) ||
                 Common.fetch_value(bridge_result, :preflight) ||
                 %{},
             metadata: Common.fetch_value(bridge_result, :metadata) || %{}
           }) do
      {:ok, snapshot}
    else
      {:error, reason} -> Errors.normalize(reason)
    end
  end

  @impl true
  def runtime_logs(%RequestContext{} = context, request, opts)
      when is_map(request) and is_list(opts) do
    service = Services.operator_query(opts)

    with {:ok, tenant_id} <- WorkContext.tenant_id(context),
         {:ok, subject_id} <- RuntimeMapping.runtime_subject_id(request),
         {:ok, bridge_result} <- timeline_via_service(service, tenant_id, subject_id),
         entries <- Common.fetch_value(bridge_result, :entries) || [],
         {:ok, page} <-
           RuntimeLogPage.new(%{
             entries: entries,
             total_count: Common.fetch_value(bridge_result, :total_count) || length(entries),
             next_cursor: Common.fetch_value(bridge_result, :next_cursor),
             has_more?: Common.fetch_value(bridge_result, :has_more?) || false,
             metadata:
               (Common.fetch_value(bridge_result, :metadata) || %{})
               |> Map.put_new("subject_id", subject_id)
           }) do
      {:ok, page}
    else
      {:error, reason} -> Errors.normalize(reason)
    end
  end

  @impl true
  def record_live_effect(%RequestContext{} = context, attrs, opts \\ [])
      when is_map(attrs) and is_list(opts) do
    with {:ok, tenant_id} <- WorkContext.tenant_id(context),
         attrs <- attrs |> Map.new() |> Map.put_new(:tenant_ref, tenant_id),
         {:ok, receipt} <- LiveEffectReceipt.new(attrs) do
      {:ok, receipt}
    else
      {:error, reason} -> Errors.normalize(reason)
    end
  end

  def collect_evidence(%RequestContext{} = context, evidence_role_ref, request, opts)
      when (is_atom(evidence_role_ref) or is_binary(evidence_role_ref)) and is_map(request) and
             is_list(opts) do
    service = Services.runtime_gateway(opts)

    if Services.exports?(service, :collect_evidence, 4) do
      case service.collect_evidence(context, evidence_role_ref, request, opts) do
        {:ok, result} -> {:ok, result}
        {:error, reason} -> Errors.normalize(reason)
      end
    else
      Errors.normalize(:evidence_collection_not_configured)
    end
  end

  def invoke_resource_effect(%RequestContext{} = context, resource_effect_role_ref, request, opts)
      when (is_atom(resource_effect_role_ref) or is_binary(resource_effect_role_ref)) and
             is_map(request) and is_list(opts) do
    service = Services.runtime_gateway(opts)

    if Services.exports?(service, :invoke_resource_effect, 4) do
      case service.invoke_resource_effect(context, resource_effect_role_ref, request, opts) do
        {:ok, result} -> {:ok, result}
        {:error, reason} -> Errors.normalize(reason)
      end
    else
      Errors.normalize(:resource_effect_not_configured)
    end
  end

  defp apply_runtime_profile_via_service(service, tenant_id, runtime_profile) do
    cond do
      Services.exports?(service, :apply, 2) ->
        service.apply(tenant_id, runtime_profile)

      Services.exports?(service, :ensure, 2) ->
        with {:ok, status} <- service.ensure(tenant_id, runtime_profile) do
          {:ok, %{status: status}}
        end

      true ->
        {:error, :runtime_profile_service_not_configured}
    end
  end

  defp system_health_via_service(service, tenant_id, program_id) do
    if Services.exports?(service, :system_health, 2) do
      service.system_health(tenant_id, program_id)
    else
      {:error, :runtime_status_service_not_configured}
    end
  end

  defp timeline_via_service(service, tenant_id, subject_id) do
    if Services.exports?(service, :timeline, 2) do
      service.timeline(tenant_id, subject_id)
    else
      {:error, :runtime_logs_service_not_configured}
    end
  end
end
