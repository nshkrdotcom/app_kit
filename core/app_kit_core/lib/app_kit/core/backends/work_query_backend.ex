defmodule AppKit.Core.Backends.WorkQueryBackend do
  @moduledoc """
  Frozen northbound backend contract for subject and projection work queries.
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

  @callback ingest_subject(RequestContext.t(), map(), keyword()) ::
              {:ok, SubjectRef.t()} | {:error, SurfaceError.t()}

  @callback list_subjects(RequestContext.t(), FilterSet.t() | nil, PageRequest.t(), keyword()) ::
              {:ok, PageResult.t()} | {:error, SurfaceError.t()}

  @callback get_subject(RequestContext.t(), SubjectRef.t(), keyword()) ::
              {:ok, SubjectDetail.t()} | {:error, SurfaceError.t()}

  @callback get_projection(RequestContext.t(), ProjectionRef.t(), keyword()) ::
              {:ok, map()} | {:error, SurfaceError.t()}

  @callback queue_stats(RequestContext.t(), FilterSet.t() | nil, keyword()) ::
              {:ok, map()} | {:error, SurfaceError.t()}
end
