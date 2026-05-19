defmodule AppKit.Core.OperatorSignalResult do
  @moduledoc """
  Public-safe result DTO for operator workflow signals.

  This is the AppKit BFF shape for cancel, pause, resume, retry, and replan
  actions. It reports local acceptance, outbox delivery, workflow effect, and
  projection freshness without exposing Temporal query results or SDK structs.
  """

  alias AppKit.Core.{ActorRef, InstallationRef, Support, TenantRef, TraceIdentity}

  @authority_states [:authorized, :denied]
  @local_states [:accepted, :duplicate, :rejected]
  @dispatch_states [
    :queued,
    :dispatching,
    :delivered_to_temporal,
    :dispatch_failed_retryable,
    :dispatch_failed_terminal,
    :not_dispatched
  ]
  @workflow_effect_states [
    :pending,
    :accepted_by_workflow,
    :processed_by_workflow,
    :rejected_by_workflow,
    :timed_out_or_stale,
    :rejected_by_authority
  ]
  @projection_states [:fresh, :lagging, :stale, :unknown]
  @contract_name "AppKit.OperatorSignalResult.v1"

  @enforce_keys [
    :command_id,
    :signal_id,
    :workflow_ref,
    :tenant_ref,
    :installation_ref,
    :operator_ref,
    :resource_ref,
    :authority_packet_ref,
    :permission_decision_ref,
    :idempotency_key,
    :trace_id,
    :correlation_id,
    :release_manifest_version,
    :authority_state,
    :local_state,
    :dispatch_state,
    :workflow_effect_state,
    :projection_state,
    :operator_message
  ]
  defstruct [
    :contract_name,
    :command_id,
    :signal_id,
    :workflow_ref,
    :tenant_ref,
    :installation_ref,
    :operator_ref,
    :resource_ref,
    :authority_packet_ref,
    :permission_decision_ref,
    :idempotency_key,
    :trace_id,
    :correlation_id,
    :release_manifest_version,
    :authority_state,
    :local_state,
    :dispatch_state,
    :workflow_effect_state,
    :projection_state,
    :operator_message,
    :retry_after_ms,
    :staleness_started_at,
    :last_projection_event_ref,
    :incident_bundle_ref
  ]

  @type t :: %__MODULE__{
          command_id: String.t(),
          signal_id: String.t(),
          workflow_ref: String.t(),
          tenant_ref: TenantRef.t(),
          installation_ref: InstallationRef.t(),
          operator_ref: ActorRef.t(),
          resource_ref: map(),
          authority_packet_ref: String.t(),
          permission_decision_ref: String.t(),
          idempotency_key: String.t(),
          trace_id: String.t(),
          correlation_id: String.t(),
          release_manifest_version: String.t(),
          authority_state: atom(),
          local_state: atom(),
          dispatch_state: atom(),
          workflow_effect_state: atom(),
          projection_state: atom(),
          operator_message: String.t(),
          retry_after_ms: non_neg_integer() | nil,
          staleness_started_at: DateTime.t() | nil,
          last_projection_event_ref: String.t() | nil,
          incident_bundle_ref: String.t() | nil
        }

  @spec contract_name() :: String.t()
  def contract_name, do: @contract_name

  @spec new(map() | keyword()) :: {:ok, t()} | {:error, :invalid_operator_signal_result}
  def new(attrs) do
    with {:ok, attrs} <- Support.normalize_attrs(attrs),
         command_id <- Map.get(attrs, :command_id),
         true <- Support.present_binary?(command_id),
         signal_id <- Map.get(attrs, :signal_id),
         true <- Support.present_binary?(signal_id),
         workflow_ref <- Map.get(attrs, :workflow_ref),
         true <- Support.present_binary?(workflow_ref),
         {:ok, tenant_ref} <- Support.nested_struct(Map.get(attrs, :tenant_ref), TenantRef),
         false <- is_nil(tenant_ref),
         {:ok, installation_ref} <-
           Support.nested_struct(Map.get(attrs, :installation_ref), InstallationRef),
         false <- is_nil(installation_ref),
         {:ok, operator_ref} <- Support.nested_struct(Map.get(attrs, :operator_ref), ActorRef),
         false <- is_nil(operator_ref),
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
         release_manifest_version <- Map.get(attrs, :release_manifest_version),
         true <- Support.present_binary?(release_manifest_version),
         {:ok, authority_state} <-
           normalize_enum(Map.get(attrs, :authority_state), @authority_states),
         {:ok, local_state} <- normalize_enum(Map.get(attrs, :local_state), @local_states),
         {:ok, dispatch_state} <-
           normalize_enum(Map.get(attrs, :dispatch_state), @dispatch_states),
         {:ok, workflow_effect_state} <-
           normalize_enum(Map.get(attrs, :workflow_effect_state), @workflow_effect_states),
         {:ok, projection_state} <-
           normalize_enum(Map.get(attrs, :projection_state), @projection_states),
         operator_message <- Map.get(attrs, :operator_message),
         true <- Support.present_binary?(operator_message),
         retry_after_ms <- Map.get(attrs, :retry_after_ms),
         true <- Support.optional_non_neg_integer?(retry_after_ms),
         staleness_started_at <- Map.get(attrs, :staleness_started_at),
         true <- Support.optional_datetime?(staleness_started_at),
         last_projection_event_ref <- Map.get(attrs, :last_projection_event_ref),
         true <- Support.optional_binary?(last_projection_event_ref),
         incident_bundle_ref <- Map.get(attrs, :incident_bundle_ref),
         true <- Support.optional_binary?(incident_bundle_ref) do
      {:ok,
       %__MODULE__{
         contract_name: @contract_name,
         command_id: command_id,
         signal_id: signal_id,
         workflow_ref: workflow_ref,
         tenant_ref: tenant_ref,
         installation_ref: installation_ref,
         operator_ref: operator_ref,
         resource_ref: resource_ref,
         authority_packet_ref: authority_packet_ref,
         permission_decision_ref: permission_decision_ref,
         idempotency_key: idempotency_key,
         trace_id: trace_id,
         correlation_id: correlation_id,
         release_manifest_version: release_manifest_version,
         authority_state: authority_state,
         local_state: local_state,
         dispatch_state: dispatch_state,
         workflow_effect_state: workflow_effect_state,
         projection_state: projection_state,
         operator_message: operator_message,
         retry_after_ms: retry_after_ms,
         staleness_started_at: staleness_started_at,
         last_projection_event_ref: last_projection_event_ref,
         incident_bundle_ref: incident_bundle_ref
       }}
    else
      _ -> {:error, :invalid_operator_signal_result}
    end
  end

  defp scoped_ref?(%{id: id, kind: kind}),
    do: Support.present_binary?(id) and Support.present_binary?(kind)

  defp scoped_ref?(%{"id" => id, "kind" => kind}),
    do: Support.present_binary?(id) and Support.present_binary?(kind)

  defp scoped_ref?(_value), do: false

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
