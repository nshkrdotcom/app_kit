defmodule AppKit.Core.RuntimeReadback.RetryRow do
  @moduledoc "Retry attempt readback row."

  alias AppKit.Core.RuntimeReadback.Support

  @enforce_keys [:attempt_ref, :status]
  defstruct [
    :retry_ref,
    :attempt_ref,
    :status,
    :reason,
    :scheduled_at,
    :due_at,
    :delay_ms,
    :delay_type,
    :continuation?,
    :worker_ref,
    :workspace_ref,
    :last_error_ref,
    metadata: %{}
  ]

  def new(%__MODULE__{} = value), do: {:ok, value}

  def new(attrs) do
    with {:ok, attrs, nil} <- Support.normalize(attrs),
         :ok <- Support.reject_selectors(attrs, :invalid_retry_row),
         retry_ref <- Support.optional(attrs, :retry_ref),
         true <- Support.optional_ref?(retry_ref),
         attempt_ref when is_binary(attempt_ref) <- Support.required(attrs, :attempt_ref),
         true <- Support.safe_ref?(attempt_ref),
         status <- Support.required(attrs, :status),
         true <- Support.atomish?(status),
         reason <- Support.optional(attrs, :reason),
         true <- is_nil(reason) or is_binary(reason),
         scheduled_at <- Support.optional(attrs, :scheduled_at),
         true <- Support.optional_timestamp?(scheduled_at),
         due_at <- Support.optional(attrs, :due_at),
         true <- Support.optional_timestamp?(due_at),
         delay_ms <- Support.optional(attrs, :delay_ms),
         true <- is_nil(delay_ms) or (is_integer(delay_ms) and delay_ms >= 0),
         delay_type <- Support.optional(attrs, :delay_type),
         true <- is_nil(delay_type) or is_binary(delay_type),
         continuation? <- Support.optional(attrs, :continuation?, false),
         true <- is_boolean(continuation?),
         worker_ref <- Support.optional(attrs, :worker_ref),
         true <- Support.optional_ref?(worker_ref),
         workspace_ref <- Support.optional(attrs, :workspace_ref),
         true <- Support.optional_ref?(workspace_ref),
         last_error_ref <- Support.optional(attrs, :last_error_ref),
         true <- Support.optional_ref?(last_error_ref),
         metadata <- Support.optional(attrs, :metadata, %{}),
         true <- is_map(metadata) do
      {:ok,
       %__MODULE__{
         retry_ref: retry_ref,
         attempt_ref: attempt_ref,
         status: status,
         reason: reason,
         scheduled_at: scheduled_at,
         due_at: due_at,
         delay_ms: delay_ms,
         delay_type: delay_type,
         continuation?: continuation?,
         worker_ref: worker_ref,
         workspace_ref: workspace_ref,
         last_error_ref: last_error_ref,
         metadata: metadata
       }}
    else
      _ -> {:error, :invalid_retry_row}
    end
  end

  def dump(%__MODULE__{} = value) do
    %{
      "retry_ref" => value.retry_ref,
      "attempt_ref" => value.attempt_ref,
      "status" => normalize_atomish(value.status),
      "reason" => value.reason,
      "scheduled_at" => timestamp_dump(value.scheduled_at),
      "due_at" => timestamp_dump(value.due_at),
      "delay_ms" => value.delay_ms,
      "delay_type" => value.delay_type,
      "continuation?" => if(value.continuation?, do: true),
      "worker_ref" => value.worker_ref,
      "workspace_ref" => value.workspace_ref,
      "last_error_ref" => value.last_error_ref,
      "metadata" => non_empty_map(value.metadata)
    }
    |> Map.reject(fn {_key, value} -> is_nil(value) end)
  end

  defp timestamp_dump(%DateTime{} = value), do: DateTime.to_iso8601(value)
  defp timestamp_dump(value), do: value
  defp normalize_atomish(value) when is_atom(value), do: Atom.to_string(value)
  defp normalize_atomish(value), do: value
  defp non_empty_map(map) when is_map(map) and map_size(map) > 0, do: map
  defp non_empty_map(_map), do: nil
end
