defmodule AppKit.Bridges.MezzanineBridge.HeadlessAdapter do
  @moduledoc false

  @behaviour AppKit.Core.Backends.HeadlessBackend

  alias AppKit.Bridges.MezzanineBridge.{
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
         runtime_sources <-
           Enum.map(
             rows,
             &RuntimeReadbackMapping.state_snapshot_source(query_service, tenant_ref, &1, opts)
           ) do
      RuntimeReadbackMapping.runtime_state_snapshot(context, rows, runtime_sources, request, now)
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
  def runtime_run_detail(%RequestContext{} = _context, run_ref, request, opts) do
    run_id = RuntimeReadbackMapping.readback_ref_id(run_ref)
    RuntimeReadbackMapping.runtime_run_detail(run_id, request, opts, DateTime.utc_now())
  end

  @impl true
  def request_runtime_refresh(%RequestContext{} = _context, request, _opts) do
    RuntimeReadbackMapping.runtime_refresh_result(request)
  end

  @impl true
  def request_runtime_control(%RequestContext{} = _context, request, _opts) do
    RuntimeReadbackMapping.runtime_control_result(request)
  end
end
