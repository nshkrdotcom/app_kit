defmodule AppKit.Core.RunRef do
  @moduledoc """
  Stable run reference used across AppKit surfaces.
  """

  @enforce_keys [:run_id, :scope_id]
  defstruct [:run_id, :scope_id, metadata: %{}]

  @type t :: %__MODULE__{
          run_id: String.t(),
          scope_id: String.t(),
          metadata: map()
        }

  @spec new(map() | keyword()) :: {:ok, t()} | {:error, atom()}
  def new(attrs) do
    attrs = Map.new(attrs)

    with run_id when is_binary(run_id) <- Map.get(attrs, :run_id),
         scope_id when is_binary(scope_id) <- Map.get(attrs, :scope_id) do
      {:ok,
       %__MODULE__{
         run_id: run_id,
         scope_id: scope_id,
         metadata: Map.get(attrs, :metadata, %{})
       }}
    else
      _ -> {:error, :invalid_run_ref}
    end
  end
end
