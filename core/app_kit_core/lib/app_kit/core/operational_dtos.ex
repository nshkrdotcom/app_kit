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

defmodule AppKit.Core.ReadLease do
  @moduledoc """
  Stable northbound leased direct-read envelope.
  """

  alias AppKit.Core.{ReadLeaseRef, Support, TraceIdentity}

  @enforce_keys [:lease_ref, :trace_id, :expires_at, :lease_token]
  defstruct [
    :lease_ref,
    :trace_id,
    :expires_at,
    :lease_token,
    allowed_operations: [],
    authorization_scope: %{},
    scope: %{},
    lineage_anchor: %{},
    invalidation_cursor: 0,
    invalidation_channel: nil
  ]

  @type t :: %__MODULE__{
          lease_ref: ReadLeaseRef.t(),
          trace_id: String.t(),
          expires_at: DateTime.t(),
          lease_token: String.t(),
          allowed_operations: [String.t() | atom()],
          authorization_scope: map(),
          scope: map(),
          lineage_anchor: map(),
          invalidation_cursor: non_neg_integer(),
          invalidation_channel: String.t() | nil
        }

  @spec new(map() | keyword()) :: {:ok, t()} | {:error, :invalid_read_lease}
  def new(attrs) do
    with {:ok, attrs} <- Support.normalize_attrs(attrs),
         {:ok, lease_ref} <- Support.nested_struct(Map.get(attrs, :lease_ref), ReadLeaseRef),
         false <- is_nil(lease_ref),
         {:ok, trace_id} <- TraceIdentity.ensure(Map.get(attrs, :trace_id)),
         expires_at <- Map.get(attrs, :expires_at),
         true <- Support.optional_datetime?(expires_at),
         false <- is_nil(expires_at),
         lease_token <- Map.get(attrs, :lease_token),
         true <- Support.present_binary?(lease_token),
         allowed_operations <- Map.get(attrs, :allowed_operations, []),
         true <- Support.list_of?(allowed_operations, &Support.atom_or_binary?/1),
         authorization_scope <- Map.get(attrs, :authorization_scope, %{}),
         true <- is_map(authorization_scope),
         scope <- Map.get(attrs, :scope, %{}),
         true <- is_map(scope),
         lineage_anchor <- Map.get(attrs, :lineage_anchor, %{}),
         true <- is_map(lineage_anchor),
         invalidation_cursor <- Map.get(attrs, :invalidation_cursor, 0),
         true <- Support.optional_non_neg_integer?(invalidation_cursor),
         invalidation_channel <- Map.get(attrs, :invalidation_channel),
         true <- Support.optional_binary?(invalidation_channel) do
      {:ok,
       %__MODULE__{
         lease_ref: lease_ref,
         trace_id: trace_id,
         expires_at: expires_at,
         lease_token: lease_token,
         allowed_operations: allowed_operations,
         authorization_scope: authorization_scope,
         scope: scope,
         lineage_anchor: lineage_anchor,
         invalidation_cursor: invalidation_cursor,
         invalidation_channel: invalidation_channel
       }}
    else
      _ -> {:error, :invalid_read_lease}
    end
  end
end

defmodule AppKit.Core.StreamAttachLease do
  @moduledoc """
  Stable northbound stream-attach lease envelope.
  """

  alias AppKit.Core.{StreamAttachLeaseRef, Support, TraceIdentity}

  @enforce_keys [:lease_ref, :trace_id, :expires_at, :attach_token]
  defstruct [
    :lease_ref,
    :trace_id,
    :expires_at,
    :attach_token,
    authorization_scope: %{},
    scope: %{},
    lineage_anchor: %{},
    reconnect_cursor: 0,
    invalidation_channel: nil,
    poll_interval_ms: 2_000
  ]

  @type t :: %__MODULE__{
          lease_ref: StreamAttachLeaseRef.t(),
          trace_id: String.t(),
          expires_at: DateTime.t(),
          attach_token: String.t(),
          authorization_scope: map(),
          scope: map(),
          lineage_anchor: map(),
          reconnect_cursor: non_neg_integer(),
          invalidation_channel: String.t() | nil,
          poll_interval_ms: pos_integer()
        }

  @spec new(map() | keyword()) :: {:ok, t()} | {:error, :invalid_stream_attach_lease}
  def new(attrs) do
    with {:ok, attrs} <- Support.normalize_attrs(attrs),
         {:ok, lease_ref} <-
           Support.nested_struct(Map.get(attrs, :lease_ref), StreamAttachLeaseRef),
         false <- is_nil(lease_ref),
         {:ok, trace_id} <- TraceIdentity.ensure(Map.get(attrs, :trace_id)),
         expires_at <- Map.get(attrs, :expires_at),
         true <- Support.optional_datetime?(expires_at),
         false <- is_nil(expires_at),
         attach_token <- Map.get(attrs, :attach_token),
         true <- Support.present_binary?(attach_token),
         authorization_scope <- Map.get(attrs, :authorization_scope, %{}),
         true <- is_map(authorization_scope),
         scope <- Map.get(attrs, :scope, %{}),
         true <- is_map(scope),
         lineage_anchor <- Map.get(attrs, :lineage_anchor, %{}),
         true <- is_map(lineage_anchor),
         reconnect_cursor <- Map.get(attrs, :reconnect_cursor, 0),
         true <- Support.optional_non_neg_integer?(reconnect_cursor),
         invalidation_channel <- Map.get(attrs, :invalidation_channel),
         true <- Support.optional_binary?(invalidation_channel),
         poll_interval_ms <- Map.get(attrs, :poll_interval_ms, 2_000),
         true <- Support.positive_integer?(poll_interval_ms),
         true <- poll_interval_ms <= 2_000 do
      {:ok,
       %__MODULE__{
         lease_ref: lease_ref,
         trace_id: trace_id,
         expires_at: expires_at,
         attach_token: attach_token,
         authorization_scope: authorization_scope,
         scope: scope,
         lineage_anchor: lineage_anchor,
         reconnect_cursor: reconnect_cursor,
         invalidation_channel: invalidation_channel,
         poll_interval_ms: poll_interval_ms
       }}
    else
      _ -> {:error, :invalid_stream_attach_lease}
    end
  end
end

defmodule AppKit.Core.PendingObligation do
  @moduledoc """
  Stable northbound pending-obligation projection.
  """

  alias AppKit.Core.Support

  @enforce_keys [:obligation_id, :obligation_kind, :status]
  defstruct [
    :obligation_id,
    :obligation_kind,
    :status,
    summary: nil,
    decision_ref_id: nil,
    required_by: nil,
    blocking?: false,
    metadata: %{}
  ]

  @type t :: %__MODULE__{
          obligation_id: String.t(),
          obligation_kind: String.t(),
          status: String.t(),
          summary: String.t() | nil,
          decision_ref_id: String.t() | nil,
          required_by: DateTime.t() | nil,
          blocking?: boolean(),
          metadata: map()
        }

  @spec new(map() | keyword()) :: {:ok, t()} | {:error, :invalid_pending_obligation}
  def new(attrs) do
    with {:ok, attrs} <- Support.normalize_attrs(attrs),
         obligation_id <- Map.get(attrs, :obligation_id),
         true <- Support.present_binary?(obligation_id),
         obligation_kind <- Map.get(attrs, :obligation_kind),
         true <- Support.present_binary?(obligation_kind),
         status <- Map.get(attrs, :status),
         true <- Support.present_binary?(status),
         summary <- Map.get(attrs, :summary),
         true <- Support.optional_binary?(summary),
         decision_ref_id <- Map.get(attrs, :decision_ref_id),
         true <- Support.optional_binary?(decision_ref_id),
         required_by <- Map.get(attrs, :required_by),
         true <- Support.optional_datetime?(required_by),
         blocking? <- Map.get(attrs, :blocking?, false),
         true <- is_boolean(blocking?),
         metadata <- Map.get(attrs, :metadata, %{}),
         true <- is_map(metadata) do
      {:ok,
       %__MODULE__{
         obligation_id: obligation_id,
         obligation_kind: obligation_kind,
         status: status,
         summary: summary,
         decision_ref_id: decision_ref_id,
         required_by: required_by,
         blocking?: blocking?,
         metadata: metadata
       }}
    else
      _ -> {:error, :invalid_pending_obligation}
    end
  end
end

defmodule AppKit.Core.BlockingCondition do
  @moduledoc """
  Stable northbound blocking-condition projection.
  """

  alias AppKit.Core.Support

  @enforce_keys [:blocker_kind, :status]
  defstruct [
    :blocker_kind,
    :status,
    summary: nil,
    reason: nil,
    obligation_id: nil,
    decision_ref_id: nil,
    metadata: %{}
  ]

  @type t :: %__MODULE__{
          blocker_kind: String.t(),
          status: String.t(),
          summary: String.t() | nil,
          reason: String.t() | nil,
          obligation_id: String.t() | nil,
          decision_ref_id: String.t() | nil,
          metadata: map()
        }

  @spec new(map() | keyword()) :: {:ok, t()} | {:error, :invalid_blocking_condition}
  def new(attrs) do
    with {:ok, attrs} <- Support.normalize_attrs(attrs),
         blocker_kind <- Map.get(attrs, :blocker_kind),
         true <- Support.present_binary?(blocker_kind),
         status <- Map.get(attrs, :status),
         true <- Support.present_binary?(status),
         summary <- Map.get(attrs, :summary),
         true <- Support.optional_binary?(summary),
         reason <- Map.get(attrs, :reason),
         true <- Support.optional_binary?(reason),
         obligation_id <- Map.get(attrs, :obligation_id),
         true <- Support.optional_binary?(obligation_id),
         decision_ref_id <- Map.get(attrs, :decision_ref_id),
         true <- Support.optional_binary?(decision_ref_id),
         metadata <- Map.get(attrs, :metadata, %{}),
         true <- is_map(metadata) do
      {:ok,
       %__MODULE__{
         blocker_kind: blocker_kind,
         status: status,
         summary: summary,
         reason: reason,
         obligation_id: obligation_id,
         decision_ref_id: decision_ref_id,
         metadata: metadata
       }}
    else
      _ -> {:error, :invalid_blocking_condition}
    end
  end
end

defmodule AppKit.Core.NextStepPreview do
  @moduledoc """
  Stable northbound next-step itinerary projection.
  """

  alias AppKit.Core.Support

  @enforce_keys [:step_kind, :status]
  defstruct [
    :step_kind,
    :status,
    summary: nil,
    blocking_condition_kinds: [],
    obligation_ids: [],
    metadata: %{}
  ]

  @type t :: %__MODULE__{
          step_kind: String.t(),
          status: String.t(),
          summary: String.t() | nil,
          blocking_condition_kinds: [String.t()],
          obligation_ids: [String.t()],
          metadata: map()
        }

  @spec new(map() | keyword()) :: {:ok, t()} | {:error, :invalid_next_step_preview}
  def new(attrs) do
    with {:ok, attrs} <- Support.normalize_attrs(attrs),
         step_kind <- Map.get(attrs, :step_kind),
         true <- Support.present_binary?(step_kind),
         status <- Map.get(attrs, :status),
         true <- Support.present_binary?(status),
         summary <- Map.get(attrs, :summary),
         true <- Support.optional_binary?(summary),
         blocking_condition_kinds <- Map.get(attrs, :blocking_condition_kinds, []),
         true <-
           is_list(blocking_condition_kinds) and
             Enum.all?(blocking_condition_kinds, &Support.present_binary?/1),
         obligation_ids <- Map.get(attrs, :obligation_ids, []),
         true <- is_list(obligation_ids) and Enum.all?(obligation_ids, &Support.present_binary?/1),
         metadata <- Map.get(attrs, :metadata, %{}),
         true <- is_map(metadata) do
      {:ok,
       %__MODULE__{
         step_kind: step_kind,
         status: status,
         summary: summary,
         blocking_condition_kinds: blocking_condition_kinds,
         obligation_ids: obligation_ids,
         metadata: metadata
       }}
    else
      _ -> {:error, :invalid_next_step_preview}
    end
  end
end

defmodule AppKit.Core.OperatorProjection do
  @moduledoc """
  Stable northbound operator-facing projection envelope.
  """

  alias AppKit.Core.{
    BlockingCondition,
    DecisionRef,
    ExecutionRef,
    NextStepPreview,
    OperatorAction,
    PendingObligation,
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
    pending_obligations: [],
    blocking_conditions: [],
    next_step_preview: nil,
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
          pending_obligations: [PendingObligation.t()],
          blocking_conditions: [BlockingCondition.t()],
          next_step_preview: NextStepPreview.t() | nil,
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
         pending_obligations: pending_obligations,
         blocking_conditions: blocking_conditions,
         next_step_preview: next_step_preview,
         timeline: timeline,
         updated_at: updated_at,
         payload: payload
       }}
    else
      _ -> {:error, :invalid_operator_projection}
    end
  end
end

defmodule AppKit.Core.OperatorSurfaceProjection do
  @moduledoc """
  Phase 4 operator-visible projection with explicit staleness semantics.

  This DTO distinguishes local acceptance, signal dispatch, workflow effect
  acknowledgement, stale projections, and failed dispatches without exposing
  Temporal SDK details to AppKit consumers.
  """

  alias AppKit.Core.{ActorRef, InstallationRef, ProjectionRef, Support, TenantRef, TraceIdentity}

  @staleness_classes [
    :queued,
    :dispatching,
    :delivered_to_temporal,
    :pending_workflow_ack,
    :processed,
    :dispatch_failed,
    :stale,
    :lower_fresh,
    :projection_stale,
    :diagnostic_only,
    :authoritative_archived
  ]
  @contract_name "AppKit.OperatorSurfaceProjection.v1"
  @dispatch_states [
    :queued,
    :dispatching,
    :delivered_to_temporal,
    :dispatch_failed,
    :not_applicable
  ]
  @workflow_effect_states [:pending, :processed, :failed, :not_applicable]

  @enforce_keys [
    :projection_ref,
    :tenant_ref,
    :installation_ref,
    :operator_ref,
    :target_ref,
    :authority_packet_ref,
    :permission_decision_ref,
    :idempotency_key,
    :trace_id,
    :correlation_id,
    :release_manifest_ref,
    :projection_version,
    :source_event_position,
    :observed_at,
    :produced_at,
    :staleness_class,
    :dispatch_state,
    :workflow_effect_state
  ]
  defstruct [
    :contract_name,
    :projection_ref,
    :tenant_ref,
    :installation_ref,
    :operator_ref,
    :target_ref,
    :authority_packet_ref,
    :permission_decision_ref,
    :idempotency_key,
    :trace_id,
    :correlation_id,
    :release_manifest_ref,
    :projection_version,
    :source_event_position,
    :observed_at,
    :produced_at,
    :staleness_class,
    :dispatch_state,
    :workflow_effect_state,
    payload: %{}
  ]

  @type t :: %__MODULE__{
          projection_ref: ProjectionRef.t(),
          tenant_ref: TenantRef.t(),
          installation_ref: InstallationRef.t(),
          operator_ref: ActorRef.t(),
          target_ref: map(),
          authority_packet_ref: String.t(),
          permission_decision_ref: String.t(),
          idempotency_key: String.t(),
          trace_id: String.t(),
          correlation_id: String.t(),
          release_manifest_ref: String.t(),
          projection_version: non_neg_integer(),
          source_event_position: non_neg_integer(),
          observed_at: DateTime.t(),
          produced_at: DateTime.t(),
          staleness_class: atom(),
          dispatch_state: atom(),
          workflow_effect_state: atom(),
          payload: map()
        }

  @spec contract_name() :: String.t()
  def contract_name, do: @contract_name

  @spec new(map() | keyword()) :: {:ok, t()} | {:error, :invalid_operator_surface_projection}
  def new(attrs) do
    with {:ok, attrs} <- Support.normalize_attrs(attrs),
         {:ok, projection_ref} <-
           Support.nested_struct(Map.get(attrs, :projection_ref), ProjectionRef),
         false <- is_nil(projection_ref),
         {:ok, tenant_ref} <- Support.nested_struct(Map.get(attrs, :tenant_ref), TenantRef),
         false <- is_nil(tenant_ref),
         {:ok, installation_ref} <-
           Support.nested_struct(Map.get(attrs, :installation_ref), InstallationRef),
         false <- is_nil(installation_ref),
         {:ok, operator_ref} <- Support.nested_struct(Map.get(attrs, :operator_ref), ActorRef),
         false <- is_nil(operator_ref),
         target_ref <- Map.get(attrs, :target_ref),
         true <- scoped_ref?(target_ref),
         authority_packet_ref <- Map.get(attrs, :authority_packet_ref),
         true <- Support.present_binary?(authority_packet_ref),
         permission_decision_ref <- Map.get(attrs, :permission_decision_ref),
         true <- Support.present_binary?(permission_decision_ref),
         idempotency_key <- Map.get(attrs, :idempotency_key),
         true <- Support.present_binary?(idempotency_key),
         {:ok, trace_id} <- TraceIdentity.ensure(Map.get(attrs, :trace_id)),
         correlation_id <- Map.get(attrs, :correlation_id),
         true <- Support.present_binary?(correlation_id),
         release_manifest_ref <- Map.get(attrs, :release_manifest_ref),
         true <- Support.present_binary?(release_manifest_ref),
         projection_version <- Map.get(attrs, :projection_version),
         true <- is_integer(projection_version) and projection_version >= 0,
         source_event_position <- Map.get(attrs, :source_event_position),
         true <- is_integer(source_event_position) and source_event_position >= 0,
         observed_at <- Map.get(attrs, :observed_at),
         true <- required_datetime?(observed_at),
         produced_at <- Map.get(attrs, :produced_at),
         true <- required_datetime?(produced_at),
         {:ok, staleness_class} <-
           normalize_enum(Map.get(attrs, :staleness_class), @staleness_classes),
         {:ok, dispatch_state} <-
           normalize_enum(Map.get(attrs, :dispatch_state), @dispatch_states),
         {:ok, workflow_effect_state} <-
           normalize_enum(Map.get(attrs, :workflow_effect_state), @workflow_effect_states),
         payload <- Map.get(attrs, :payload, %{}),
         true <- is_map(payload) do
      {:ok,
       %__MODULE__{
         contract_name: @contract_name,
         projection_ref: projection_ref,
         tenant_ref: tenant_ref,
         installation_ref: installation_ref,
         operator_ref: operator_ref,
         target_ref: target_ref,
         authority_packet_ref: authority_packet_ref,
         permission_decision_ref: permission_decision_ref,
         idempotency_key: idempotency_key,
         trace_id: trace_id,
         correlation_id: correlation_id,
         release_manifest_ref: release_manifest_ref,
         projection_version: projection_version,
         source_event_position: source_event_position,
         observed_at: observed_at,
         produced_at: produced_at,
         staleness_class: staleness_class,
         dispatch_state: dispatch_state,
         workflow_effect_state: workflow_effect_state,
         payload: payload
       }}
    else
      _ -> {:error, :invalid_operator_surface_projection}
    end
  end

  defp scoped_ref?(%{id: id, kind: kind}),
    do: Support.present_binary?(id) and Support.present_binary?(kind)

  defp scoped_ref?(%{"id" => id, "kind" => kind}),
    do: Support.present_binary?(id) and Support.present_binary?(kind)

  defp scoped_ref?(_value), do: false

  defp required_datetime?(%DateTime{}), do: true
  defp required_datetime?(_value), do: false

  defp normalize_enum(value, allowed) when is_atom(value) do
    if value in allowed do
      {:ok, value}
    else
      :error
    end
  end

  defp normalize_enum(value, allowed) when is_binary(value) do
    normalized = String.to_existing_atom(value)

    if normalized in allowed do
      {:ok, normalized}
    else
      :error
    end
  rescue
    ArgumentError -> :error
  end

  defp normalize_enum(_value, _allowed), do: :error
end

defmodule AppKit.Core.ObserverDescriptor do
  @moduledoc """
  Phase 4 observer descriptor DTO for tenant-safe operator/product projections.

  Observer descriptors expose only redacted, allow-listed projection metadata.
  Raw provider metadata and cross-tenant identifiers must remain blocked.
  """

  alias AppKit.Core.{ActorRef, InstallationRef, ProjectionRef, Support, TenantRef, TraceIdentity}

  @staleness_classes [
    :substrate_authoritative,
    :lower_authoritative_unreconciled,
    :diagnostic_only,
    :projection_stale,
    :authoritative_archived
  ]
  @contract_name "AppKit.ObserverDescriptor.v1"

  @enforce_keys [
    :observer_ref,
    :projection_ref,
    :tenant_ref,
    :installation_ref,
    :principal_ref,
    :resource_ref,
    :authority_packet_ref,
    :permission_decision_ref,
    :idempotency_key,
    :trace_id,
    :correlation_id,
    :release_manifest_ref,
    :staleness_class,
    :redaction_policy_ref,
    :allowed_fields,
    :blocked_fields
  ]
  defstruct [
    :contract_name,
    :observer_ref,
    :projection_ref,
    :tenant_ref,
    :installation_ref,
    :principal_ref,
    :resource_ref,
    :authority_packet_ref,
    :permission_decision_ref,
    :idempotency_key,
    :trace_id,
    :correlation_id,
    :release_manifest_ref,
    :staleness_class,
    :redaction_policy_ref,
    :allowed_fields,
    :blocked_fields,
    metadata: %{}
  ]

  @type t :: %__MODULE__{
          observer_ref: String.t(),
          projection_ref: ProjectionRef.t(),
          tenant_ref: TenantRef.t(),
          installation_ref: InstallationRef.t(),
          principal_ref: ActorRef.t(),
          resource_ref: map(),
          authority_packet_ref: String.t(),
          permission_decision_ref: String.t(),
          idempotency_key: String.t(),
          trace_id: String.t(),
          correlation_id: String.t(),
          release_manifest_ref: String.t(),
          staleness_class: atom(),
          redaction_policy_ref: String.t(),
          allowed_fields: [String.t()],
          blocked_fields: [String.t()],
          metadata: map()
        }

  @spec contract_name() :: String.t()
  def contract_name, do: @contract_name

  @spec new(map() | keyword()) :: {:ok, t()} | {:error, :invalid_observer_descriptor}
  def new(attrs) do
    with {:ok, attrs} <- Support.normalize_attrs(attrs),
         observer_ref <- Map.get(attrs, :observer_ref),
         true <- Support.present_binary?(observer_ref),
         {:ok, projection_ref} <-
           Support.nested_struct(Map.get(attrs, :projection_ref), ProjectionRef),
         false <- is_nil(projection_ref),
         {:ok, tenant_ref} <- Support.nested_struct(Map.get(attrs, :tenant_ref), TenantRef),
         false <- is_nil(tenant_ref),
         {:ok, installation_ref} <-
           Support.nested_struct(Map.get(attrs, :installation_ref), InstallationRef),
         false <- is_nil(installation_ref),
         {:ok, principal_ref} <- Support.nested_struct(Map.get(attrs, :principal_ref), ActorRef),
         false <- is_nil(principal_ref),
         resource_ref <- Map.get(attrs, :resource_ref),
         true <- scoped_ref?(resource_ref),
         authority_packet_ref <- Map.get(attrs, :authority_packet_ref),
         true <- Support.present_binary?(authority_packet_ref),
         permission_decision_ref <- Map.get(attrs, :permission_decision_ref),
         true <- Support.present_binary?(permission_decision_ref),
         idempotency_key <- Map.get(attrs, :idempotency_key),
         true <- Support.present_binary?(idempotency_key),
         {:ok, trace_id} <- TraceIdentity.ensure(Map.get(attrs, :trace_id)),
         correlation_id <- Map.get(attrs, :correlation_id),
         true <- Support.present_binary?(correlation_id),
         release_manifest_ref <- Map.get(attrs, :release_manifest_ref),
         true <- Support.present_binary?(release_manifest_ref),
         {:ok, staleness_class} <-
           normalize_enum(Map.get(attrs, :staleness_class), @staleness_classes),
         redaction_policy_ref <- Map.get(attrs, :redaction_policy_ref),
         true <- Support.present_binary?(redaction_policy_ref),
         allowed_fields <- Map.get(attrs, :allowed_fields),
         true <- non_empty_string_list?(allowed_fields),
         blocked_fields <- Map.get(attrs, :blocked_fields),
         true <- non_empty_string_list?(blocked_fields),
         metadata <- Map.get(attrs, :metadata, %{}),
         true <- is_map(metadata) do
      {:ok,
       %__MODULE__{
         contract_name: @contract_name,
         observer_ref: observer_ref,
         projection_ref: projection_ref,
         tenant_ref: tenant_ref,
         installation_ref: installation_ref,
         principal_ref: principal_ref,
         resource_ref: resource_ref,
         authority_packet_ref: authority_packet_ref,
         permission_decision_ref: permission_decision_ref,
         idempotency_key: idempotency_key,
         trace_id: trace_id,
         correlation_id: correlation_id,
         release_manifest_ref: release_manifest_ref,
         staleness_class: staleness_class,
         redaction_policy_ref: redaction_policy_ref,
         allowed_fields: allowed_fields,
         blocked_fields: blocked_fields,
         metadata: metadata
       }}
    else
      _ -> {:error, :invalid_observer_descriptor}
    end
  end

  defp scoped_ref?(%{id: id, kind: kind}),
    do: Support.present_binary?(id) and Support.present_binary?(kind)

  defp scoped_ref?(%{"id" => id, "kind" => kind}),
    do: Support.present_binary?(id) and Support.present_binary?(kind)

  defp scoped_ref?(_value), do: false

  defp non_empty_string_list?([_ | _] = values),
    do: Enum.all?(values, &Support.present_binary?/1)

  defp non_empty_string_list?(_values), do: false

  defp normalize_enum(value, allowed) when is_atom(value) do
    if value in allowed do
      {:ok, value}
    else
      :error
    end
  end

  defp normalize_enum(value, allowed) when is_binary(value) do
    normalized = String.to_existing_atom(value)

    if normalized in allowed do
      {:ok, normalized}
    else
      :error
    end
  rescue
    ArgumentError -> :error
  end

  defp normalize_enum(_value, _allowed), do: :error
end
