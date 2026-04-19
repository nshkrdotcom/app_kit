defmodule AppKit.Core.RevisionEpochSupport do
  @moduledoc false

  @base_binary_fields [
    :tenant_ref,
    :installation_ref,
    :workspace_ref,
    :project_ref,
    :environment_ref,
    :resource_ref,
    :authority_packet_ref,
    :permission_decision_ref,
    :idempotency_key,
    :trace_id,
    :correlation_id,
    :release_manifest_ref
  ]

  @optional_actor_fields [:principal_ref, :system_actor_ref]

  def base_binary_fields, do: @base_binary_fields
  def optional_actor_fields, do: @optional_actor_fields

  def normalize_attrs(attrs) when is_list(attrs), do: {:ok, Map.new(attrs)}

  def normalize_attrs(attrs) when is_map(attrs) do
    if Map.has_key?(attrs, :__struct__) do
      {:ok, Map.from_struct(attrs)}
    else
      {:ok, attrs}
    end
  end

  def normalize_attrs(_attrs), do: {:error, :invalid_attrs}

  def present_binary?(value), do: is_binary(value) and byte_size(String.trim(value)) > 0
  def optional_binary?(nil), do: true
  def optional_binary?(value), do: present_binary?(value)
  def non_neg_integer?(value), do: is_integer(value) and value >= 0

  def missing_required_fields(attrs, required_binary, required_non_neg_integers) do
    binary_missing =
      required_binary
      |> Enum.reject(fn field -> present_binary?(Map.get(attrs, field)) end)

    integer_missing =
      required_non_neg_integers
      |> Enum.reject(fn field -> non_neg_integer?(Map.get(attrs, field)) end)

    actor_missing =
      if present_binary?(Map.get(attrs, :principal_ref)) or
           present_binary?(Map.get(attrs, :system_actor_ref)) do
        []
      else
        [:principal_ref_or_system_actor_ref]
      end

    binary_missing ++ actor_missing ++ integer_missing
  end

  def optional_binary_fields?(attrs, fields) do
    Enum.all?(fields, fn field -> optional_binary?(Map.get(attrs, field)) end)
  end

  def enum_string(value, allowed) when is_atom(value),
    do: enum_string(Atom.to_string(value), allowed)

  def enum_string(value, allowed) when is_binary(value) do
    if value in allowed, do: {:ok, value}, else: :error
  end

  def enum_string(_value, _allowed), do: :error

  def required_non_empty_map(attrs, field) do
    case Map.get(attrs, field) do
      value when is_map(value) and map_size(value) > 0 -> {:ok, value}
      _other -> :error
    end
  end

  def required_datetime_or_string(attrs, field) do
    case Map.get(attrs, field) do
      %DateTime{} = datetime ->
        {:ok, datetime}

      value when is_binary(value) ->
        if present_binary?(value), do: {:ok, value}, else: :error

      _other ->
        :error
    end
  end
end

defmodule AppKit.Core.InstallationRevisionEpochFence do
  @moduledoc """
  Northbound AppKit DTO for platform revision and activation-epoch fencing.

  Contract: `AppKit.InstallationRevisionEpochFence.v1`.
  """

  alias AppKit.Core.RevisionEpochSupport

  @contract_name "AppKit.InstallationRevisionEpochFence.v1"
  @fence_statuses ["accepted", "rejected"]
  @required_binary_fields RevisionEpochSupport.base_binary_fields() ++
                            [
                              :node_id,
                              :fence_decision_ref,
                              :stale_reason
                            ]
  @required_non_neg_integer_fields [
    :installation_revision,
    :activation_epoch,
    :lease_epoch
  ]
  @optional_binary_fields RevisionEpochSupport.optional_actor_fields() ++
                            [
                              :mixed_revision_node_ref,
                              :rollout_window_ref
                            ]

  defstruct [
    :contract_name,
    :tenant_ref,
    :installation_ref,
    :workspace_ref,
    :project_ref,
    :environment_ref,
    :principal_ref,
    :system_actor_ref,
    :resource_ref,
    :authority_packet_ref,
    :permission_decision_ref,
    :idempotency_key,
    :trace_id,
    :correlation_id,
    :release_manifest_ref,
    :installation_revision,
    :activation_epoch,
    :lease_epoch,
    :node_id,
    :fence_decision_ref,
    :fence_status,
    :stale_reason,
    :attempted_installation_revision,
    :attempted_activation_epoch,
    :attempted_lease_epoch,
    :mixed_revision_node_ref,
    :rollout_window_ref
  ]

  @type t :: %__MODULE__{}

  @spec new(map() | keyword()) ::
          {:ok, t()}
          | {:error, {:missing_required_fields, [atom()]}}
          | {:error, :invalid_installation_revision_epoch_fence}
  def new(attrs) do
    with {:ok, attrs} <- RevisionEpochSupport.normalize_attrs(attrs),
         [] <-
           RevisionEpochSupport.missing_required_fields(
             attrs,
             @required_binary_fields,
             @required_non_neg_integer_fields
           ),
         true <- RevisionEpochSupport.optional_binary_fields?(attrs, @optional_binary_fields),
         true <- optional_non_neg_integer?(attrs, :attempted_installation_revision),
         true <- optional_non_neg_integer?(attrs, :attempted_activation_epoch),
         true <- optional_non_neg_integer?(attrs, :attempted_lease_epoch),
         {:ok, fence_status} <-
           RevisionEpochSupport.enum_string(Map.get(attrs, :fence_status), @fence_statuses),
         :ok <- validate_fence_semantics(attrs, fence_status) do
      {:ok, build(attrs, fence_status)}
    else
      fields when is_list(fields) -> {:error, {:missing_required_fields, fields}}
      _error -> {:error, :invalid_installation_revision_epoch_fence}
    end
  end

  defp build(attrs, fence_status) do
    %__MODULE__{
      contract_name: @contract_name,
      tenant_ref: Map.fetch!(attrs, :tenant_ref),
      installation_ref: Map.fetch!(attrs, :installation_ref),
      workspace_ref: Map.fetch!(attrs, :workspace_ref),
      project_ref: Map.fetch!(attrs, :project_ref),
      environment_ref: Map.fetch!(attrs, :environment_ref),
      principal_ref: Map.get(attrs, :principal_ref),
      system_actor_ref: Map.get(attrs, :system_actor_ref),
      resource_ref: Map.fetch!(attrs, :resource_ref),
      authority_packet_ref: Map.fetch!(attrs, :authority_packet_ref),
      permission_decision_ref: Map.fetch!(attrs, :permission_decision_ref),
      idempotency_key: Map.fetch!(attrs, :idempotency_key),
      trace_id: Map.fetch!(attrs, :trace_id),
      correlation_id: Map.fetch!(attrs, :correlation_id),
      release_manifest_ref: Map.fetch!(attrs, :release_manifest_ref),
      installation_revision: Map.fetch!(attrs, :installation_revision),
      activation_epoch: Map.fetch!(attrs, :activation_epoch),
      lease_epoch: Map.fetch!(attrs, :lease_epoch),
      node_id: Map.fetch!(attrs, :node_id),
      fence_decision_ref: Map.fetch!(attrs, :fence_decision_ref),
      fence_status: fence_status,
      stale_reason: Map.fetch!(attrs, :stale_reason),
      attempted_installation_revision: Map.get(attrs, :attempted_installation_revision),
      attempted_activation_epoch: Map.get(attrs, :attempted_activation_epoch),
      attempted_lease_epoch: Map.get(attrs, :attempted_lease_epoch),
      mixed_revision_node_ref: Map.get(attrs, :mixed_revision_node_ref),
      rollout_window_ref: Map.get(attrs, :rollout_window_ref)
    }
  end

  defp validate_fence_semantics(attrs, "accepted") do
    if Map.fetch!(attrs, :stale_reason) == "none" and not attempted_drift?(attrs) do
      :ok
    else
      :error
    end
  end

  defp validate_fence_semantics(attrs, "rejected") do
    if Map.fetch!(attrs, :stale_reason) != "none" and stale_attempt?(attrs) do
      :ok
    else
      :error
    end
  end

  defp attempted_drift?(attrs) do
    Enum.any?(
      [
        {:attempted_installation_revision, :installation_revision},
        {:attempted_activation_epoch, :activation_epoch},
        {:attempted_lease_epoch, :lease_epoch}
      ],
      fn {attempted_key, current_key} ->
        attempted = Map.get(attrs, attempted_key)
        is_integer(attempted) and attempted != Map.fetch!(attrs, current_key)
      end
    )
  end

  defp stale_attempt?(attrs) do
    Enum.any?(
      [
        {:attempted_installation_revision, :installation_revision},
        {:attempted_activation_epoch, :activation_epoch},
        {:attempted_lease_epoch, :lease_epoch}
      ],
      fn {attempted_key, current_key} ->
        attempted = Map.get(attrs, attempted_key)
        is_integer(attempted) and attempted < Map.fetch!(attrs, current_key)
      end
    )
  end

  defp optional_non_neg_integer?(attrs, field),
    do:
      RevisionEpochSupport.non_neg_integer?(Map.get(attrs, field, 0)) or
        is_nil(Map.get(attrs, field))
end

defmodule AppKit.Core.LeaseRevocationEvidence do
  @moduledoc """
  Northbound AppKit DTO for lease revocation propagation evidence.

  Contract: `AppKit.LeaseRevocationEvidence.v1`.
  """

  alias AppKit.Core.RevisionEpochSupport

  @contract_name "AppKit.LeaseRevocationEvidence.v1"
  @lease_statuses ["revoked", "rejected_after_revocation"]
  @required_binary_fields RevisionEpochSupport.base_binary_fields() ++
                            [
                              :lease_ref,
                              :revocation_ref,
                              :cache_invalidation_ref,
                              :post_revocation_attempt_ref
                            ]
  @optional_binary_fields RevisionEpochSupport.optional_actor_fields()

  defstruct [
    :contract_name,
    :tenant_ref,
    :installation_ref,
    :workspace_ref,
    :project_ref,
    :environment_ref,
    :principal_ref,
    :system_actor_ref,
    :resource_ref,
    :authority_packet_ref,
    :permission_decision_ref,
    :idempotency_key,
    :trace_id,
    :correlation_id,
    :release_manifest_ref,
    :lease_ref,
    :revocation_ref,
    :revoked_at,
    :lease_scope,
    :cache_invalidation_ref,
    :post_revocation_attempt_ref,
    :lease_status
  ]

  @type t :: %__MODULE__{}

  @spec new(map() | keyword()) ::
          {:ok, t()}
          | {:error, {:missing_required_fields, [atom()]}}
          | {:error, :invalid_lease_revocation_evidence}
  def new(attrs) do
    with {:ok, attrs} <- RevisionEpochSupport.normalize_attrs(attrs),
         [] <-
           RevisionEpochSupport.missing_required_fields(
             attrs,
             @required_binary_fields,
             []
           ),
         true <- RevisionEpochSupport.optional_binary_fields?(attrs, @optional_binary_fields),
         {:ok, revoked_at} <- RevisionEpochSupport.required_datetime_or_string(attrs, :revoked_at),
         {:ok, lease_scope} <- RevisionEpochSupport.required_non_empty_map(attrs, :lease_scope),
         {:ok, lease_status} <-
           RevisionEpochSupport.enum_string(
             Map.get(attrs, :lease_status, "revoked"),
             @lease_statuses
           ) do
      {:ok, build(attrs, revoked_at, lease_scope, lease_status)}
    else
      fields when is_list(fields) -> {:error, {:missing_required_fields, fields}}
      _error -> {:error, :invalid_lease_revocation_evidence}
    end
  end

  defp build(attrs, revoked_at, lease_scope, lease_status) do
    %__MODULE__{
      contract_name: @contract_name,
      tenant_ref: Map.fetch!(attrs, :tenant_ref),
      installation_ref: Map.fetch!(attrs, :installation_ref),
      workspace_ref: Map.fetch!(attrs, :workspace_ref),
      project_ref: Map.fetch!(attrs, :project_ref),
      environment_ref: Map.fetch!(attrs, :environment_ref),
      principal_ref: Map.get(attrs, :principal_ref),
      system_actor_ref: Map.get(attrs, :system_actor_ref),
      resource_ref: Map.fetch!(attrs, :resource_ref),
      authority_packet_ref: Map.fetch!(attrs, :authority_packet_ref),
      permission_decision_ref: Map.fetch!(attrs, :permission_decision_ref),
      idempotency_key: Map.fetch!(attrs, :idempotency_key),
      trace_id: Map.fetch!(attrs, :trace_id),
      correlation_id: Map.fetch!(attrs, :correlation_id),
      release_manifest_ref: Map.fetch!(attrs, :release_manifest_ref),
      lease_ref: Map.fetch!(attrs, :lease_ref),
      revocation_ref: Map.fetch!(attrs, :revocation_ref),
      revoked_at: revoked_at,
      lease_scope: lease_scope,
      cache_invalidation_ref: Map.fetch!(attrs, :cache_invalidation_ref),
      post_revocation_attempt_ref: Map.fetch!(attrs, :post_revocation_attempt_ref),
      lease_status: lease_status
    }
  end
end
