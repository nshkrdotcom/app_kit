defmodule AppKit.Core.RunRequest do
  @moduledoc """
  Stable northbound work-control request envelope.
  """

  alias AppKit.Core.{SubjectRef, Support}

  @enforce_keys [:subject_ref]
  defstruct [:subject_ref, recipe_ref: nil, params: %{}, reason: nil, metadata: %{}]

  @type t :: %__MODULE__{
          subject_ref: SubjectRef.t(),
          recipe_ref: String.t() | nil,
          params: map(),
          reason: String.t() | nil,
          metadata: map()
        }

  @spec new(map() | keyword()) :: {:ok, t()} | {:error, :invalid_run_request}
  def new(attrs) do
    with {:ok, attrs} <- Support.normalize_attrs(attrs),
         {:ok, subject_ref} <- Support.nested_struct(Map.get(attrs, :subject_ref), SubjectRef),
         false <- is_nil(subject_ref),
         recipe_ref <- Map.get(attrs, :recipe_ref),
         true <- Support.optional_binary?(recipe_ref),
         params <- Map.get(attrs, :params, %{}),
         true <- is_map(params),
         reason <- Map.get(attrs, :reason),
         true <- Support.optional_binary?(reason),
         metadata <- Map.get(attrs, :metadata, %{}),
         true <- is_map(metadata) do
      {:ok,
       %__MODULE__{
         subject_ref: subject_ref,
         recipe_ref: recipe_ref,
         params: params,
         reason: reason,
         metadata: metadata
       }}
    else
      _ -> {:error, :invalid_run_request}
    end
  end
end
