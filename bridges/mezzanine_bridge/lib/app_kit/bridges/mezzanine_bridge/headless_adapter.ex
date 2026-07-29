defmodule AppKit.Bridges.MezzanineBridge.HeadlessAdapter do
  @moduledoc false

  @behaviour AppKit.Core.Backends.HeadlessBackend

  alias AppKit.Bridges.MezzanineBridge.{
    AgentIntakeMapping,
    Common,
    Errors,
    RuntimeReadbackMapping,
    Services,
    WorkContext,
    WorkMapping
  }

  alias AppKit.Core.RequestContext

  @impl true
  def state_snapshot(%RequestContext{} = context, request, opts) when is_list(opts) do
    now = DateTime.utc_now()
    query_service = Services.work_query(opts)

    with {:ok, tenant_ref} <- WorkContext.tenant_id(context),
         {:ok, program_id} <- WorkContext.program_id(context, opts),
         {:ok, rows} <- query_service.list_subjects(tenant_ref, program_id, %{}),
         projections <- canonical_agent_projections(tenant_ref, opts),
         runtime_sources <-
           state_snapshot_sources(query_service, tenant_ref, rows, projections, opts) do
      RuntimeReadbackMapping.runtime_state_snapshot(
        context,
        runtime_sources,
        runtime_sources,
        request,
        now
      )
    else
      {:error, reason} -> Errors.normalize(reason)
    end
  end

  @impl true
  def runtime_subject_detail(%RequestContext{} = context, subject_ref, _request, opts)
      when is_list(opts) do
    subject_id = RuntimeReadbackMapping.readback_ref_id(subject_ref)
    now = DateTime.utc_now()

    with {:ok, tenant_ref} <- WorkContext.tenant_id(context),
         {:ok, projection} <-
           WorkMapping.get_subject_projection(
             Services.work_query(opts),
             tenant_ref,
             subject_id,
             Keyword.put(opts, :runtime_projection?, true)
           ) do
      RuntimeReadbackMapping.runtime_subject_detail(subject_id, projection, now)
    else
      {:error, reason} -> Errors.normalize(reason)
    end
  end

  @impl true
  def runtime_run_detail(%RequestContext{} = context, run_ref, _request, opts) do
    run_id = RuntimeReadbackMapping.readback_ref_id(run_ref)
    service = Services.agent_intake(opts)

    with {:ok, projection} <- service.fetch_projection(run_id, opts),
         :ok <- AgentIntakeMapping.authorize_projection(context, run_id, projection),
         {:ok, turns} <- service.list_turns(run_id, opts),
         {:ok, events} <- service.list_events(run_id, nil, Keyword.put(opts, :limit, 500)),
         {:ok, provider_events} <- provider_events(service, projection, opts),
         {:ok, detail} <-
           AgentIntakeMapping.run_detail(projection, turns, events, provider_events) do
      {:ok, detail}
    else
      {:error, reason} -> Errors.normalize(reason)
    end
  end

  @impl true
  def request_runtime_refresh(%RequestContext{} = context, request, opts) do
    service = Services.runtime_refresh(opts)

    if Services.exports?(service, :request_runtime_refresh, 3) do
      with {:ok, owner_result} <- service.request_runtime_refresh(context, request, opts),
           {:ok, result} <-
             RuntimeReadbackMapping.durable_runtime_refresh_result(request, owner_result) do
        {:ok, result}
      else
        {:error, reason} -> Errors.normalize(reason)
      end
    else
      Errors.normalize(:runtime_refresh_owner_not_configured)
    end
  end

  @impl true
  def request_runtime_control(%RequestContext{} = context, request, opts) do
    case Services.work_control(opts).control_run(context, request, opts) do
      {:ok, result} -> {:ok, result}
      {:error, reason} -> Errors.normalize(reason)
    end
  end

  defp provider_events(service, projection, opts) do
    case AgentIntakeMapping.model_turn_ref(projection) do
      nil ->
        {:ok, []}

      turn_ref ->
        service.list_provider_events(turn_ref, 0, Keyword.put(opts, :limit, 500))
    end
  end

  defp canonical_agent_projections(tenant_ref, opts) do
    service = Services.agent_intake(opts)

    if Services.exports?(service, :list_projections, 2) do
      case service.list_projections(tenant_ref, Keyword.put_new(opts, :limit, 500)) do
        {:ok, projections} when is_list(projections) ->
          Enum.filter(
            projections,
            &same_tenant?(
              Common.fetch_value(&1, :tenant_ref),
              tenant_ref
            )
          )

        _unavailable ->
          []
      end
    else
      []
    end
  end

  defp state_snapshot_sources(query_service, tenant_ref, rows, projections, opts) do
    projections_by_work_object =
      Map.new(projections, fn projection ->
        {
          RuntimeReadbackMapping.readback_ref_id(Common.fetch_value(projection, :work_object_id)),
          projection
        }
      end)

    {sources, matched_work_objects} =
      Enum.map_reduce(rows, MapSet.new(), fn row, matched ->
        work_object_id =
          row
          |> Common.fetch_value(:subject_id)
          |> RuntimeReadbackMapping.readback_ref_id()

        projection = Map.get(projections_by_work_object, work_object_id)

        source =
          query_service
          |> RuntimeReadbackMapping.state_snapshot_source(tenant_ref, row, opts)
          |> RuntimeReadbackMapping.with_agent_projection(projection)

        matched =
          if projection, do: MapSet.put(matched, work_object_id), else: matched

        {source, matched}
      end)

    missing_sources =
      projections
      |> Enum.reject(fn projection ->
        projection
        |> Common.fetch_value(:work_object_id)
        |> RuntimeReadbackMapping.readback_ref_id()
        |> then(&MapSet.member?(matched_work_objects, &1))
      end)
      |> Enum.map(&RuntimeReadbackMapping.with_agent_projection(%{}, &1))

    sources ++ missing_sources
  end

  defp same_tenant?(projection_tenant, tenant_ref) do
    projection_tenant = RuntimeReadbackMapping.readback_ref_id(projection_tenant)
    projection_tenant in [tenant_ref, "tenant://#{tenant_ref}"]
  end
end
