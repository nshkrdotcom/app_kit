defmodule AppKit.Bridges.OuterBrainBridge do
  @moduledoc """
  App-facing bridge for semantic-turn submission above the outer brain.
  """

  alias AppKit.ScopeObjects.HostScope
  alias OuterBrain.Bridges.DomainSubmission

  @spec submit_turn(HostScope.t(), String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def submit_turn(%HostScope{} = scope, text, opts \\ []) when is_binary(text) do
    trimmed = String.trim(text)

    with :ok <- validate_turn(trimmed),
         {:ok, idempotency_key} <- required_string(opts, :idempotency_key),
         {:ok, domain_module} <- required_atom(opts, :domain_module),
         {:ok, route_sources} <- required_route_sources(opts),
         runtime_ref <- Keyword.get(opts, :semantic_runtime, {DomainSubmission, []}),
         {:ok, runtime_module, runtime_opts} <- normalize_runtime_ref(runtime_ref) do
      runtime_module.submit_turn(
        trimmed,
        runtime_opts ++
          [
            session_id: scope.session_id,
            tenant_id: scope.tenant_id,
            actor_id: scope.actor_id,
            environment: scope.environment,
            scope_id: scope.scope_id,
            workspace_id: Keyword.get(opts, :workspace_id, scope.scope_id),
            workspace_root: workspace_root(scope, opts),
            idempotency_key: idempotency_key,
            trace_id: Keyword.get(opts, :trace_id, "trace/#{idempotency_key}"),
            domain_module: domain_module,
            route_sources: route_sources,
            route: Keyword.get(opts, :route),
            context: context(scope, opts),
            metadata: metadata(scope, opts),
            kernel_runtime: Keyword.get(opts, :kernel_runtime),
            external_integration: Keyword.get(opts, :external_integration)
          ]
      )
    else
      {:error, _reason} = error ->
        error
    end
  end

  defp validate_turn(""), do: {:error, :blank_turn}
  defp validate_turn(_trimmed), do: :ok

  defp required_string(opts, key) do
    case Keyword.get(opts, key) do
      value when is_binary(value) and value != "" -> {:ok, value}
      _other -> {:error, {:missing_option, key}}
    end
  end

  defp required_atom(opts, key) do
    case Keyword.get(opts, key) do
      value when is_atom(value) -> {:ok, value}
      _other -> {:error, {:missing_option, key}}
    end
  end

  defp required_route_sources(opts) do
    case Keyword.get(opts, :route_sources) do
      value when is_list(value) and value != [] -> {:ok, value}
      _other -> {:error, {:missing_option, :route_sources}}
    end
  end

  defp normalize_runtime_ref({module, runtime_opts})
       when is_atom(module) and is_list(runtime_opts),
       do: {:ok, module, runtime_opts}

  defp normalize_runtime_ref(module) when is_atom(module), do: {:ok, module, []}

  defp normalize_runtime_ref(other),
    do: {:error, {:invalid_semantic_runtime, other}}

  defp context(%HostScope{} = scope, opts) do
    scope.metadata
    |> Map.get(:context, %{})
    |> Map.merge(%{
      session_id: scope.session_id,
      tenant_id: scope.tenant_id,
      actor_id: scope.actor_id,
      environment: scope.environment
    })
    |> Map.merge(Keyword.get(opts, :context, %{}))
  end

  defp metadata(%HostScope{} = scope, opts) do
    scope.metadata
    |> Map.delete(:context)
    |> Map.merge(Keyword.get(opts, :metadata, %{}))
  end

  defp workspace_root(%HostScope{} = scope, opts) do
    Keyword.get(opts, :workspace_root, Map.get(scope.metadata, :workspace_root))
  end
end
