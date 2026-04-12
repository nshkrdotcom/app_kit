defmodule AppKit.RuntimeGateway do
  @moduledoc """
  App-facing runtime gateway descriptors above lower runtime mechanics.
  """

  alias AppKit.ScopeObjects.ManagedTarget

  @enforce_keys [:target, :mode, :transport]
  defstruct [:target, :mode, :transport]

  @type t :: %__MODULE__{
          target: ManagedTarget.t(),
          mode: :attached | :detached,
          transport: :session | :job
        }

  @spec open(ManagedTarget.t(), keyword()) :: {:ok, t()} | {:error, atom()}
  def open(%ManagedTarget{} = target, opts \\ []) do
    mode = Keyword.get(opts, :mode, :attached)
    transport = Keyword.get(opts, :transport, :session)

    if mode in [:attached, :detached] and transport in [:session, :job] do
      {:ok, %__MODULE__{target: target, mode: mode, transport: transport}}
    else
      {:error, :invalid_runtime_gateway}
    end
  end
end
