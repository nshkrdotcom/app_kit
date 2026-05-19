defmodule AppKit.Core.RuntimeReadback.PollingState do
  @moduledoc "Explicit polling readback state used by headless hosts."

  alias AppKit.Core.RuntimeReadback.Support

  @enforce_keys [:checking?, :poll_interval_ms, :staleness_ms]
  defstruct [
    :checking?,
    :next_poll_at,
    :poll_interval_ms,
    :last_refresh_command_ref,
    :staleness_ms
  ]

  def new(%__MODULE__{} = value), do: {:ok, value}

  def new(attrs) do
    with {:ok, attrs, nil} <- Support.normalize(attrs),
         :ok <- Support.reject_selectors(attrs, :invalid_polling_state),
         checking? <- Support.required(attrs, :checking?),
         true <- Support.bool?(checking?),
         next_poll_at <- Support.optional(attrs, :next_poll_at),
         true <- Support.optional_timestamp?(next_poll_at),
         poll_interval_ms <- Support.required(attrs, :poll_interval_ms),
         true <- Support.non_neg_integer?(poll_interval_ms),
         last_refresh_command_ref <- Support.optional(attrs, :last_refresh_command_ref),
         true <- Support.optional_ref?(last_refresh_command_ref),
         staleness_ms <- Support.required(attrs, :staleness_ms),
         true <- Support.non_neg_integer?(staleness_ms) do
      {:ok,
       %__MODULE__{
         checking?: checking?,
         next_poll_at: next_poll_at,
         poll_interval_ms: poll_interval_ms,
         last_refresh_command_ref: last_refresh_command_ref,
         staleness_ms: staleness_ms
       }}
    else
      _ -> {:error, :invalid_polling_state}
    end
  end

  def dump(%__MODULE__{} = value), do: Support.dump_struct(value)
end
