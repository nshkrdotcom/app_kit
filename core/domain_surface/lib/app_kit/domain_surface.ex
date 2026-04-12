defmodule AppKit.DomainSurface do
  @moduledoc """
  Typed app-facing composition above the domain bridge.
  """

  alias AppKit.AppConfig
  alias AppKit.Bridges.DomainBridge
  alias AppKit.Core.Result
  alias AppKit.ScopeObjects.HostScope
  alias AppKit.WorkControl

  @spec submit_command(HostScope.t(), atom(), map(), keyword()) ::
          {:ok, Result.t()} | {:error, atom()}
  def submit_command(%HostScope{} = scope, route_name, params, opts \\ []) do
    with {:ok, config} <- AppConfig.normalize(Keyword.get(opts, :config)),
         true <- config.domain_surface?,
         {:ok, command} <- DomainBridge.compile_command(scope, route_name, params),
         {:ok, result} <-
           WorkControl.start_run(
             command,
             review_required: Keyword.get(opts, :review_required, false),
             target: Keyword.get(opts, :target, :default)
           ) do
      {:ok, result}
    else
      false -> {:error, :domain_surface_disabled}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec ask_query(HostScope.t(), atom(), map(), keyword()) :: {:ok, Result.t()} | {:error, atom()}
  def ask_query(%HostScope{} = scope, route_name, params, opts \\ []) do
    with {:ok, config} <- AppConfig.normalize(Keyword.get(opts, :config)),
         true <- config.domain_surface?,
         {:ok, query} <- DomainBridge.compile_query(scope, route_name, params),
         {:ok, result} <-
           Result.new(%{surface: :domain, state: :accepted, payload: %{query: query}}) do
      {:ok, result}
    else
      false -> {:error, :domain_surface_disabled}
      {:error, reason} -> {:error, reason}
    end
  end
end
