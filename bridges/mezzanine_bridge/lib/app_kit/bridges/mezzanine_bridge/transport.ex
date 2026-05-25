defmodule AppKit.Bridges.MezzanineBridge.Transport do
  @moduledoc """
  Caller-owned transport contract for AppKit calls into Mezzanine.

  The same AppKit bridge can use an in-process Mezzanine facade, a local
  distributed facade, or deterministic fixtures without changing the product
  surface DTOs that AppKit owns.
  """

  @type result :: {:ok, map()} | {:error, map()}

  @callback submit_work(request :: map(), opts :: keyword()) :: result()
  @callback readback(ref :: String.t(), opts :: keyword()) :: result()
end
