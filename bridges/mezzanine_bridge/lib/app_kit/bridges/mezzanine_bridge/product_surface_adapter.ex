defmodule AppKit.Bridges.MezzanineBridge.ProductSurfaceAdapter do
  @moduledoc false

  @behaviour AppKit.Core.Backends.ProductSurfaceBackend

  alias AppKit.Bridges.MezzanineBridge.Errors
  alias AppKit.Bridges.MezzanineBridge.Services
  alias AppKit.Core.ProductSurface.CapabilityProjection
  alias AppKit.Core.ProductSurface.RunProjection
  alias AppKit.Core.RequestContext

  @impl true
  def run_projection(%RequestContext{} = context, run_ref, opts)
      when is_binary(run_ref) and run_ref != "" and is_list(opts) do
    with service when not is_nil(service) <- Services.product_projection(opts),
         true <- Services.exports?(service, :run_projection, 3),
         {:ok, raw_projection} <- service.run_projection(context, run_ref, opts),
         {:ok, projection} <- revalidate_run_projection(raw_projection),
         :ok <- validate_run_identity(projection, run_ref),
         :ok <- validate_cursor_tenants(projection, context.tenant_ref.id) do
      {:ok, projection}
    else
      nil ->
        Errors.normalize(:product_projection_owner_not_configured)

      false ->
        Errors.normalize(:product_projection_owner_not_configured)

      {:error, reason} ->
        Errors.normalize(reason)

      _response ->
        Errors.normalize(:invalid_product_projection_owner_response)
    end
  end

  def run_projection(_context, _run_ref, _opts) do
    Errors.normalize(:invalid_product_run_projection_request)
  end

  @impl true
  def capability_projections(%RequestContext{} = context, request, opts)
      when is_map(request) and is_list(opts) do
    with service when not is_nil(service) <- Services.product_projection(opts),
         true <- Services.exports?(service, :capability_projections, 3),
         {:ok, raw_projections} when is_list(raw_projections) <-
           service.capability_projections(context, request, opts),
         {:ok, projections} <- revalidate_capability_projections(raw_projections) do
      {:ok, projections}
    else
      nil ->
        Errors.normalize(:product_projection_owner_not_configured)

      false ->
        Errors.normalize(:product_projection_owner_not_configured)

      {:error, reason} ->
        Errors.normalize(reason)

      _response ->
        Errors.normalize(:invalid_product_projection_owner_response)
    end
  end

  def capability_projections(_context, _request, _opts) do
    Errors.normalize(:invalid_product_capability_projection_request)
  end

  defp revalidate_run_projection(projection) when is_map(projection) do
    with {:ok, validated} <- RunProjection.new(projection) do
      validated
      |> RunProjection.dump()
      |> RunProjection.new()
    end
  end

  defp revalidate_run_projection(_projection), do: {:error, :invalid_product_run_projection}

  defp revalidate_capability_projections(projections) do
    Enum.reduce_while(projections, {:ok, []}, fn projection, {:ok, acc} ->
      case revalidate_capability_projection(projection) do
        {:ok, validated} -> {:cont, {:ok, [validated | acc]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> then(fn
      {:ok, validated} -> {:ok, Enum.reverse(validated)}
      error -> error
    end)
  end

  defp revalidate_capability_projection(projection) when is_map(projection) do
    with {:ok, validated} <- CapabilityProjection.new(projection) do
      validated
      |> CapabilityProjection.dump()
      |> CapabilityProjection.new()
    end
  end

  defp revalidate_capability_projection(_projection),
    do: {:error, :invalid_product_capability_projection}

  defp validate_run_identity(projection, requested_run_ref) do
    run_refs =
      [
        projection.run_ref,
        projection.cursor.ledger_ref,
        projection.control.run_ref,
        get_in(projection.context || %{}, [:run_ref])
      ] ++
        Enum.flat_map(projection.turns, fn turn ->
          [
            turn.run_ref,
            get_in(turn.context || %{}, [:run_ref]),
            turn.stream_cursor && turn.stream_cursor.ledger_ref
          ]
        end) ++
        Enum.map(projection.events, & &1.ledger_ref) ++
        Enum.map(projection.operations, & &1.run_ref)

    if Enum.all?(run_refs, &(is_nil(&1) or &1 == requested_run_ref)) do
      :ok
    else
      {:error, :product_run_identity_mismatch}
    end
  end

  defp validate_cursor_tenants(projection, tenant_ref) do
    tenant_refs =
      [projection.cursor.tenant_ref] ++
        Enum.flat_map(projection.turns, fn turn ->
          case turn.stream_cursor do
            nil -> []
            cursor -> [cursor.tenant_ref]
          end
        end)

    if Enum.all?(tenant_refs, &(&1 == tenant_ref)) do
      :ok
    else
      {:error, :product_cursor_tenant_mismatch}
    end
  end
end
