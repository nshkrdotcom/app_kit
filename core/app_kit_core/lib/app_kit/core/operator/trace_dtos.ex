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

defmodule AppKit.Core.UnifiedTrace do
  @moduledoc """
  Stable northbound unified-trace envelope.
  """

  alias AppKit.Core.{InstallationRef, Support, TraceIdentity, UnifiedTraceStep}

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
         {:ok, trace_id} <- TraceIdentity.ensure(Map.get(attrs, :trace_id)),
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

defmodule AppKit.Core.UnifiedTraceStep do
  @moduledoc """
  Stable northbound unified-trace step.
  """

  alias AppKit.Core.{Support, TraceIdentity}

  @enforce_keys [:ref, :source]
  defstruct [
    :ref,
    :source,
    occurred_at: nil,
    trace_id: nil,
    causation_id: nil,
    staleness_class: nil,
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
          staleness_class: String.t() | nil,
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
         {:ok, trace_id} <- TraceIdentity.ensure_optional(Map.get(attrs, :trace_id)),
         causation_id <- Map.get(attrs, :causation_id),
         true <- Support.optional_binary?(causation_id),
         staleness_class <- Map.get(attrs, :staleness_class),
         true <- Support.optional_binary?(staleness_class),
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
         staleness_class: staleness_class,
         operator_actionable?: operator_actionable?,
         diagnostic?: diagnostic?,
         payload: payload
       }}
    else
      _ -> {:error, :invalid_unified_trace_step}
    end
  end
end
