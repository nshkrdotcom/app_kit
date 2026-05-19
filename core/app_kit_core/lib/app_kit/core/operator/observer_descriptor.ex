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
    case Enum.find(allowed, &(Atom.to_string(&1) == value)) do
      nil -> :error
      normalized -> {:ok, normalized}
    end
  end

  defp normalize_enum(_value, _allowed), do: :error
end
