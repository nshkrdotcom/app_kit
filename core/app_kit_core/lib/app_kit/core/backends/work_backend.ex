defmodule AppKit.Core.Backends.WorkBackend do
  @moduledoc """
  Backend contract for `AppKit.WorkControl`.

  This keeps the northbound surface stable while allowing different lower
  implementations to back it.
  """

  alias AppKit.Core.Result

  @callback start_run(map(), keyword()) :: {:ok, Result.t()} | {:error, atom()}
end
