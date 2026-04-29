defmodule AppKit.NoBypass.Scanner do
  @moduledoc """
  Product-boundary scanner facade for AppKit consumers.

  This module preserves the product-facing scanner name while the implementation
  remains in `AppKit.Boundary.NoBypass`.
  """

  alias AppKit.Boundary.NoBypass

  @spec scan(keyword()) :: {:ok, map()} | {:error, map()}
  def scan(opts \\ []), do: NoBypass.scan(opts)

  @spec format_violation(NoBypass.Violation.t()) :: String.t()
  def format_violation(violation), do: NoBypass.format_violation(violation)
end
