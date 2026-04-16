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

defmodule AppKit.Core.TimelineEvent do
  @moduledoc """
  Stable northbound operator timeline entry.
  """

  alias AppKit.Core.{ActorRef, Support}

  @enforce_keys [:event_kind]
  defstruct [
    :event_kind,
    ref: nil,
    occurred_at: nil,
    summary: nil,
    actor_ref: nil,
    payload: %{},
    metadata: %{}
  ]

  @type t :: %__MODULE__{
          event_kind: String.t(),
          ref: String.t() | nil,
          occurred_at: DateTime.t() | nil,
          summary: String.t() | nil,
          actor_ref: ActorRef.t() | nil,
          payload: map(),
          metadata: map()
        }

  @spec new(map() | keyword()) :: {:ok, t()} | {:error, :invalid_timeline_event}
  def new(attrs) do
    with {:ok, attrs} <- Support.normalize_attrs(attrs),
         event_kind <- Map.get(attrs, :event_kind),
         true <- Support.present_binary?(event_kind),
         ref <- Map.get(attrs, :ref),
         true <- Support.optional_binary?(ref),
         occurred_at <- Map.get(attrs, :occurred_at),
         true <- Support.optional_datetime?(occurred_at),
         summary <- Map.get(attrs, :summary),
         true <- Support.optional_binary?(summary),
         {:ok, actor_ref} <- Support.nested_struct(Map.get(attrs, :actor_ref), ActorRef),
         payload <- Map.get(attrs, :payload, %{}),
         true <- is_map(payload),
         metadata <- Map.get(attrs, :metadata, %{}),
         true <- is_map(metadata) do
      {:ok,
       %__MODULE__{
         event_kind: event_kind,
         ref: ref,
         occurred_at: occurred_at,
         summary: summary,
         actor_ref: actor_ref,
         payload: payload,
         metadata: metadata
       }}
    else
      _ -> {:error, :invalid_timeline_event}
    end
  end

  @spec new!(map() | keyword()) :: t()
  def new!(attrs) do
    case new(attrs) do
      {:ok, event} -> event
      {:error, reason} -> raise ArgumentError, "invalid timeline event: #{inspect(reason)}"
    end
  end
end

defmodule AppKit.Core.UnifiedTraceStep do
  @moduledoc """
  Stable northbound unified-trace step.
  """

  alias AppKit.Core.Support

  @enforce_keys [:ref, :source]
  defstruct [
    :ref,
    :source,
    occurred_at: nil,
    trace_id: nil,
    causation_id: nil,
    freshness: nil,
    operator_actionable?: false,
    diagnostic?: false,
    payload: %{}
  ]

  @type t :: %__MODULE__{
          ref: String.t(),
          source: String.t(),
          occurred_at: DateTime.t() | nil,
          trace_id: String.t() | nil,
          causation_id: String.t() | nil,
          freshness: String.t() | nil,
          operator_actionable?: boolean(),
          diagnostic?: boolean(),
          payload: map()
        }

  @spec new(map() | keyword()) :: {:ok, t()} | {:error, :invalid_unified_trace_step}
  def new(attrs) do
    with {:ok, attrs} <- Support.normalize_attrs(attrs),
         ref <- Map.get(attrs, :ref),
         true <- Support.present_binary?(ref),
         source <- Map.get(attrs, :source),
         true <- Support.present_binary?(source),
         occurred_at <- Map.get(attrs, :occurred_at),
         true <- Support.optional_datetime?(occurred_at),
         trace_id <- Map.get(attrs, :trace_id),
         true <- Support.optional_binary?(trace_id),
         causation_id <- Map.get(attrs, :causation_id),
         true <- Support.optional_binary?(causation_id),
         freshness <- Map.get(attrs, :freshness),
         true <- Support.optional_binary?(freshness),
         operator_actionable? <- Map.get(attrs, :operator_actionable?, false),
         true <- is_boolean(operator_actionable?),
         diagnostic? <- Map.get(attrs, :diagnostic?, false),
         true <- is_boolean(diagnostic?),
         payload <- Map.get(attrs, :payload, %{}),
         true <- is_map(payload) do
      {:ok,
       %__MODULE__{
         ref: ref,
         source: source,
         occurred_at: occurred_at,
         trace_id: trace_id,
         causation_id: causation_id,
         freshness: freshness,
         operator_actionable?: operator_actionable?,
         diagnostic?: diagnostic?,
         payload: payload
       }}
    else
      _ -> {:error, :invalid_unified_trace_step}
    end
  end
end

defmodule AppKit.Core.UnifiedTrace do
  @moduledoc """
  Stable northbound unified-trace envelope.
  """

  alias AppKit.Core.{InstallationRef, Support, UnifiedTraceStep}

  @enforce_keys [:trace_id, :steps]
  defstruct [:trace_id, installation_ref: nil, join_keys: %{}, steps: [], metadata: %{}]

  @type t :: %__MODULE__{
          trace_id: String.t(),
          installation_ref: InstallationRef.t() | nil,
          join_keys: map(),
          steps: [UnifiedTraceStep.t()],
          metadata: map()
        }

  @spec new(map() | keyword()) :: {:ok, t()} | {:error, :invalid_unified_trace}
  def new(attrs) do
    with {:ok, attrs} <- Support.normalize_attrs(attrs),
         trace_id <- Map.get(attrs, :trace_id),
         true <- Support.present_binary?(trace_id),
         {:ok, installation_ref} <-
           Support.nested_struct(Map.get(attrs, :installation_ref), InstallationRef),
         steps <- Map.get(attrs, :steps),
         {:ok, steps} <- Support.nested_structs(steps, UnifiedTraceStep),
         join_keys <- Map.get(attrs, :join_keys, %{}),
         true <- is_map(join_keys),
         metadata <- Map.get(attrs, :metadata, %{}),
         true <- is_map(metadata) do
      {:ok,
       %__MODULE__{
         trace_id: trace_id,
         installation_ref: installation_ref,
         join_keys: join_keys,
         steps: steps,
         metadata: metadata
       }}
    else
      _ -> {:error, :invalid_unified_trace}
    end
  end
end

defmodule AppKit.Core.OperatorProjection do
  @moduledoc """
  Stable northbound operator-facing projection envelope.
  """

  alias AppKit.Core.{
    DecisionRef,
    ExecutionRef,
    OperatorAction,
    SubjectRef,
    Support,
    TimelineEvent
  }

  @enforce_keys [:subject_ref, :lifecycle_state]
  defstruct [
    :subject_ref,
    :lifecycle_state,
    current_execution_ref: nil,
    pending_decision_refs: [],
    available_actions: [],
    timeline: [],
    updated_at: nil,
    payload: %{}
  ]

  @type t :: %__MODULE__{
          subject_ref: SubjectRef.t(),
          lifecycle_state: String.t(),
          current_execution_ref: ExecutionRef.t() | nil,
          pending_decision_refs: [DecisionRef.t()],
          available_actions: [OperatorAction.t()],
          timeline: [TimelineEvent.t()],
          updated_at: DateTime.t() | nil,
          payload: map()
        }

  @spec new(map() | keyword()) :: {:ok, t()} | {:error, :invalid_operator_projection}
  def new(attrs) do
    with {:ok, attrs} <- Support.normalize_attrs(attrs),
         {:ok, subject_ref} <- Support.nested_struct(Map.get(attrs, :subject_ref), SubjectRef),
         false <- is_nil(subject_ref),
         lifecycle_state <- Map.get(attrs, :lifecycle_state),
         true <- Support.present_binary?(lifecycle_state),
         {:ok, current_execution_ref} <-
           Support.nested_struct(Map.get(attrs, :current_execution_ref), ExecutionRef),
         {:ok, pending_decision_refs} <-
           Support.nested_structs(Map.get(attrs, :pending_decision_refs, []), DecisionRef),
         {:ok, available_actions} <-
           Support.nested_structs(Map.get(attrs, :available_actions, []), OperatorAction),
         {:ok, timeline} <-
           Support.nested_structs(Map.get(attrs, :timeline, []), TimelineEvent),
         updated_at <- Map.get(attrs, :updated_at),
         true <- Support.optional_datetime?(updated_at),
         payload <- Map.get(attrs, :payload, %{}),
         true <- is_map(payload) do
      {:ok,
       %__MODULE__{
         subject_ref: subject_ref,
         lifecycle_state: lifecycle_state,
         current_execution_ref: current_execution_ref,
         pending_decision_refs: pending_decision_refs,
         available_actions: available_actions,
         timeline: timeline,
         updated_at: updated_at,
         payload: payload
       }}
    else
      _ -> {:error, :invalid_operator_projection}
    end
  end
end
