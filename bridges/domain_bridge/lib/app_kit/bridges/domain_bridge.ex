defmodule AppKit.Bridges.DomainBridge do
  @moduledoc """
  App-facing bridge for typed `jido_domain` calls.
  """

  alias AppKit.ScopeObjects.HostScope
  alias Jido.Domain.{Command, Error, Query}

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

    {:ok,
     [
       context: context,
       metadata: Keyword.get(opts, :metadata, scope.metadata)
     ] ++ extra_opts}
  end

  defp scope_context_overrides(%HostScope{metadata: metadata}, opts) do
    scope_context =
      case Map.get(metadata, :context, Map.get(metadata, "context")) do
        %{} = value -> value
        _other -> %{}
      end

    opts_context =
      case Keyword.get(opts, :context, %{}) do
        %{} = value -> value
        _other -> %{}
      end

    Map.merge(scope_context, opts_context)
  end

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
