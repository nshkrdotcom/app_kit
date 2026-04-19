defmodule AppKit.Core.ArchivalRestoreSupport do
  @moduledoc false

  alias AppKit.Core.RevisionEpochSupport

  @sha256_regex ~r/\Asha256:[0-9a-f]{64}\z/

  @spec base_binary_fields() :: [atom()]
  def base_binary_fields, do: RevisionEpochSupport.base_binary_fields()

  @spec optional_actor_fields() :: [atom()]
  def optional_actor_fields, do: RevisionEpochSupport.optional_actor_fields()

  @spec normalize_attrs(map() | keyword() | struct()) :: {:ok, map()} | {:error, :invalid_attrs}
  def normalize_attrs(attrs), do: RevisionEpochSupport.normalize_attrs(attrs)

  @spec missing_required_fields(map(), [atom()], [atom()]) :: [atom()]
  def missing_required_fields(attrs, required_binary, required_non_neg_integer) do
    RevisionEpochSupport.missing_required_fields(attrs, required_binary, required_non_neg_integer)
  end

  @spec optional_binary_fields?(map(), [atom()]) :: boolean()
  def optional_binary_fields?(attrs, fields),
    do: RevisionEpochSupport.optional_binary_fields?(attrs, fields)

  @spec enum_string(term(), [String.t()]) :: {:ok, String.t()} | :error
  def enum_string(value, allowed), do: RevisionEpochSupport.enum_string(value, allowed)

  @spec present_binary?(term()) :: boolean()
  def present_binary?(value), do: RevisionEpochSupport.present_binary?(value)

  @spec non_neg_integer?(term()) :: boolean()
  def non_neg_integer?(value), do: RevisionEpochSupport.non_neg_integer?(value)

  @spec sha256?(term()) :: boolean()
  def sha256?(value), do: is_binary(value) and Regex.match?(@sha256_regex, value)
end

defmodule AppKit.Core.ColdRestoreTraceProjection do
  @moduledoc """
  Northbound DTO for archived trace restore evidence.

  Contract: `AppKit.ColdRestoreTraceProjection.v1`.
  """

  alias AppKit.Core.ArchivalRestoreSupport

  @contract_name "AppKit.ColdRestoreTraceProjection.v1"
  @source_contract_name "Mezzanine.ColdRestoreTraceQuery.v1"
  @required_binary_fields ArchivalRestoreSupport.base_binary_fields() ++
                            [
                              :restore_request_ref,
                              :archive_partition_ref,
                              :hot_index_ref,
                              :cold_object_ref,
                              :restore_consistency_hash,
                              :source_contract_name
                            ]
  @optional_binary_fields ArchivalRestoreSupport.optional_actor_fields() ++
                            [:retention_policy_ref, :cold_storage_uri_ref]

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
    :restore_request_ref,
    :archive_partition_ref,
    :hot_index_ref,
    :cold_object_ref,
    :restore_consistency_hash,
    :source_contract_name,
    :retention_policy_ref,
    :cold_storage_uri_ref
  ]

  @type t :: %__MODULE__{}

  @spec contract_name() :: String.t()
  def contract_name, do: @contract_name

  @spec new(map() | keyword()) ::
          {:ok, t()}
          | {:error, {:missing_required_fields, [atom()]}}
          | {:error, :invalid_cold_restore_trace_projection}
  def new(attrs) do
    with {:ok, attrs} <- ArchivalRestoreSupport.normalize_attrs(attrs),
         [] <- ArchivalRestoreSupport.missing_required_fields(attrs, @required_binary_fields, []),
         true <- ArchivalRestoreSupport.optional_binary_fields?(attrs, @optional_binary_fields),
         true <- ArchivalRestoreSupport.sha256?(Map.get(attrs, :restore_consistency_hash)),
         true <- Map.fetch!(attrs, :source_contract_name) == @source_contract_name do
      {:ok, struct!(__MODULE__, Map.put(attrs, :contract_name, @contract_name))}
    else
      fields when is_list(fields) -> {:error, {:missing_required_fields, fields}}
      _error -> {:error, :invalid_cold_restore_trace_projection}
    end
  end
end

defmodule AppKit.Core.ColdRestoreArtifactProjection do
  @moduledoc """
  Northbound DTO for archived artifact restore and lineage evidence.

  Contract: `AppKit.ColdRestoreArtifactProjection.v1`.
  """

  alias AppKit.Core.ArchivalRestoreSupport

  @contract_name "AppKit.ColdRestoreArtifactProjection.v1"
  @source_contract_name "Mezzanine.ColdRestoreArtifactQuery.v1"
  @required_binary_fields ArchivalRestoreSupport.base_binary_fields() ++
                            [
                              :artifact_id,
                              :artifact_kind,
                              :artifact_hash,
                              :lineage_ref,
                              :archive_object_ref,
                              :restore_validation_ref,
                              :source_contract_name
                            ]
  @optional_binary_fields ArchivalRestoreSupport.optional_actor_fields() ++
                            [:retention_policy_ref, :cold_storage_uri_ref]

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
    :artifact_id,
    :artifact_kind,
    :artifact_hash,
    :lineage_ref,
    :archive_object_ref,
    :restore_validation_ref,
    :source_contract_name,
    :retention_policy_ref,
    :cold_storage_uri_ref
  ]

  @type t :: %__MODULE__{}

  @spec contract_name() :: String.t()
  def contract_name, do: @contract_name

  @spec new(map() | keyword()) ::
          {:ok, t()}
          | {:error, {:missing_required_fields, [atom()]}}
          | {:error, :invalid_cold_restore_artifact_projection}
  def new(attrs) do
    with {:ok, attrs} <- ArchivalRestoreSupport.normalize_attrs(attrs),
         [] <- ArchivalRestoreSupport.missing_required_fields(attrs, @required_binary_fields, []),
         true <- ArchivalRestoreSupport.optional_binary_fields?(attrs, @optional_binary_fields),
         true <- ArchivalRestoreSupport.sha256?(Map.get(attrs, :artifact_hash)),
         true <- Map.fetch!(attrs, :source_contract_name) == @source_contract_name do
      {:ok, struct!(__MODULE__, Map.put(attrs, :contract_name, @contract_name))}
    else
      fields when is_list(fields) -> {:error, {:missing_required_fields, fields}}
      _error -> {:error, :invalid_cold_restore_artifact_projection}
    end
  end
end

defmodule AppKit.Core.ArchivalConflictProjection do
  @moduledoc """
  Northbound DTO for hot/cold archival conflict state.

  Contract: `AppKit.ArchivalConflictProjection.v1`.
  """

  alias AppKit.Core.ArchivalRestoreSupport

  @contract_name "AppKit.ArchivalConflictProjection.v1"
  @source_contract_name "Mezzanine.ArchivalConflict.v1"
  @precedence_rules [
    "hot_authoritative",
    "cold_authoritative",
    "quarantine_until_operator_resolution"
  ]
  @required_binary_fields ArchivalRestoreSupport.base_binary_fields() ++
                            [
                              :conflict_ref,
                              :hot_hash,
                              :cold_hash,
                              :quarantine_ref,
                              :resolution_action_ref,
                              :source_contract_name
                            ]
  @optional_binary_fields ArchivalRestoreSupport.optional_actor_fields() ++
                            [:retention_policy_ref, :cold_storage_uri_ref]

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
    :conflict_ref,
    :hot_hash,
    :cold_hash,
    :precedence_rule,
    :quarantine_ref,
    :resolution_action_ref,
    :source_contract_name,
    :retention_policy_ref,
    :cold_storage_uri_ref
  ]

  @type t :: %__MODULE__{}

  @spec contract_name() :: String.t()
  def contract_name, do: @contract_name

  @spec new(map() | keyword()) ::
          {:ok, t()}
          | {:error, {:missing_required_fields, [atom()]}}
          | {:error, :invalid_archival_conflict_projection}
  def new(attrs) do
    with {:ok, attrs} <- ArchivalRestoreSupport.normalize_attrs(attrs),
         [] <- ArchivalRestoreSupport.missing_required_fields(attrs, @required_binary_fields, []),
         true <- ArchivalRestoreSupport.optional_binary_fields?(attrs, @optional_binary_fields),
         true <- ArchivalRestoreSupport.sha256?(Map.get(attrs, :hot_hash)),
         true <- ArchivalRestoreSupport.sha256?(Map.get(attrs, :cold_hash)),
         true <- Map.fetch!(attrs, :hot_hash) != Map.fetch!(attrs, :cold_hash),
         true <- Map.fetch!(attrs, :source_contract_name) == @source_contract_name,
         {:ok, precedence_rule} <-
           ArchivalRestoreSupport.enum_string(Map.get(attrs, :precedence_rule), @precedence_rules) do
      {:ok,
       struct!(
         __MODULE__,
         Map.merge(attrs, %{contract_name: @contract_name, precedence_rule: precedence_rule})
       )}
    else
      fields when is_list(fields) -> {:error, {:missing_required_fields, fields}}
      _error -> {:error, :invalid_archival_conflict_projection}
    end
  end
end

defmodule AppKit.Core.ArchivalSweepProjection do
  @moduledoc """
  Northbound DTO for archival sweep retry and quarantine evidence.

  Contract: `AppKit.ArchivalSweepProjection.v1`.
  """

  alias AppKit.Core.ArchivalRestoreSupport

  @contract_name "AppKit.ArchivalSweepProjection.v1"
  @source_contract_name "Mezzanine.ArchivalSweep.v1"
  @required_binary_fields ArchivalRestoreSupport.base_binary_fields() ++
                            [
                              :sweep_ref,
                              :artifact_ref,
                              :retry_policy_ref,
                              :quarantine_ref,
                              :next_retry_at,
                              :source_contract_name
                            ]
  @required_non_neg_integer_fields [:retry_count]
  @optional_binary_fields ArchivalRestoreSupport.optional_actor_fields() ++
                            [:retention_policy_ref, :cold_storage_uri_ref]

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
    :sweep_ref,
    :artifact_ref,
    :retry_count,
    :retry_policy_ref,
    :quarantine_ref,
    :next_retry_at,
    :source_contract_name,
    :retention_policy_ref,
    :cold_storage_uri_ref
  ]

  @type t :: %__MODULE__{}

  @spec contract_name() :: String.t()
  def contract_name, do: @contract_name

  @spec new(map() | keyword()) ::
          {:ok, t()}
          | {:error, {:missing_required_fields, [atom()]}}
          | {:error, :invalid_archival_sweep_projection}
  def new(attrs) do
    with {:ok, attrs} <- ArchivalRestoreSupport.normalize_attrs(attrs),
         [] <-
           ArchivalRestoreSupport.missing_required_fields(
             attrs,
             @required_binary_fields,
             []
           ),
         :ok <- validate_retry_count(attrs),
         true <- ArchivalRestoreSupport.optional_binary_fields?(attrs, @optional_binary_fields),
         true <- Map.fetch!(attrs, :source_contract_name) == @source_contract_name do
      {:ok, struct!(__MODULE__, Map.put(attrs, :contract_name, @contract_name))}
    else
      {:missing_required_fields, fields} -> {:error, {:missing_required_fields, fields}}
      fields when is_list(fields) -> {:error, {:missing_required_fields, fields}}
      _error -> {:error, :invalid_archival_sweep_projection}
    end
  end

  defp validate_retry_count(attrs) do
    case Map.fetch(attrs, :retry_count) do
      {:ok, value} when is_integer(value) and value >= 0 -> :ok
      {:ok, _value} -> :error
      :error -> {:missing_required_fields, @required_non_neg_integer_fields}
    end
  end
end
