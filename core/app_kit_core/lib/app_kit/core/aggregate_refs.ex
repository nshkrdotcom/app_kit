defmodule AppKit.Core.SubjectRef do
  @moduledoc """
  Stable northbound subject reference.
  """

  alias AppKit.Core.{InstallationRef, Support}

  @enforce_keys [:id, :subject_kind]
  defstruct [:id, :subject_kind, installation_ref: nil]

  @type t :: %__MODULE__{
          id: String.t(),
          subject_kind: String.t(),
          installation_ref: InstallationRef.t() | nil
        }

  @spec new(map() | keyword()) :: {:ok, t()} | {:error, :invalid_subject_ref}
  def new(attrs) do
    with {:ok, attrs} <- Support.normalize_attrs(attrs),
         id <- Map.get(attrs, :id),
         true <- Support.present_binary?(id),
         subject_kind <- Map.get(attrs, :subject_kind),
         true <- Support.present_binary?(subject_kind),
         {:ok, installation_ref} <-
           Support.nested_struct(Map.get(attrs, :installation_ref), InstallationRef) do
      {:ok, %__MODULE__{id: id, subject_kind: subject_kind, installation_ref: installation_ref}}
    else
      _ -> {:error, :invalid_subject_ref}
    end
  end
end

defmodule AppKit.Core.ExecutionRef do
  @moduledoc """
  Stable northbound execution reference.
  """

  alias AppKit.Core.{SubjectRef, Support}

  @enforce_keys [:id]
  defstruct [:id, subject_ref: nil, recipe_ref: nil, dispatch_state: nil]

  @type t :: %__MODULE__{
          id: String.t(),
          subject_ref: SubjectRef.t() | nil,
          recipe_ref: String.t() | nil,
          dispatch_state: atom() | String.t() | nil
        }

  @spec new(map() | keyword()) :: {:ok, t()} | {:error, :invalid_execution_ref}
  def new(attrs) do
    with {:ok, attrs} <- Support.normalize_attrs(attrs),
         id <- Map.get(attrs, :id),
         true <- Support.present_binary?(id),
         {:ok, subject_ref} <- Support.nested_struct(Map.get(attrs, :subject_ref), SubjectRef),
         recipe_ref <- Map.get(attrs, :recipe_ref),
         true <- Support.optional_binary?(recipe_ref),
         dispatch_state <- Map.get(attrs, :dispatch_state),
         true <- Support.optional_atom_or_binary?(dispatch_state) do
      {:ok,
       %__MODULE__{
         id: id,
         subject_ref: subject_ref,
         recipe_ref: recipe_ref,
         dispatch_state: dispatch_state
       }}
    else
      _ -> {:error, :invalid_execution_ref}
    end
  end
end

defmodule AppKit.Core.DecisionRef do
  @moduledoc """
  Stable northbound decision reference.
  """

  alias AppKit.Core.{SubjectRef, Support}

  @enforce_keys [:id, :decision_kind]
  defstruct [:id, :decision_kind, subject_ref: nil]

  @type t :: %__MODULE__{
          id: String.t(),
          decision_kind: String.t(),
          subject_ref: SubjectRef.t() | nil
        }

  @spec new(map() | keyword()) :: {:ok, t()} | {:error, :invalid_decision_ref}
  def new(attrs) do
    with {:ok, attrs} <- Support.normalize_attrs(attrs),
         id <- Map.get(attrs, :id),
         true <- Support.present_binary?(id),
         decision_kind <- Map.get(attrs, :decision_kind),
         true <- Support.present_binary?(decision_kind),
         {:ok, subject_ref} <- Support.nested_struct(Map.get(attrs, :subject_ref), SubjectRef) do
      {:ok, %__MODULE__{id: id, decision_kind: decision_kind, subject_ref: subject_ref}}
    else
      _ -> {:error, :invalid_decision_ref}
    end
  end
end

defmodule AppKit.Core.ProjectionRef do
  @moduledoc """
  Stable northbound projection reference.
  """

  alias AppKit.Core.{SubjectRef, Support}

  @enforce_keys [:name]
  defstruct [:name, subject_ref: nil, schema_ref: nil, schema_version: nil]

  @type t :: %__MODULE__{
          name: String.t(),
          subject_ref: SubjectRef.t() | nil,
          schema_ref: String.t() | nil,
          schema_version: non_neg_integer() | nil
        }

  @spec new(map() | keyword()) :: {:ok, t()} | {:error, :invalid_projection_ref}
  def new(attrs) do
    with {:ok, attrs} <- Support.normalize_attrs(attrs),
         name <- Map.get(attrs, :name),
         true <- Support.present_binary?(name),
         {:ok, subject_ref} <- Support.nested_struct(Map.get(attrs, :subject_ref), SubjectRef),
         schema_ref <- Map.get(attrs, :schema_ref),
         true <- Support.optional_binary?(schema_ref),
         schema_version <- Map.get(attrs, :schema_version),
         true <- Support.optional_non_neg_integer?(schema_version) do
      {:ok,
       %__MODULE__{
         name: name,
         subject_ref: subject_ref,
         schema_ref: schema_ref,
         schema_version: schema_version
       }}
    else
      _ -> {:error, :invalid_projection_ref}
    end
  end
end

defmodule AppKit.Core.OperatorActionRef do
  @moduledoc """
  Stable northbound operator action reference.
  """

  alias AppKit.Core.{SubjectRef, Support}

  @enforce_keys [:id, :action_kind]
  defstruct [:id, :action_kind, subject_ref: nil]

  @type t :: %__MODULE__{
          id: String.t(),
          action_kind: String.t(),
          subject_ref: SubjectRef.t() | nil
        }

  @spec new(map() | keyword()) :: {:ok, t()} | {:error, :invalid_operator_action_ref}
  def new(attrs) do
    with {:ok, attrs} <- Support.normalize_attrs(attrs),
         id <- Map.get(attrs, :id),
         true <- Support.present_binary?(id),
         action_kind <- Map.get(attrs, :action_kind),
         true <- Support.present_binary?(action_kind),
         {:ok, subject_ref} <- Support.nested_struct(Map.get(attrs, :subject_ref), SubjectRef) do
      {:ok, %__MODULE__{id: id, action_kind: action_kind, subject_ref: subject_ref}}
    else
      _ -> {:error, :invalid_operator_action_ref}
    end
  end
end

defmodule AppKit.Core.ReadLeaseRef do
  @moduledoc """
  Stable northbound read-lease reference.
  """

  alias AppKit.Core.{ExecutionRef, Support}

  @enforce_keys [:id, :allowed_family]
  defstruct [:id, :allowed_family, execution_ref: nil]

  @type t :: %__MODULE__{
          id: String.t(),
          allowed_family: String.t(),
          execution_ref: ExecutionRef.t() | nil
        }

  @spec new(map() | keyword()) :: {:ok, t()} | {:error, :invalid_read_lease_ref}
  def new(attrs) do
    with {:ok, attrs} <- Support.normalize_attrs(attrs),
         id <- Map.get(attrs, :id),
         true <- Support.present_binary?(id),
         allowed_family <- Map.get(attrs, :allowed_family),
         true <- Support.present_binary?(allowed_family),
         {:ok, execution_ref} <-
           Support.nested_struct(Map.get(attrs, :execution_ref), ExecutionRef) do
      {:ok,
       %__MODULE__{
         id: id,
         allowed_family: allowed_family,
         execution_ref: execution_ref
       }}
    else
      _ -> {:error, :invalid_read_lease_ref}
    end
  end
end

defmodule AppKit.Core.StreamAttachLeaseRef do
  @moduledoc """
  Stable northbound stream-attach lease reference.
  """

  alias AppKit.Core.{ExecutionRef, Support}

  @enforce_keys [:id, :allowed_family]
  defstruct [:id, :allowed_family, execution_ref: nil]

  @type t :: %__MODULE__{
          id: String.t(),
          allowed_family: String.t(),
          execution_ref: ExecutionRef.t() | nil
        }

  @spec new(map() | keyword()) ::
          {:ok, t()} | {:error, :invalid_stream_attach_lease_ref}
  def new(attrs) do
    with {:ok, attrs} <- Support.normalize_attrs(attrs),
         id <- Map.get(attrs, :id),
         true <- Support.present_binary?(id),
         allowed_family <- Map.get(attrs, :allowed_family),
         true <- Support.present_binary?(allowed_family),
         {:ok, execution_ref} <-
           Support.nested_struct(Map.get(attrs, :execution_ref), ExecutionRef) do
      {:ok,
       %__MODULE__{
         id: id,
         allowed_family: allowed_family,
         execution_ref: execution_ref
       }}
    else
      _ -> {:error, :invalid_stream_attach_lease_ref}
    end
  end
end

defmodule AppKit.Core.SubjectSummary do
  @moduledoc """
  Stable northbound subject summary aggregate.
  """

  alias AppKit.Core.{SubjectRef, Support}

  @enforce_keys [:subject_ref, :lifecycle_state]
  defstruct [
    :subject_ref,
    :lifecycle_state,
    title: nil,
    summary: nil,
    opened_at: nil,
    updated_at: nil,
    schema_ref: nil,
    schema_version: nil,
    payload: %{}
  ]

  @type t :: %__MODULE__{
          subject_ref: SubjectRef.t(),
          lifecycle_state: String.t(),
          title: String.t() | nil,
          summary: String.t() | nil,
          opened_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil,
          schema_ref: String.t() | nil,
          schema_version: non_neg_integer() | nil,
          payload: map()
        }

  @spec new(map() | keyword()) :: {:ok, t()} | {:error, :invalid_subject_summary}
  def new(attrs) do
    with {:ok, attrs} <- Support.normalize_attrs(attrs),
         {:ok, subject_ref} <- Support.nested_struct(Map.get(attrs, :subject_ref), SubjectRef),
         false <- is_nil(subject_ref),
         lifecycle_state <- Map.get(attrs, :lifecycle_state),
         true <- Support.present_binary?(lifecycle_state),
         title <- Map.get(attrs, :title),
         true <- Support.optional_binary?(title),
         summary <- Map.get(attrs, :summary),
         true <- Support.optional_binary?(summary),
         opened_at <- Map.get(attrs, :opened_at),
         true <- Support.optional_datetime?(opened_at),
         updated_at <- Map.get(attrs, :updated_at),
         true <- Support.optional_datetime?(updated_at),
         schema_ref <- Map.get(attrs, :schema_ref),
         true <- Support.optional_binary?(schema_ref),
         schema_version <- Map.get(attrs, :schema_version),
         true <- Support.optional_non_neg_integer?(schema_version),
         payload <- Map.get(attrs, :payload, %{}),
         true <- is_map(payload) do
      {:ok,
       %__MODULE__{
         subject_ref: subject_ref,
         lifecycle_state: lifecycle_state,
         title: title,
         summary: summary,
         opened_at: opened_at,
         updated_at: updated_at,
         schema_ref: schema_ref,
         schema_version: schema_version,
         payload: payload
       }}
    else
      _ -> {:error, :invalid_subject_summary}
    end
  end
end

defmodule AppKit.Core.SubjectDetail do
  @moduledoc """
  Stable northbound subject detail aggregate.
  """

  alias AppKit.Core.{
    BlockingCondition,
    DecisionRef,
    ExecutionRef,
    NextStepPreview,
    OperatorActionRef,
    PendingObligation,
    SubjectRef,
    Support
  }

  @enforce_keys [:subject_ref, :lifecycle_state]
  defstruct [
    :subject_ref,
    :lifecycle_state,
    title: nil,
    description: nil,
    current_execution_ref: nil,
    pending_decision_refs: [],
    available_actions: [],
    pending_obligations: [],
    blocking_conditions: [],
    next_step_preview: nil,
    schema_ref: nil,
    schema_version: nil,
    payload: %{}
  ]

  @type t :: %__MODULE__{
          subject_ref: SubjectRef.t(),
          lifecycle_state: String.t(),
          title: String.t() | nil,
          description: String.t() | nil,
          current_execution_ref: ExecutionRef.t() | nil,
          pending_decision_refs: [DecisionRef.t()],
          available_actions: [OperatorActionRef.t()],
          pending_obligations: [PendingObligation.t()],
          blocking_conditions: [BlockingCondition.t()],
          next_step_preview: NextStepPreview.t() | nil,
          schema_ref: String.t() | nil,
          schema_version: non_neg_integer() | nil,
          payload: map()
        }

  @spec new(map() | keyword()) :: {:ok, t()} | {:error, :invalid_subject_detail}
  def new(attrs) do
    with {:ok, attrs} <- Support.normalize_attrs(attrs),
         {:ok, subject_ref} <- Support.nested_struct(Map.get(attrs, :subject_ref), SubjectRef),
         false <- is_nil(subject_ref),
         lifecycle_state <- Map.get(attrs, :lifecycle_state),
         true <- Support.present_binary?(lifecycle_state),
         title <- Map.get(attrs, :title),
         true <- Support.optional_binary?(title),
         description <- Map.get(attrs, :description),
         true <- Support.optional_binary?(description),
         {:ok, current_execution_ref} <-
           Support.nested_struct(Map.get(attrs, :current_execution_ref), ExecutionRef),
         {:ok, pending_decision_refs} <-
           Support.nested_structs(Map.get(attrs, :pending_decision_refs, []), DecisionRef),
         {:ok, available_actions} <-
           Support.nested_structs(Map.get(attrs, :available_actions, []), OperatorActionRef),
         {:ok, pending_obligations} <-
           Support.nested_structs(
             Map.get(attrs, :pending_obligations, []),
             PendingObligation
           ),
         {:ok, blocking_conditions} <-
           Support.nested_structs(
             Map.get(attrs, :blocking_conditions, []),
             BlockingCondition
           ),
         {:ok, next_step_preview} <-
           Support.nested_struct(Map.get(attrs, :next_step_preview), NextStepPreview),
         schema_ref <- Map.get(attrs, :schema_ref),
         true <- Support.optional_binary?(schema_ref),
         schema_version <- Map.get(attrs, :schema_version),
         true <- Support.optional_non_neg_integer?(schema_version),
         payload <- Map.get(attrs, :payload, %{}),
         true <- is_map(payload) do
      {:ok,
       %__MODULE__{
         subject_ref: subject_ref,
         lifecycle_state: lifecycle_state,
         title: title,
         description: description,
         current_execution_ref: current_execution_ref,
         pending_decision_refs: pending_decision_refs,
         available_actions: available_actions,
         pending_obligations: pending_obligations,
         blocking_conditions: blocking_conditions,
         next_step_preview: next_step_preview,
         schema_ref: schema_ref,
         schema_version: schema_version,
         payload: payload
       }}
    else
      _ -> {:error, :invalid_subject_detail}
    end
  end
end

defmodule AppKit.Core.DecisionSummary do
  @moduledoc """
  Stable northbound decision summary aggregate.
  """

  alias AppKit.Core.{DecisionRef, SubjectRef, Support}

  @enforce_keys [:decision_ref, :status]
  defstruct [
    :decision_ref,
    :status,
    required_by: nil,
    subject_ref: nil,
    summary: nil,
    schema_ref: nil,
    schema_version: nil,
    payload: %{}
  ]

  @type t :: %__MODULE__{
          decision_ref: DecisionRef.t(),
          status: String.t(),
          required_by: DateTime.t() | nil,
          subject_ref: SubjectRef.t() | nil,
          summary: String.t() | nil,
          schema_ref: String.t() | nil,
          schema_version: non_neg_integer() | nil,
          payload: map()
        }

  @spec new(map() | keyword()) :: {:ok, t()} | {:error, :invalid_decision_summary}
  def new(attrs) do
    with {:ok, attrs} <- Support.normalize_attrs(attrs),
         {:ok, decision_ref} <- Support.nested_struct(Map.get(attrs, :decision_ref), DecisionRef),
         false <- is_nil(decision_ref),
         status <- Map.get(attrs, :status),
         true <- Support.present_binary?(status),
         required_by <- Map.get(attrs, :required_by),
         true <- Support.optional_datetime?(required_by),
         {:ok, subject_ref} <- Support.nested_struct(Map.get(attrs, :subject_ref), SubjectRef),
         summary <- Map.get(attrs, :summary),
         true <- Support.optional_binary?(summary),
         schema_ref <- Map.get(attrs, :schema_ref),
         true <- Support.optional_binary?(schema_ref),
         schema_version <- Map.get(attrs, :schema_version),
         true <- Support.optional_non_neg_integer?(schema_version),
         payload <- Map.get(attrs, :payload, %{}),
         true <- is_map(payload) do
      {:ok,
       %__MODULE__{
         decision_ref: decision_ref,
         status: status,
         required_by: required_by,
         subject_ref: subject_ref,
         summary: summary,
         schema_ref: schema_ref,
         schema_version: schema_version,
         payload: payload
       }}
    else
      _ -> {:error, :invalid_decision_summary}
    end
  end
end
