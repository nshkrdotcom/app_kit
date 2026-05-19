defmodule AppKit.Core.OperatorAction do
  @moduledoc """
  Stable northbound operator action descriptor.
  """

  alias AppKit.Core.{OperatorActionRef, Support}

  @enforce_keys [:action_ref]
  defstruct [
    :action_ref,
    label: nil,
    description: nil,
    dangerous?: false,
    requires_confirmation?: false,
    metadata: %{}
  ]

  @type t :: %__MODULE__{
          action_ref: OperatorActionRef.t(),
          label: String.t() | nil,
          description: String.t() | nil,
          dangerous?: boolean(),
          requires_confirmation?: boolean(),
          metadata: map()
        }

  @spec new(map() | keyword()) :: {:ok, t()} | {:error, :invalid_operator_action}
  def new(attrs) do
    with {:ok, attrs} <- Support.normalize_attrs(attrs),
         {:ok, action_ref} <-
           Support.nested_struct(Map.get(attrs, :action_ref), OperatorActionRef),
         false <- is_nil(action_ref),
         label <- Map.get(attrs, :label),
         true <- Support.optional_binary?(label),
         description <- Map.get(attrs, :description),
         true <- Support.optional_binary?(description),
         dangerous? <- Map.get(attrs, :dangerous?, false),
         true <- is_boolean(dangerous?),
         requires_confirmation? <- Map.get(attrs, :requires_confirmation?, false),
         true <- is_boolean(requires_confirmation?),
         metadata <- Map.get(attrs, :metadata, %{}),
         true <- is_map(metadata) do
      {:ok,
       %__MODULE__{
         action_ref: action_ref,
         label: label,
         description: description,
         dangerous?: dangerous?,
         requires_confirmation?: requires_confirmation?,
         metadata: metadata
       }}
    else
      _ -> {:error, :invalid_operator_action}
    end
  end

  @spec new!(map() | keyword()) :: t()
  def new!(attrs) do
    case new(attrs) do
      {:ok, action} -> action
      {:error, reason} -> raise ArgumentError, "invalid operator action: #{inspect(reason)}"
    end
  end
end

defmodule AppKit.Core.OperatorActionRequest do
  @moduledoc """
  Stable northbound operator action request envelope.
  """

  alias AppKit.Core.{OperatorActionRef, Support}

  @enforce_keys [:action_ref]
  defstruct [:action_ref, params: %{}, reason: nil, metadata: %{}]

  @type t :: %__MODULE__{
          action_ref: OperatorActionRef.t(),
          params: map(),
          reason: String.t() | nil,
          metadata: map()
        }

  @spec new(map() | keyword()) :: {:ok, t()} | {:error, :invalid_operator_action_request}
  def new(attrs) do
    with {:ok, attrs} <- Support.normalize_attrs(attrs),
         {:ok, action_ref} <-
           Support.nested_struct(Map.get(attrs, :action_ref), OperatorActionRef),
         false <- is_nil(action_ref),
         params <- Map.get(attrs, :params, %{}),
         true <- is_map(params),
         reason <- Map.get(attrs, :reason),
         true <- Support.optional_binary?(reason),
         metadata <- Map.get(attrs, :metadata, %{}),
         true <- is_map(metadata) do
      {:ok,
       %__MODULE__{
         action_ref: action_ref,
         params: params,
         reason: reason,
         metadata: metadata
       }}
    else
      _ -> {:error, :invalid_operator_action_request}
    end
  end
end
