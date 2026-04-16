defmodule AppKit.WorkSurface do
  @moduledoc """
  Typed app-facing intake, queue, detail, and projection surface.
  """

  alias AppKit.Core.{
    FilterSet,
    PageRequest,
    PageResult,
    ProjectionRef,
    RequestContext,
    SubjectDetail,
    SubjectRef,
    SurfaceError
  }

  @spec ingest_subject(RequestContext.t(), map(), keyword()) ::
          {:ok, SubjectRef.t()} | {:error, SurfaceError.t()}
  def ingest_subject(%RequestContext{} = context, attrs, opts \\ []) when is_map(attrs) do
    backend(opts).ingest_subject(context, attrs, opts)
  end

  @spec list_subjects(RequestContext.t(), PageRequest.t(), keyword()) ::
          {:ok, PageResult.t()} | {:error, SurfaceError.t()}
  def list_subjects(%RequestContext{} = context, %PageRequest{} = page_request, opts \\ []) do
    backend(opts).list_subjects(context, page_request.filters, page_request, opts)
  end

  @spec get_subject(RequestContext.t(), SubjectRef.t(), keyword()) ::
          {:ok, SubjectDetail.t()} | {:error, SurfaceError.t()}
  def get_subject(%RequestContext{} = context, %SubjectRef{} = subject_ref, opts \\ []) do
    backend(opts).get_subject(context, subject_ref, opts)
  end

  @spec get_projection(RequestContext.t(), ProjectionRef.t(), keyword()) ::
          {:ok, map()} | {:error, SurfaceError.t()}
  def get_projection(%RequestContext{} = context, %ProjectionRef{} = projection_ref, opts \\ []) do
    backend(opts).get_projection(context, projection_ref, opts)
  end

  @spec queue_stats(RequestContext.t(), FilterSet.t() | nil, keyword()) ::
          {:ok, map()} | {:error, SurfaceError.t()}
  def queue_stats(%RequestContext{} = context, filters \\ nil, opts \\ [])
      when is_nil(filters) or is_struct(filters, FilterSet) do
    backend(opts).queue_stats(context, filters, opts)
  end

  defp backend(opts) do
    Keyword.get(opts, :work_query_backend) ||
      Application.get_env(:app_kit, :work_query_backend, AppKit.Bridges.MezzanineBridge)
  end
end
