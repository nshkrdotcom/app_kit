defmodule AppKit.Core.Backends.ProductSurfaceBackend do
  @moduledoc """
  Backend contract for the composite durable product projection and executable
  capability catalog.

  Implementations must assemble owner-backed facts behind AppKit. Products
  never select or query lower owner modules directly.
  """

  @callback run_projection(
              context :: term(),
              run_ref :: String.t(),
              opts :: keyword()
            ) :: {:ok, struct() | map()} | {:error, term()}

  @callback capability_projections(
              context :: term(),
              request :: map(),
              opts :: keyword()
            ) :: {:ok, [struct() | map()]} | {:error, term()}
end
