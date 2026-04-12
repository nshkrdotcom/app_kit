defmodule AppKit.Core.Result do
  @moduledoc """
  Stable app-facing result wrapper for northbound surfaces.
  """

  @type surface ::
          :chat
          | :domain
          | :operator
          | :work_control
          | :runtime_gateway
          | :conversation

  @type state :: :accepted | :scheduled | :waiting_review | :projected | :rejected

  @enforce_keys [:surface, :state]
  defstruct [:surface, :state, payload: %{}, meta: %{}]

  @type t :: %__MODULE__{
          surface: surface(),
          state: state(),
          payload: map(),
          meta: map()
        }

  @spec new(map() | keyword()) :: {:ok, t()} | {:error, atom()}
  def new(attrs) do
    attrs = Map.new(attrs)

    with true <- Map.get(attrs, :surface) in surfaces(),
         true <- Map.get(attrs, :state) in states(),
         payload <- Map.get(attrs, :payload, %{}),
         true <- is_map(payload) do
      {:ok,
       %__MODULE__{
         surface: Map.fetch!(attrs, :surface),
         state: Map.fetch!(attrs, :state),
         payload: payload,
         meta: Map.get(attrs, :meta, %{})
       }}
    else
      false -> {:error, :invalid_result}
    end
  end

  @spec surfaces() :: [surface()]
  def surfaces, do: [:chat, :domain, :operator, :work_control, :runtime_gateway, :conversation]

  @spec states() :: [state()]
  def states, do: [:accepted, :scheduled, :waiting_review, :projected, :rejected]
end
