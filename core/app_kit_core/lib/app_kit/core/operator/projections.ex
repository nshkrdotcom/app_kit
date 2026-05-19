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
    case Enum.find(allowed, &(Atom.to_string(&1) == value)) do
      nil -> :error
      normalized -> {:ok, normalized}
    end
  end

  defp normalize_enum(_value, _allowed), do: :error
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
