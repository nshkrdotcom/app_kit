defmodule AppKit.Core.SurfaceError do
  @moduledoc """
  Stable northbound surface error envelope.
  """

  alias AppKit.Core.Support

  @kinds [:validation, :authorization, :not_found, :conflict, :boundary, :transient, :terminal]

  @enforce_keys [:code, :message]
  defstruct [:code, :message, kind: nil, retryable: nil, details: %{}, cause_ref: nil]

  @type kind ::
          :validation
          | :authorization
          | :not_found
          | :conflict
          | :boundary
          | :transient
          | :terminal

  @type t :: %__MODULE__{
          code: String.t(),
          message: String.t(),
          kind: kind() | nil,
          retryable: boolean() | nil,
          details: map(),
          cause_ref: String.t() | nil
        }

  @spec new(map() | keyword()) :: {:ok, t()} | {:error, :invalid_surface_error}
  def new(attrs) do
    with {:ok, attrs} <- Support.normalize_attrs(attrs),
         code <- Map.get(attrs, :code),
         true <- Support.present_binary?(code),
         message <- Map.get(attrs, :message),
         true <- Support.present_binary?(message),
         kind <- Map.get(attrs, :kind),
         true <- Support.optional_enum?(kind, @kinds),
         retryable <- Map.get(attrs, :retryable),
         true <- Support.optional_boolean?(retryable),
         details <- Map.get(attrs, :details, %{}),
         true <- is_map(details),
         cause_ref <- Map.get(attrs, :cause_ref),
         true <- Support.optional_binary?(cause_ref) do
      {:ok,
       %__MODULE__{
         code: code,
         message: message,
         kind: kind,
         retryable: retryable,
         details: details,
         cause_ref: cause_ref
       }}
    else
      _ -> {:error, :invalid_surface_error}
    end
  end
end

defmodule AppKit.Core.ActionResult do
  @moduledoc """
  Stable northbound action outcome envelope.
  """

  alias AppKit.Core.{ExecutionRef, OperatorActionRef, Support}

  @statuses [:accepted, :completed, :rejected, :failed]

  @enforce_keys [:status]
  defstruct [:status, action_ref: nil, execution_ref: nil, message: nil, metadata: %{}]

  @type status :: :accepted | :completed | :rejected | :failed

  @type t :: %__MODULE__{
          status: status(),
          action_ref: OperatorActionRef.t() | nil,
          execution_ref: ExecutionRef.t() | nil,
          message: String.t() | nil,
          metadata: map()
        }

  @spec new(map() | keyword()) :: {:ok, t()} | {:error, :invalid_action_result}
  def new(attrs) do
    with {:ok, attrs} <- Support.normalize_attrs(attrs),
         status <- Map.get(attrs, :status),
         true <- Support.enum?(status, @statuses),
         {:ok, action_ref} <-
           Support.nested_struct(Map.get(attrs, :action_ref), OperatorActionRef),
         {:ok, execution_ref} <-
           Support.nested_struct(Map.get(attrs, :execution_ref), ExecutionRef),
         message <- Map.get(attrs, :message),
         true <- Support.optional_binary?(message),
         metadata <- Map.get(attrs, :metadata, %{}),
         true <- is_map(metadata) do
      {:ok,
       %__MODULE__{
         status: status,
         action_ref: action_ref,
         execution_ref: execution_ref,
         message: message,
         metadata: metadata
       }}
    else
      _ -> {:error, :invalid_action_result}
    end
  end
end
