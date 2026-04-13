defmodule AppKit.DomainSurface do
  @moduledoc """
  Typed app-facing composition above the domain bridge.
  """

  alias AppKit.AppConfig
  alias AppKit.Bridges.DomainBridge
  alias AppKit.Core.Result
  alias AppKit.ScopeObjects.HostScope
  alias Jido.Domain
  alias Jido.Domain.Error

  @type surface_error :: Error.t() | atom()

  @spec submit_command(HostScope.t(), atom(), map(), keyword()) ::
          {:ok, Result.t()} | {:error, surface_error()}
  def submit_command(%HostScope{} = scope, route_name, params, opts \\ []) do
    with {:ok, config} <- AppConfig.normalize(Keyword.get(opts, :config)),
         true <- config.domain_surface?,
         {:ok, command} <- DomainBridge.compile_command(scope, route_name, params, opts),
         {:ok, result} <- dispatch_command(command, route_name, opts) do
      {:ok, result}
    else
      false -> {:error, :domain_surface_disabled}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec ask_query(HostScope.t(), atom(), map(), keyword()) ::
          {:ok, Result.t()} | {:error, surface_error()}
  def ask_query(%HostScope{} = scope, route_name, params, opts \\ []) do
    with {:ok, config} <- AppConfig.normalize(Keyword.get(opts, :config)),
         true <- config.domain_surface?,
         {:ok, query} <- DomainBridge.compile_query(scope, route_name, params, opts),
         {:ok, result} <- dispatch_query(query, route_name, opts) do
      {:ok, result}
    else
      false -> {:error, :domain_surface_disabled}
      {:error, reason} -> {:error, reason}
    end
  end

  defp dispatch_command(command, route_name, opts) do
    case Domain.route(command, domain_route_opts(opts)) do
      {:ok, accepted} ->
        Result.new(%{
          surface: :domain,
          state: :accepted,
          payload: %{route_name: route_name, command: command, accepted: accepted}
        })

      {:error, %Error{} = error} ->
        Result.new(%{
          surface: :domain,
          state: :rejected,
          payload: %{route_name: route_name, command: command, error: error}
        })
    end
  end

  defp dispatch_query(query, route_name, opts) do
    case Domain.route(query, domain_route_opts(opts)) do
      {:ok, response} ->
        Result.new(%{
          surface: :domain,
          state: :accepted,
          payload: %{route_name: route_name, query: query, response: response}
        })

      {:error, %Error{} = error} ->
        Result.new(%{
          surface: :domain,
          state: :rejected,
          payload: %{route_name: route_name, query: query, error: error}
        })
    end
  end

  defp domain_route_opts(opts) do
    opts
    |> Keyword.take([:kernel_runtime, :external_integration])
  end
end
