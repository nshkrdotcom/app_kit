defmodule AppKit.Bridges.OuterBrainBridge do
  @moduledoc """
  App-facing bridge for semantic-turn submission above the outer brain.
  """

  alias AppKit.Core.{Telemetry, TraceIdentity}
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
         {:ok, runtime_module, runtime_opts} <- normalize_runtime_ref(runtime_ref),
         {:ok, resolution} <- resolve_trace(scope, opts) do
      emit_trace_resolution(scope.tenant_id, :outer_brain_bridge, resolution)

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
            trace_id: resolution.trace_id,
            domain_module: domain_module,
            route_sources: route_sources,
            route: Keyword.get(opts, :route),
            context: context(scope, opts, resolution.trace_id),
            metadata: metadata(scope, opts, resolution.client_trace_id),
            kernel_runtime: Keyword.get(opts, :kernel_runtime),
            external_integration: Keyword.get(opts, :external_integration)
          ]
      )
    else
      {:error, :invalid_trace_id} = error ->
        Telemetry.trace_rejected(%{
          reason: :invalid_format,
          tenant_id: scope.tenant_id,
          source: :request_edge,
          surface: :outer_brain_bridge
        })

        error

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

  defp context(%HostScope{} = scope, opts, trace_id) do
    scope.metadata
    |> Map.get(:context, %{})
    |> normalize_optional_map()
    |> Map.merge(%{
      session_id: scope.session_id,
      tenant_id: scope.tenant_id,
      actor_id: scope.actor_id,
      environment: scope.environment,
      trace_id: trace_id
    })
    |> Map.merge(normalize_optional_map(Keyword.get(opts, :context, %{})))
    |> drop_trace_controls()
    |> Map.put(:trace_id, trace_id)
    |> Map.delete("trace_id")
  end

  defp metadata(%HostScope{} = scope, opts, client_trace_id) do
    scope.metadata
    |> Map.delete(:context)
    |> Map.merge(normalize_optional_map(Keyword.get(opts, :metadata, %{})))
    |> sanitize_control_metadata()
    |> maybe_put_client_trace_id(client_trace_id)
  end

  defp workspace_root(%HostScope{} = scope, opts) do
    Keyword.get(opts, :workspace_root, Map.get(scope.metadata, :workspace_root))
  end

  defp resolve_trace(%HostScope{} = scope, opts) do
    TraceIdentity.resolve_edge_trace(
      edge_trace_candidate(opts),
      trust: trace_trust(scope, opts)
    )
  end

  defp edge_trace_candidate(opts) do
    context = normalize_optional_map(Keyword.get(opts, :context, %{}))

    Keyword.get(opts, :trace_id) ||
      Map.get(context, :trace_id) ||
      Map.get(context, "trace_id")
  end

  defp trace_trust(%HostScope{metadata: metadata}, opts) do
    context = normalize_optional_map(Keyword.get(opts, :context, %{}))

    [
      Keyword.get(opts, :trace_trust),
      Map.get(context, :trace_trust),
      Map.get(context, "trace_trust"),
      Map.get(metadata, :trace_trust),
      Map.get(metadata, "trace_trust"),
      Keyword.get(opts, :trusted_trace_id?),
      Map.get(context, :trusted_trace_id?),
      Map.get(context, "trusted_trace_id?"),
      Map.get(metadata, :trusted_trace_id?),
      Map.get(metadata, "trusted_trace_id?")
    ]
    |> Enum.find(fn value -> not is_nil(value) end)
  end

  defp drop_trace_controls(context) do
    context
    |> Map.delete(:trace_trust)
    |> Map.delete("trace_trust")
    |> Map.delete(:trusted_trace_id?)
    |> Map.delete("trusted_trace_id?")
  end

  defp sanitize_control_metadata(metadata) do
    metadata
    |> Map.delete(:trace_trust)
    |> Map.delete("trace_trust")
    |> Map.delete(:trusted_trace_id?)
    |> Map.delete("trusted_trace_id?")
  end

  defp maybe_put_client_trace_id(metadata, nil), do: metadata

  defp maybe_put_client_trace_id(metadata, trace_id),
    do: Map.put(metadata, :client_trace_id, trace_id)

  defp normalize_optional_map(value) when is_map(value), do: value
  defp normalize_optional_map(value) when is_list(value), do: Map.new(value)
  defp normalize_optional_map(_value), do: %{}

  defp emit_trace_resolution(tenant_id, surface, %{disposition: :minted, trace_id: trace_id}) do
    Telemetry.trace_minted(%{
      trace_id: trace_id,
      tenant_id: tenant_id,
      source: :request_edge,
      surface: surface
    })
  end

  defp emit_trace_resolution(tenant_id, surface, %{disposition: :replaced, trace_id: trace_id}) do
    Telemetry.trace_replaced(%{
      trace_id: trace_id,
      tenant_id: tenant_id,
      reason: :untrusted_caller,
      source: :request_edge,
      surface: surface
    })
  end

  defp emit_trace_resolution(_tenant_id, _surface, _resolution), do: :ok
end
