defmodule AppKit.Core.Backends.OperatorBackend do
  @moduledoc """
  Backend contract for `AppKit.OperatorSurface`.

  The public operator surface stays stable while projections and review wiring
  can come from different lower implementations.
  """

  alias AppKit.Core.RunRef

  @callback run_status(RunRef.t(), map(), keyword()) :: {:ok, map()} | {:error, atom()}
  @callback review_run(RunRef.t(), map(), keyword()) :: {:ok, map()} | {:error, atom()}
end
