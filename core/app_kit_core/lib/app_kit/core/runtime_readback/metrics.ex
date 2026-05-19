defmodule AppKit.Core.RuntimeReadback.RateLimitSnapshot do
  @moduledoc "Bounded rate-limit readback DTO."

  alias AppKit.Core.RuntimeReadback.Support

  @enforce_keys [:limit_id, :remaining]
  defstruct [:limit_id, :name, :remaining, :reset_at, :window, :source_event_ref]

  def new(%__MODULE__{} = value), do: {:ok, value}

  def new(attrs) do
    with {:ok, attrs, nil} <- Support.normalize(attrs),
         :ok <- Support.reject_selectors(attrs, :invalid_rate_limit_snapshot),
         limit_id when is_binary(limit_id) <- Support.required(attrs, :limit_id),
         true <- Support.safe_ref?(limit_id),
         name <- Support.optional(attrs, :name),
         true <- is_nil(name) or is_binary(name),
         remaining <- Support.required(attrs, :remaining),
         true <- Support.non_neg_integer?(remaining),
         reset_at <- Support.optional(attrs, :reset_at),
         true <- Support.optional_timestamp?(reset_at),
         window <- Support.optional(attrs, :window),
         true <- is_nil(window) or is_binary(window),
         source_event_ref <- Support.optional(attrs, :source_event_ref),
         true <- Support.optional_ref?(source_event_ref) do
      {:ok,
       %__MODULE__{
         limit_id: limit_id,
         name: name,
         remaining: remaining,
         reset_at: reset_at,
         window: window,
         source_event_ref: source_event_ref
       }}
    else
      _ -> {:error, :invalid_rate_limit_snapshot}
    end
  end

  def dump(%__MODULE__{} = value), do: Support.dump_struct(value)
end

defmodule AppKit.Core.RuntimeReadback.TokenTotals do
  @moduledoc "Token aggregate readback without provider payloads."

  alias AppKit.Core.RuntimeReadback.Support

  defstruct total_input_tokens: 0,
            total_output_tokens: 0,
            total_tokens: 0,
            cached_input_tokens: 0,
            source: nil

  def new(%__MODULE__{} = value), do: {:ok, value}

  def new(attrs) do
    with {:ok, attrs, nil} <- Support.normalize(attrs),
         :ok <- Support.reject_selectors(attrs, :invalid_token_totals),
         input <- Support.optional(attrs, :total_input_tokens, 0),
         true <- Support.non_neg_integer?(input),
         output <- Support.optional(attrs, :total_output_tokens, 0),
         true <- Support.non_neg_integer?(output),
         total <- Support.optional(attrs, :total_tokens, input + output),
         true <- Support.non_neg_integer?(total),
         cached <- Support.optional(attrs, :cached_input_tokens, 0),
         true <- Support.non_neg_integer?(cached),
         source <- Support.optional(attrs, :source),
         true <- Support.optional_ref?(source) do
      {:ok,
       %__MODULE__{
         total_input_tokens: input,
         total_output_tokens: output,
         total_tokens: total,
         cached_input_tokens: cached,
         source: source
       }}
    else
      _ -> {:error, :invalid_token_totals}
    end
  end

  def dump(%__MODULE__{} = value), do: Support.dump_struct(value)
end
