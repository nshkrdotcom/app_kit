defmodule AppKit.Core.EvidenceAuditSupport do
  @moduledoc false

  alias AppKit.Core.ArchivalRestoreSupport
  alias AppKit.Core.RevisionEpochSupport

  @spec base_binary_fields() :: [atom()]
  def base_binary_fields, do: RevisionEpochSupport.base_binary_fields()

  @spec optional_actor_fields() :: [atom()]
  def optional_actor_fields, do: RevisionEpochSupport.optional_actor_fields()

  @spec normalize_attrs(map() | keyword() | struct()) :: {:ok, map()} | {:error, :invalid_attrs}
  def normalize_attrs(attrs), do: RevisionEpochSupport.normalize_attrs(attrs)

  @spec missing_required_fields(map(), [atom()], [atom()]) :: [atom()]
  def missing_required_fields(attrs, required_binary, required_non_neg_integer),
    do:
      RevisionEpochSupport.missing_required_fields(
        attrs,
        required_binary,
        required_non_neg_integer
      )

  @spec optional_binary_fields?(map(), [atom()]) :: boolean()
  def optional_binary_fields?(attrs, fields),
    do: RevisionEpochSupport.optional_binary_fields?(attrs, fields)

  @spec present_binary?(term()) :: boolean()
  def present_binary?(value), do: RevisionEpochSupport.present_binary?(value)

  @spec sha256?(term()) :: boolean()
  def sha256?(value), do: ArchivalRestoreSupport.sha256?(value)

  @spec previous_hash?(term()) :: boolean()
  def previous_hash?("genesis"), do: true
  def previous_hash?(value), do: sha256?(value)
end

defmodule AppKit.Core.AuditHashChainProjection do
  @moduledoc """
  Northbound operator DTO for Citadel audit hash-chain evidence.

  Contract: `AppKit.AuditHashChainProjection.v1`.
  """

  alias AppKit.Core.EvidenceAuditSupport

  @contract_name "AppKit.AuditHashChainProjection.v1"
  @source_contract_name "Platform.AuditHashChain.v1"
  @required_binary_fields EvidenceAuditSupport.base_binary_fields() ++
                            [
                              :audit_ref,
                              :previous_hash,
                              :event_hash,
                              :chain_head_hash,
                              :writer_ref,
                              :immutability_proof_ref,
                              :source_contract_name
                            ]
  @optional_binary_fields EvidenceAuditSupport.optional_actor_fields()

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
    :audit_ref,
    :previous_hash,
    :event_hash,
    :chain_head_hash,
    :writer_ref,
    :immutability_proof_ref,
    :source_contract_name
  ]

  @type t :: %__MODULE__{}

  @spec contract_name() :: String.t()
  def contract_name, do: @contract_name

  @spec new(map() | keyword()) ::
          {:ok, t()}
          | {:error, {:missing_required_fields, [atom()]}}
          | {:error, :invalid_audit_hash_chain_projection}
  def new(attrs) do
    with {:ok, attrs} <- EvidenceAuditSupport.normalize_attrs(attrs),
         [] <- EvidenceAuditSupport.missing_required_fields(attrs, @required_binary_fields, []),
         true <- EvidenceAuditSupport.optional_binary_fields?(attrs, @optional_binary_fields),
         true <- EvidenceAuditSupport.previous_hash?(Map.get(attrs, :previous_hash)),
         true <- EvidenceAuditSupport.sha256?(Map.get(attrs, :event_hash)),
         true <- EvidenceAuditSupport.sha256?(Map.get(attrs, :chain_head_hash)),
         true <- Map.fetch!(attrs, :source_contract_name) == @source_contract_name do
      {:ok, struct!(__MODULE__, Map.put(attrs, :contract_name, @contract_name))}
    else
      fields when is_list(fields) -> {:error, {:missing_required_fields, fields}}
      _error -> {:error, :invalid_audit_hash_chain_projection}
    end
  end
end

defmodule AppKit.Core.SuppressionVisibilityProjection do
  @moduledoc """
  Northbound operator DTO for visible suppression and quarantine records.

  Contract: `AppKit.SuppressionVisibilityProjection.v1`.
  """

  alias AppKit.Core.EvidenceAuditSupport

  @contract_name "AppKit.SuppressionVisibilityProjection.v1"
  @source_contract_name "Platform.SuppressionVisibility.v1"
  @required_binary_fields EvidenceAuditSupport.base_binary_fields() ++
                            [
                              :suppression_ref,
                              :suppression_kind,
                              :reason_code,
                              :target_ref,
                              :operator_visibility,
                              :diagnostics_ref,
                              :source_contract_name
                            ]
  @optional_binary_fields EvidenceAuditSupport.optional_actor_fields()

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
    :suppression_ref,
    :suppression_kind,
    :reason_code,
    :target_ref,
    :operator_visibility,
    :recovery_action_refs,
    :diagnostics_ref,
    :source_contract_name
  ]

  @type t :: %__MODULE__{}

  @spec contract_name() :: String.t()
  def contract_name, do: @contract_name

  @spec new(map() | keyword()) ::
          {:ok, t()}
          | {:error, {:missing_required_fields, [atom()]}}
          | {:error, :invalid_suppression_visibility_projection}
  def new(attrs) do
    with {:ok, attrs} <- EvidenceAuditSupport.normalize_attrs(attrs),
         [] <- missing_required_fields(attrs),
         true <- EvidenceAuditSupport.optional_binary_fields?(attrs, @optional_binary_fields),
         true <- Map.fetch!(attrs, :operator_visibility) == "visible",
         true <- Map.fetch!(attrs, :source_contract_name) == @source_contract_name do
      {:ok, struct!(__MODULE__, Map.put(attrs, :contract_name, @contract_name))}
    else
      fields when is_list(fields) -> {:error, {:missing_required_fields, fields}}
      _error -> {:error, :invalid_suppression_visibility_projection}
    end
  end

  defp missing_required_fields(attrs) do
    EvidenceAuditSupport.missing_required_fields(attrs, @required_binary_fields, []) ++
      recovery_action_missing(attrs)
  end

  defp recovery_action_missing(attrs) do
    case Map.get(attrs, :recovery_action_refs) do
      refs when is_list(refs) ->
        if refs != [] and Enum.all?(refs, &EvidenceAuditSupport.present_binary?/1) do
          []
        else
          [:recovery_action_refs]
        end

      _other ->
        [:recovery_action_refs]
    end
  end
end
