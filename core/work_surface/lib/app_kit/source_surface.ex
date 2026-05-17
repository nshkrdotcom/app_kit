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

  @spec publish_linear_source(RequestContext.t(), map(), keyword()) ::
          {:ok, map()} | {:error, SurfaceError.t()}
  def publish_linear_source(%RequestContext{} = context, attrs, opts \\ [])
      when is_map(attrs) and is_list(opts) do
    backend(opts).publish_linear_source(context, attrs, opts)
  end

  @spec execute_linear_graphql_tool(RequestContext.t(), map(), keyword()) ::
          {:ok, map()} | {:error, SurfaceError.t()}
  def execute_linear_graphql_tool(%RequestContext{} = context, attrs, opts \\ [])
      when is_map(attrs) and is_list(opts) do
    backend(opts).execute_linear_graphql_tool(context, attrs, opts)
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
