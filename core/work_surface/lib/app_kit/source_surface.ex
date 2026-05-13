defmodule AppKit.SourceSurface do
  @moduledoc """
  Typed app-facing source intake and source current-state surface.
  """

  alias AppKit.BackendConfig
  alias AppKit.Core.{RequestContext, SurfaceError}

  @spec sync_linear_issues(RequestContext.t(), map(), keyword()) ::
          {:ok, map()} | {:error, SurfaceError.t()}
  def sync_linear_issues(%RequestContext{} = context, source_page, opts \\ [])
      when is_map(source_page) and is_list(opts) do
    backend(opts).sync_linear_issues(context, source_page, opts)
  end

  @spec current_linear_issue_states(RequestContext.t(), [String.t()], map(), keyword()) ::
          {:ok, map()} | {:error, SurfaceError.t()}
  def current_linear_issue_states(
        %RequestContext{} = context,
        issue_ids,
        source_binding,
        opts \\ []
      )
      when is_list(issue_ids) and is_map(source_binding) and is_list(opts) do
    backend(opts).current_linear_issue_states(context, issue_ids, source_binding, opts)
  end

  @spec fetch_linear_candidates(RequestContext.t(), map(), keyword()) ::
          {:ok, map()} | {:error, SurfaceError.t()}
  def fetch_linear_candidates(%RequestContext{} = context, source_binding, opts \\ [])
      when is_map(source_binding) and is_list(opts) do
    backend(opts).fetch_linear_candidates(context, source_binding, opts)
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
