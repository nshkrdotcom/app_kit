defmodule AppKit.SpatialGateway.Backend.Boundary do
  @moduledoc "Boundary backend for Chassis Ring 0 readback dispatch."

  @behaviour AppKit.SpatialGateway.Backend

  alias AppKit.SpatialGateway.Request
  alias Chassis.Boundary
  alias Chassis.Boundary.ReadDeploymentProjection

  @protocol_ref "boundary:appkit.chassis.read_deployment_projection:v1"

  @impl true
  def handle(%Request.GetActiveProfile{}, opts) do
    dispatcher = Keyword.get(opts, :boundary_dispatcher, Boundary)
    envelope = read_envelope(opts)

    case dispatcher.dispatch(envelope, dispatch_opts(opts)) do
      {:ok,
       %Boundary.Envelope{payload: %ReadDeploymentProjection.Response{projection: projection}}} ->
        {:ok, projection.active_profile}

      {:ok, %Boundary.Envelope{payload: %{projection: %{active_profile: profile}}}} ->
        {:ok, profile}

      {:ok, %Boundary.Envelope{payload: %{active_profile: profile}}} ->
        {:ok, profile}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl true
  def handle(%Request.GetHealthStatus{}, _opts), do: {:error, :boundary_operation_not_supported}

  @impl true
  def handle(%Request.RegisterDeployedApp{}, _opts),
    do: {:error, :boundary_operation_not_supported}

  @impl true
  def handle(%Request.TriggerRollback{}, _opts), do: {:error, :boundary_operation_not_supported}

  defp read_envelope(opts) do
    Boundary.Envelope.new!(%{
      protocol_ref: @protocol_ref,
      envelope_ref: Keyword.get(opts, :envelope_ref, "env:appkit.chassis.read:#{unique()}"),
      tenant_ref: Keyword.get(opts, :tenant_ref),
      installation_ref: Keyword.get(opts, :installation_ref),
      trace_id: Keyword.get(opts, :trace_id, "trace:appkit.chassis.read:#{unique()}"),
      payload: %ReadDeploymentProjection.Request{
        tenant_ref: Keyword.get(opts, :tenant_ref),
        installation_ref: Keyword.get(opts, :installation_ref),
        deployment_ref: Keyword.get(opts, :deployment_ref)
      }
    })
  end

  defp dispatch_opts(opts) do
    opts
    |> Keyword.take([:target_node, :test_pid])
    |> Keyword.put_new(:target_node, Keyword.get(opts, :chassis_node, :local))
  end

  defp unique, do: System.unique_integer([:positive]) |> Integer.to_string()
end
