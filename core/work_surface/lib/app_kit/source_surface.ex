defmodule AppKit.SourceSurface do
  @moduledoc """
  Typed app-facing source intake and source current-state surface.
  """

  alias AppKit.BackendConfig
  alias AppKit.Core.{RequestContext, SurfaceError}

  @type source_role_ref :: atom() | String.t()

  @spec sync_source(RequestContext.t(), source_role_ref(), map(), keyword()) ::
          {:ok, map()} | {:error, SurfaceError.t()}
  def sync_source(%RequestContext{} = context, source_role_ref, source_page, opts \\ [])
      when (is_atom(source_role_ref) or is_binary(source_role_ref)) and is_map(source_page) and
             is_list(opts) do
    backend(opts).sync_source(context, source_role_ref, source_page, opts)
  end

  @spec current_states(RequestContext.t(), source_role_ref(), map(), keyword()) ::
          {:ok, map()} | {:error, SurfaceError.t()}
  def current_states(%RequestContext{} = context, source_role_ref, request, opts \\ [])
      when (is_atom(source_role_ref) or is_binary(source_role_ref)) and is_map(request) and
             is_list(opts) do
    backend(opts).current_states(context, source_role_ref, request, opts)
  end

  @spec fetch_candidates(RequestContext.t(), source_role_ref(), map(), keyword()) ::
          {:ok, map()} | {:error, SurfaceError.t()}
  def fetch_candidates(%RequestContext{} = context, source_role_ref, request, opts \\ [])
      when (is_atom(source_role_ref) or is_binary(source_role_ref)) and is_map(request) and
             is_list(opts) do
    backend(opts).fetch_candidates(context, source_role_ref, request, opts)
  end

  @spec publish(RequestContext.t(), source_role_ref(), map(), keyword()) ::
          {:ok, map()} | {:error, SurfaceError.t()}
  def publish(%RequestContext{} = context, publication_role_ref, request, opts \\ [])
      when (is_atom(publication_role_ref) or is_binary(publication_role_ref)) and
             is_map(request) and is_list(opts) do
    backend(opts).publish_source(context, publication_role_ref, request, opts)
  end

  defp backend(opts) do
    BackendConfig.resolve(
      opts,
      :source_backend,
      :source_backend,
      AppKit.Bridges.MezzanineBridge
    )
  end
end
