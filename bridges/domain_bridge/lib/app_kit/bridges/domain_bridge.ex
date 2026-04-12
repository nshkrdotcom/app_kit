defmodule AppKit.Bridges.DomainBridge do
  @moduledoc """
  App-facing bridge for typed domain calls.
  """

  alias AppKit.ScopeObjects.HostScope

  @spec compile_command(HostScope.t(), atom(), map()) :: {:ok, map()} | {:error, atom()}
  def compile_command(%HostScope{} = scope, route_name, params)
      when is_atom(route_name) and is_map(params) do
    {:ok, %{kind: :command, scope_id: scope.scope_id, route_name: route_name, params: params}}
  end

  @spec compile_query(HostScope.t(), atom(), map()) :: {:ok, map()} | {:error, atom()}
  def compile_query(%HostScope{} = scope, route_name, params)
      when is_atom(route_name) and is_map(params) do
    {:ok, %{kind: :query, scope_id: scope.scope_id, route_name: route_name, params: params}}
  end
end
