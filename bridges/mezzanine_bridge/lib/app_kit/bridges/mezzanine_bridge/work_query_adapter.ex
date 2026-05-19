defmodule AppKit.Bridges.MezzanineBridge.WorkQueryAdapter do
  @moduledoc """
  Work-query backend adapter for the Mezzanine bridge.
  """

  @behaviour AppKit.Core.Backends.WorkQueryBackend

  alias AppKit.Bridges.MezzanineBridge.{Common, Errors, Services, WorkContext, WorkMapping}
  alias AppKit.Core.{FilterSet, PageRequest, ProjectionRef, RequestContext, SubjectRef}

  @impl true
  def ingest_subject(%RequestContext{} = context, attrs, opts)
      when is_map(attrs) and is_list(opts) do
    with {:ok, tenant_id} <- WorkContext.tenant_id(context),
         {:ok, program_id} <- WorkContext.program_id(context, opts),
         {:ok, work_class_id} <- WorkContext.work_class_id(context, attrs, opts),
         merged_attrs <-
           attrs
           |> Map.new()
           |> Map.put_new(:tenant_id, tenant_id)
           |> Map.put_new(:program_id, program_id)
           |> Map.put_new(:work_class_id, work_class_id),
         {:ok, subject} <- Services.work_query(opts).ingest_subject(merged_attrs, opts),
         {:ok, subject_ref} <- WorkMapping.subject_ref_from_summary(subject, context) do
      {:ok, subject_ref}
    else
      {:error, reason} -> Errors.normalize(reason)
    end
  end

  @impl true
  def list_subjects(%RequestContext{} = context, filters, %PageRequest{} = page_request, opts)
      when (is_nil(filters) or is_struct(filters, FilterSet)) and is_list(opts) do
    with {:ok, tenant_id} <- WorkContext.tenant_id(context),
         {:ok, program_id} <- WorkContext.program_id(context, opts),
         {:ok, rows} <-
           Services.work_query(opts).list_subjects(
             tenant_id,
             program_id,
             WorkContext.work_filters(filters || page_request.filters)
           ),
         {:ok, entries} <-
           Common.map_each(rows, &WorkMapping.subject_summary_from_row(&1, context)),
         {:ok, page_result} <- Common.page_result(entries, page_request) do
      {:ok, page_result}
    else
      {:error, reason} -> Errors.normalize(reason)
    end
  end

  @impl true
  def get_subject(%RequestContext{} = context, %SubjectRef{} = subject_ref, opts)
      when is_list(opts) do
    with :ok <- WorkContext.ensure_subject_not_archived(context, subject_ref),
         {:ok, tenant_id} <- WorkContext.tenant_id(context),
         {:ok, row} <- Services.work_query(opts).get_subject_detail(tenant_id, subject_ref.id),
         {:ok, detail} <- WorkMapping.subject_detail_from_row(row, context) do
      {:ok, detail}
    else
      {:error, :archived, manifest_ref} -> Errors.normalize({:archived, manifest_ref})
      {:error, reason} -> Errors.normalize(reason)
    end
  end

  @impl true
  def get_projection(%RequestContext{} = context, %ProjectionRef{} = projection_ref, opts)
      when is_list(opts) do
    with {:ok, tenant_id} <- WorkContext.tenant_id(context),
         {:ok, subject_id} <- WorkContext.subject_id_from_projection(projection_ref),
         {:ok, projection} <-
           WorkMapping.get_subject_projection(
             Services.work_query(opts),
             tenant_id,
             subject_id,
             opts
           ) do
      {:ok, projection}
    else
      {:error, :archived, manifest_ref} -> Errors.normalize({:archived, manifest_ref})
      {:error, reason} -> Errors.normalize(reason)
    end
  end

  @impl true
  def get_runtime_projection(%RequestContext{} = context, %SubjectRef{} = subject_ref, opts)
      when is_list(opts) do
    runtime_opts = Keyword.put(opts, :runtime_projection?, true)

    with :ok <- WorkContext.ensure_subject_not_archived(context, subject_ref),
         {:ok, tenant_id} <- WorkContext.tenant_id(context),
         {:ok, projection} <-
           WorkMapping.get_subject_projection(
             Services.work_query(opts),
             tenant_id,
             subject_ref.id,
             runtime_opts
           ),
         :ok <- WorkMapping.ensure_runtime_projection_row(projection),
         {:ok, runtime_projection} <-
           WorkMapping.subject_runtime_projection_from_map(projection, context, subject_ref) do
      {:ok, runtime_projection}
    else
      {:error, :archived, manifest_ref} -> Errors.normalize({:archived, manifest_ref})
      {:error, reason} -> Errors.normalize(reason)
    end
  end

  @impl true
  def queue_stats(%RequestContext{} = context, filters, opts)
      when (is_nil(filters) or is_struct(filters, FilterSet)) and is_list(opts) do
    with {:ok, tenant_id} <- WorkContext.tenant_id(context),
         {:ok, program_id} <- WorkContext.program_id(context, opts),
         {:ok, stats} <- Services.work_query(opts).queue_stats(tenant_id, program_id) do
      {:ok, Map.merge(stats, %{filters: WorkContext.work_filters(filters)})}
    else
      {:error, reason} -> Errors.normalize(reason)
    end
  end
end
