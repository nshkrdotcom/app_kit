defmodule AppKit.ProductSurface do
  @moduledoc """
  Executable AppKit boundary for coherent product snapshots and capability
  truth.

  The boundary revalidates every backend result with the public product DTOs.
  An available capability may be advertised only when its projection names at
  least one executable operation.
  """

  alias AppKit.BackendConfig
  alias AppKit.Core.ProductSurface.{CapabilityProjection, RunProjection}

  @backend_key :product_surface_backend
  @default_backend AppKit.Bridges.MezzanineBridge.ProductSurfaceAdapter

  @spec run_projection(term(), String.t(), keyword()) ::
          {:ok, RunProjection.t()} | {:error, term()}
  def run_projection(context, run_ref, opts \\ [])

  def run_projection(context, run_ref, opts)
      when is_binary(run_ref) and run_ref != "" and is_list(opts) do
    with {:ok, projection} <- backend(opts).run_projection(context, run_ref, opts),
         {:ok, projection} <- RunProjection.new(projection) do
      {:ok, projection}
    end
  end

  def run_projection(_context, _run_ref, _opts),
    do: {:error, :invalid_product_run_projection_request}

  @spec capabilities(term(), map(), keyword()) ::
          {:ok, [CapabilityProjection.t()]} | {:error, term()}
  def capabilities(context, request \\ %{}, opts \\ [])

  def capabilities(context, request, opts)
      when is_map(request) and is_list(opts) do
    with {:ok, projections} <- backend(opts).capability_projections(context, request, opts),
         true <- is_list(projections),
         {:ok, projections} <- validate_capabilities(projections) do
      {:ok, projections}
    else
      false -> {:error, :invalid_product_capability_projection}
      {:error, reason} -> {:error, reason}
    end
  end

  def capabilities(_context, _request, _opts),
    do: {:error, :invalid_product_capability_projection_request}

  @spec advertised_capabilities(term(), map(), keyword()) ::
          {:ok, [CapabilityProjection.t()]} | {:error, term()}
  def advertised_capabilities(context, request \\ %{}, opts \\ []) do
    with {:ok, projections} <- capabilities(context, request, opts) do
      {:ok, Enum.filter(projections, & &1.advertised?)}
    end
  end

  defp validate_capabilities(projections) do
    Enum.reduce_while(projections, {:ok, []}, fn projection, {:ok, acc} ->
      case CapabilityProjection.new(projection) do
        {:ok, projection} -> {:cont, {:ok, [projection | acc]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, projections} -> {:ok, Enum.reverse(projections)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp backend(opts) do
    BackendConfig.resolve(opts, :backend, @backend_key, @default_backend)
  end
end
