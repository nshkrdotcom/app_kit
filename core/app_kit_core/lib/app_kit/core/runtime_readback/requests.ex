defmodule AppKit.Core.RuntimeReadback.ControlRequest do
  @moduledoc "Typed control request for M1 command submission."

  alias AppKit.Core.RuntimeReadback.Support

  @actions [
    :pause,
    :resume,
    :cancel,
    :retry,
    :rework,
    :read_lease,
    :stream_attach_lease,
    :review_decision,
    :inspect_trace,
    :inspect_memory_proof,
    "pause",
    "resume",
    "cancel",
    "retry",
    "rework",
    "read_lease",
    "stream_attach_lease",
    "review_decision",
    "inspect_trace",
    "inspect_memory_proof"
  ]

  @enforce_keys [:idempotency_key, :actor_ref, :action]
  defstruct [
    :idempotency_key,
    :actor_ref,
    :subject_ref,
    :run_ref,
    :execution_ref,
    :action,
    params: %{}
  ]

  def new(%__MODULE__{} = value), do: {:ok, value}

  def new(attrs) do
    with {:ok, attrs, nil} <- Support.normalize(attrs),
         :ok <- Support.reject_selectors(attrs, :invalid_control_request),
         idempotency_key when is_binary(idempotency_key) <-
           Support.required(attrs, :idempotency_key),
         actor_ref when is_binary(actor_ref) <- Support.required(attrs, :actor_ref),
         true <- Support.safe_ref?(actor_ref),
         subject_ref <- Support.optional(attrs, :subject_ref),
         true <- Support.optional_ref?(subject_ref),
         run_ref <- Support.optional(attrs, :run_ref),
         true <- Support.optional_ref?(run_ref),
         execution_ref <- Support.optional(attrs, :execution_ref),
         true <- Support.optional_ref?(execution_ref),
         action <- Support.required(attrs, :action),
         true <- action in @actions,
         params <- Support.optional(attrs, :params, %{}),
         true <- is_map(params) do
      {:ok,
       %__MODULE__{
         idempotency_key: idempotency_key,
         actor_ref: actor_ref,
         subject_ref: subject_ref,
         run_ref: run_ref,
         execution_ref: execution_ref,
         action: action,
         params: params
       }}
    else
      _ -> {:error, :invalid_control_request}
    end
  end

  def dump(%__MODULE__{} = value), do: Support.dump_struct(value)
  def new!(attrs), do: new(attrs) |> bang()
  defp bang({:ok, value}), do: value
  defp bang({:error, reason}), do: raise(ArgumentError, Atom.to_string(reason))
end

defmodule AppKit.Core.RuntimeReadback.RefreshRequest do
  @moduledoc "Typed refresh request for M1 readback reconciliation."

  alias AppKit.Core.RuntimeReadback.Support

  @enforce_keys [:idempotency_key, :actor_ref, :scope_ref]
  defstruct [:idempotency_key, :actor_ref, :scope_ref, operations: [], reason: nil]

  def new(%__MODULE__{} = value), do: {:ok, value}

  def new(attrs) do
    with {:ok, attrs, nil} <- Support.normalize(attrs),
         :ok <- Support.reject_selectors(attrs, :invalid_refresh_request),
         idempotency_key when is_binary(idempotency_key) <-
           Support.required(attrs, :idempotency_key),
         actor_ref when is_binary(actor_ref) <- Support.required(attrs, :actor_ref),
         true <- Support.safe_ref?(actor_ref),
         scope_ref when is_binary(scope_ref) <- Support.required(attrs, :scope_ref),
         true <- Support.safe_ref?(scope_ref),
         operations <- Support.optional(attrs, :operations, []),
         true <- is_list(operations) and Enum.all?(operations, &Support.atomish?/1),
         reason <- Support.optional(attrs, :reason),
         true <- is_nil(reason) or is_binary(reason) do
      {:ok,
       %__MODULE__{
         idempotency_key: idempotency_key,
         actor_ref: actor_ref,
         scope_ref: scope_ref,
         operations: operations,
         reason: reason
       }}
    else
      _ -> {:error, :invalid_refresh_request}
    end
  end

  def dump(%__MODULE__{} = value), do: Support.dump_struct(value)
  def new!(attrs), do: new(attrs) |> bang()
  defp bang({:ok, value}), do: value
  defp bang({:error, reason}), do: raise(ArgumentError, Atom.to_string(reason))
end
