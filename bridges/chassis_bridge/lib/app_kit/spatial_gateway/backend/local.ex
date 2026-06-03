defmodule AppKit.SpatialGateway.Backend.Local do
  @moduledoc "Local backend backed by co-located Chassis registry state."

  @behaviour AppKit.SpatialGateway.Backend

  alias AppKit.SpatialGateway.Backend.Standalone
  alias AppKit.SpatialGateway.Request
  alias Chassis.AppRegistry
  alias Chassis.AppRegistry.Entry

  @impl true
  def handle(%Request.GetActiveProfile{}, opts) do
    with {:ok, registry} <- registry(opts),
         {:ok, entry} <- active_entry(registry, opts) do
      {:ok, entry.active_profile}
    else
      {:error, :registry_unavailable} -> Standalone.handle(%Request.GetActiveProfile{}, opts)
      {:error, :not_found} -> Standalone.handle(%Request.GetActiveProfile{}, opts)
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def handle(%Request.RegisterDeployedApp{app_atom: app_atom, git_sha: git_sha}, opts) do
    with {:ok, registry} <- registry(opts),
         {:ok, entry} <- build_entry(app_atom, git_sha, opts),
         {:ok, registered} <- AppRegistry.register(registry, entry) do
      {:ok, receipt_ref(registered)}
    end
  end

  @impl true
  def handle(%Request.GetHealthStatus{}, opts) do
    case Keyword.get(opts, :health_status) do
      status when status in [:healthy, :degraded, :unhealthy] -> {:ok, status}
      status when status in ["healthy", "degraded", "unhealthy"] -> {:ok, status}
      nil -> {:ok, :healthy}
      other -> {:error, {:invalid_health_status, other}}
    end
  end

  @impl true
  def handle(%Request.TriggerRollback{previous_receipt_ref: receipt_ref}, opts) do
    case Keyword.get(opts, :rollback) do
      fun when is_function(fun, 2) -> fun.(receipt_ref, opts)
      _missing -> {:error, :rollback_unavailable}
    end
  end

  defp registry(opts) do
    case Keyword.get(opts, :registry) || Process.whereis(AppRegistry) do
      nil -> {:error, :registry_unavailable}
      registry -> {:ok, registry}
    end
  end

  defp active_entry(registry, opts) do
    case Keyword.get(opts, :app_ref) do
      app_ref when is_binary(app_ref) ->
        AppRegistry.lookup(registry, app_ref)

      _missing ->
        query =
          opts
          |> Keyword.take([:app_atom, :tenant_ref])
          |> Keyword.put(:status, :active)

        with {:ok, [entry | _]} <- AppRegistry.list(registry, query) do
          {:ok, entry}
        else
          {:ok, []} -> {:error, :not_found}
          error -> error
        end
    end
  end

  defp build_entry(app_atom, git_sha, opts) do
    tenant_ref = Keyword.get(opts, :tenant_ref, "tenant:local")
    installation_ref = Keyword.get(opts, :installation_ref, "installation:local:default")

    Entry.new(%{
      app_ref: "app:#{app_atom}:#{installation_ref}:#{tenant_ref}",
      app_atom: app_atom,
      installation_ref: installation_ref,
      tenant_ref: tenant_ref,
      active_profile: Keyword.get(opts, :profile_ref, "profile:monolith"),
      environment: Keyword.get(opts, :environment, :dev),
      git_sha: git_sha,
      release_version: Keyword.get(opts, :release_version, "v0"),
      node_mesh: Keyword.get(opts, :node_mesh, [node()]),
      status: :active,
      last_deployment_receipt_ref:
        Keyword.get(opts, :deployment_receipt_ref, deployment_receipt_ref(app_atom, git_sha))
    })
  end

  defp deployment_receipt_ref(app_atom, git_sha) do
    digest =
      :crypto.hash(:sha256, "#{app_atom}:#{git_sha}")
      |> Base.encode16(case: :lower)
      |> binary_part(0, 12)

    "receipt:deployment:" <> digest
  end

  defp receipt_ref(%Entry{} = entry) do
    digest =
      :crypto.hash(:sha256, "#{entry.app_ref}:#{entry.git_sha}:#{entry.active_profile}")
      |> Base.encode16(case: :lower)
      |> binary_part(0, 12)

    "receipt:appkit:" <> digest
  end
end
