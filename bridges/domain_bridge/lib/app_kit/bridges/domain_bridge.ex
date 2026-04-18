defmodule AppKit.Bridges.DomainBridge do
  @moduledoc """
  App-facing bridge for typed `citadel_domain_surface` calls.
  """

  alias AppKit.Core.{Telemetry, TraceIdentity}
  alias AppKit.ScopeObjects.HostScope
  alias Citadel.DomainSurface.{Command, Error, Query}

  @type compile_opts :: keyword()
  @type compile_error :: Error.t() | atom()

  @spec compile_command(HostScope.t(), atom(), map(), compile_opts()) ::
          {:ok, Command.t()} | {:error, compile_error()}
  def compile_command(%HostScope{} = scope, route_name, params, opts \\ [])
      when is_atom(route_name) and is_map(params) and is_list(opts) do
    with {:ok, domain_module} <- fetch_domain_module(opts),
         {:ok, idempotency_key} <- fetch_idempotency_key(opts),
         {:ok, request_opts} <- request_opts(scope, opts, idempotency_key: idempotency_key),
         {:ok, %Command{} = command} <-
           apply_domain_route(domain_module, route_name, params, request_opts) do
      {:ok, command}
    end
  end

  @spec compile_query(HostScope.t(), atom(), map(), compile_opts()) ::
          {:ok, Query.t()} | {:error, compile_error()}
  def compile_query(%HostScope{} = scope, route_name, params, opts \\ [])
      when is_atom(route_name) and is_map(params) and is_list(opts) do
    with {:ok, domain_module} <- fetch_domain_module(opts),
         {:ok, request_opts} <- request_opts(scope, opts),
         {:ok, %Query{} = query} <-
           apply_domain_route(domain_module, route_name, params, request_opts) do
      {:ok, query}
    end
  end

  defp fetch_domain_module(opts) do
    case Keyword.get(opts, :domain_module) do
      module when is_atom(module) ->
        {:ok, module}

      nil ->
        {:error, :domain_module_required}

      _other ->
        {:error, :invalid_domain_module}
    end
  end

  defp fetch_idempotency_key(opts) do
    case Keyword.get(opts, :idempotency_key) do
      value when is_binary(value) and value != "" -> {:ok, value}
      nil -> {:error, :idempotency_key_required}
      _other -> {:error, :invalid_idempotency_key}
    end
  end

  defp request_opts(%HostScope{} = scope, opts, extra_opts \\ []) do
    context =
      %{
        session_id: scope.session_id,
        tenant_id: scope.tenant_id,
        actor_id: scope.actor_id,
        environment: scope.environment
      }
      |> Enum.reject(fn {_key, value} -> is_nil(value) end)
      |> Map.new()
      |> Map.merge(scope_context_overrides(scope, opts))

    metadata =
      opts
      |> Keyword.get(:metadata, scope.metadata)
      |> normalize_optional_map()
      |> sanitize_control_metadata()

    with {:ok, resolution} <- resolve_trace(scope, opts, context) do
      emit_trace_resolution(scope.tenant_id, :domain_bridge, resolution)

      {:ok,
       [
         context: put_trace_id(context, resolution.trace_id),
         metadata: maybe_put_client_trace_id(metadata, resolution.client_trace_id),
         trace_id: resolution.trace_id
       ] ++ extra_opts}
    else
      {:error, :invalid_trace_id} = error ->
        Telemetry.trace_rejected(%{
          reason: :invalid_format,
          tenant_id: scope.tenant_id,
          source: :request_edge,
          surface: :domain_bridge
        })

        error
    end
  end

  defp scope_context_overrides(%HostScope{metadata: metadata}, opts) do
    scope_context =
      metadata
      |> Map.get(:context, Map.get(metadata, "context"))
      |> normalize_optional_map()

    opts_context =
      opts
      |> Keyword.get(:context, %{})
      |> normalize_optional_map()

    Map.merge(scope_context, opts_context)
    |> drop_trace_controls()
  end

  defp resolve_trace(%HostScope{} = scope, opts, context) do
    TraceIdentity.resolve_edge_trace(
      edge_trace_candidate(opts, context),
      trust: trace_trust(scope, opts, context)
    )
  end

  defp edge_trace_candidate(opts, context) do
    Keyword.get(opts, :trace_id) ||
      Map.get(context, :trace_id) ||
      Map.get(context, "trace_id")
  end

  defp trace_trust(%HostScope{metadata: metadata}, opts, context) do
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

  defp sanitize_control_metadata(metadata) when is_map(metadata) do
    metadata
    |> Map.delete(:context)
    |> Map.delete("context")
    |> Map.delete(:trace_trust)
    |> Map.delete("trace_trust")
    |> Map.delete(:trusted_trace_id?)
    |> Map.delete("trusted_trace_id?")
  end

  defp normalize_optional_map(value) when is_map(value), do: value
  defp normalize_optional_map(value) when is_list(value), do: Map.new(value)
  defp normalize_optional_map(_value), do: %{}

  defp put_trace_id(context, trace_id) do
    context
    |> Map.put(:trace_id, trace_id)
    |> Map.delete("trace_id")
  end

  defp maybe_put_client_trace_id(metadata, nil), do: metadata

  defp maybe_put_client_trace_id(metadata, trace_id),
    do: Map.put(metadata, :client_trace_id, trace_id)

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

  defp apply_domain_route(domain_module, route_name, params, request_opts) do
    if Code.ensure_loaded?(domain_module) and function_exported?(domain_module, route_name, 2) do
      case apply(domain_module, route_name, [params, request_opts]) do
        {:ok, request} ->
          {:ok, request}

        {:error, %Error{} = error} ->
          {:error, error}

        {:error, reason} ->
          {:error, reason}

        other ->
          {:error, {:invalid_domain_route_result, other}}
      end
    else
      {:error, :route_not_found}
    end
  end
end
