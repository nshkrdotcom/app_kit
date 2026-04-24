defmodule AppKit.Core.MemoryControlSupport do
  @moduledoc false

  @hash_regex ~r/\Asha256:[a-f0-9]{64}\z/
  @forbidden_payload_fields [
    :payload,
    :raw_payload,
    :content,
    :fragment_payload,
    :body,
    :raw_fragment,
    :raw_content
  ]

  @spec normalize_attrs(map() | keyword() | struct()) :: {:ok, map()} | {:error, :invalid_attrs}
  def normalize_attrs(attrs) when is_list(attrs), do: {:ok, Map.new(attrs)}

  def normalize_attrs(attrs) when is_map(attrs) do
    if Map.has_key?(attrs, :__struct__) do
      {:ok, attrs |> Map.from_struct() |> Map.delete(:contract_name)}
    else
      {:ok, attrs}
    end
  end

  def normalize_attrs(_attrs), do: {:error, :invalid_attrs}

  @spec fetch(map(), atom()) :: term()
  def fetch(attrs, key) when is_map(attrs) and is_atom(key) do
    Map.get(attrs, key) || Map.get(attrs, Atom.to_string(key))
  end

  @spec required_strings(map(), [atom()]) :: [atom()]
  def required_strings(attrs, fields) when is_map(attrs) and is_list(fields) do
    Enum.reject(fields, fn field ->
      attrs |> fetch(field) |> present_binary?()
    end)
  end

  @spec present_binary?(term()) :: boolean()
  def present_binary?(value) when is_binary(value), do: String.trim(value) != ""
  def present_binary?(_value), do: false

  @spec optional_binary?(term()) :: boolean()
  def optional_binary?(nil), do: true
  def optional_binary?(value), do: present_binary?(value)

  @spec positive_integer?(term()) :: boolean()
  def positive_integer?(value), do: is_integer(value) and value > 0

  @spec optional_positive_integer?(term()) :: boolean()
  def optional_positive_integer?(nil), do: true
  def optional_positive_integer?(value), do: positive_integer?(value)

  @spec non_empty_list?(term()) :: boolean()
  def non_empty_list?([_head | _tail]), do: true
  def non_empty_list?(_value), do: false

  @spec optional_list?(term()) :: boolean()
  def optional_list?(nil), do: true
  def optional_list?(value), do: is_list(value)

  @spec optional_map?(term()) :: boolean()
  def optional_map?(nil), do: true
  def optional_map?(value), do: is_map(value)

  @spec boolean?(term()) :: boolean()
  def boolean?(value), do: is_boolean(value)

  @spec sha256?(term()) :: boolean()
  def sha256?(value) when is_binary(value), do: Regex.match?(@hash_regex, value)
  def sha256?(_value), do: false

  @spec enum?(term(), [term()]) :: boolean()
  def enum?(value, allowed), do: value in allowed

  @spec optional_enum?(term(), [term()]) :: boolean()
  def optional_enum?(nil, _allowed), do: true
  def optional_enum?(value, allowed), do: value in allowed

  @spec reject_forbidden_payload(map()) :: :ok | {:error, {:raw_payload_forbidden, atom()}}
  def reject_forbidden_payload(attrs) when is_map(attrs) do
    case Enum.find(@forbidden_payload_fields, &payload_field_present?(attrs, &1)) do
      nil -> :ok
      field -> {:error, {:raw_payload_forbidden, field}}
    end
  end

  @spec take_fields(map(), [atom()]) :: map()
  def take_fields(attrs, fields) when is_map(attrs) and is_list(fields) do
    Map.new(fields, fn field -> {field, fetch(attrs, field)} end)
  end

  @spec normalize_reason(term(), [atom()]) :: {:ok, atom()} | {:error, term()}
  def normalize_reason(reason, allowed) when is_atom(reason) do
    if reason in allowed do
      {:ok, reason}
    else
      {:error, {:unsupported_invalidation_reason, reason}}
    end
  end

  def normalize_reason(reason, allowed) when is_binary(reason) do
    case Enum.find(allowed, &(Atom.to_string(&1) == reason)) do
      nil -> {:error, {:unsupported_invalidation_reason, reason}}
      normalized -> {:ok, normalized}
    end
  end

  def normalize_reason(reason, _allowed), do: {:error, {:unsupported_invalidation_reason, reason}}

  defp payload_field_present?(attrs, field) do
    Map.has_key?(attrs, field) or Map.has_key?(attrs, Atom.to_string(field))
  end
end

defmodule AppKit.Core.MemoryFragmentProjection do
  @moduledoc """
  Operator-safe governed-memory fragment projection.
  """

  alias AppKit.Core.MemoryControlSupport

  @contract_name "AppKit.MemoryFragmentProjection.v1"
  @staleness_classes [
    "fresh",
    "epoch_bounded",
    "invalidation_pending",
    "invalidation_reconciling",
    "partitioned",
    "unknown"
  ]
  @cluster_statuses ["none", "pending", "reconciling", "revoked", "unknown"]
  @required_strings [
    :fragment_ref,
    :tenant_ref,
    :tier,
    :proof_token_ref,
    :proof_hash,
    :source_node_ref,
    :commit_lsn,
    :staleness_class,
    :cluster_invalidation_status,
    :redaction_posture
  ]
  @fields [
    :contract_name,
    :fragment_ref,
    :tenant_ref,
    :installation_ref,
    :tier,
    :proof_token_ref,
    :proof_hash,
    :source_node_ref,
    :snapshot_epoch,
    :commit_lsn,
    :commit_hlc,
    :provenance_refs,
    :evidence_refs,
    :governance_refs,
    :cluster_invalidation_status,
    :staleness_class,
    :redaction_posture,
    :metadata
  ]

  defstruct @fields

  @type t :: %__MODULE__{}

  @spec contract_name() :: String.t()
  def contract_name, do: @contract_name

  @spec staleness_classes() :: [String.t()]
  def staleness_classes, do: @staleness_classes

  @spec new(map() | keyword() | t()) ::
          {:ok, t()}
          | {:error, {:missing_required_fields, [atom()]}}
          | {:error, {:invalid_enum, atom()}}
          | {:error, {:raw_payload_forbidden, atom()}}
          | {:error, :invalid_memory_fragment_projection}
  def new(attrs) do
    with {:ok, attrs} <- MemoryControlSupport.normalize_attrs(attrs),
         :ok <- MemoryControlSupport.reject_forbidden_payload(attrs),
         [] <- missing_required_fields(attrs),
         true <- MemoryControlSupport.sha256?(MemoryControlSupport.fetch(attrs, :proof_hash)),
         true <-
           MemoryControlSupport.positive_integer?(
             MemoryControlSupport.fetch(attrs, :snapshot_epoch)
           ),
         true <-
           MemoryControlSupport.optional_binary?(
             MemoryControlSupport.fetch(attrs, :installation_ref)
           ),
         true <-
           MemoryControlSupport.optional_map?(MemoryControlSupport.fetch(attrs, :commit_hlc)),
         true <-
           MemoryControlSupport.non_empty_list?(
             MemoryControlSupport.fetch(attrs, :provenance_refs)
           ),
         true <-
           MemoryControlSupport.non_empty_list?(MemoryControlSupport.fetch(attrs, :evidence_refs)),
         true <-
           MemoryControlSupport.non_empty_list?(
             MemoryControlSupport.fetch(attrs, :governance_refs)
           ),
         true <- MemoryControlSupport.optional_map?(MemoryControlSupport.fetch(attrs, :metadata)),
         :ok <- validate_enum(attrs, :staleness_class, @staleness_classes),
         :ok <- validate_enum(attrs, :cluster_invalidation_status, @cluster_statuses) do
      {:ok, build(attrs)}
    else
      {:error, reason} -> {:error, reason}
      fields when is_list(fields) -> {:error, {:missing_required_fields, fields}}
      false -> {:error, :invalid_memory_fragment_projection}
    end
  end

  defp missing_required_fields(attrs) do
    MemoryControlSupport.required_strings(attrs, @required_strings) ++
      missing_required_non_strings(attrs)
  end

  defp missing_required_non_strings(attrs) do
    [
      required_field(attrs, :snapshot_epoch, &MemoryControlSupport.positive_integer?/1),
      required_field(attrs, :commit_hlc, &is_map/1),
      required_field(attrs, :provenance_refs, &MemoryControlSupport.non_empty_list?/1),
      required_field(attrs, :evidence_refs, &MemoryControlSupport.non_empty_list?/1),
      required_field(attrs, :governance_refs, &MemoryControlSupport.non_empty_list?/1)
    ]
    |> Enum.reject(&is_nil/1)
  end

  defp required_field(attrs, field, validator) do
    value = MemoryControlSupport.fetch(attrs, field)
    if validator.(value), do: nil, else: field
  end

  defp validate_enum(attrs, field, allowed) do
    if MemoryControlSupport.enum?(MemoryControlSupport.fetch(attrs, field), allowed) do
      :ok
    else
      {:error, {:invalid_enum, field}}
    end
  end

  defp build(attrs) do
    struct!(
      __MODULE__,
      attrs
      |> MemoryControlSupport.take_fields(@fields)
      |> Map.put(:contract_name, @contract_name)
      |> Map.update!(:metadata, &(&1 || %{}))
    )
  end
end

defmodule AppKit.Core.MemoryFragmentListRequest do
  @moduledoc """
  Operator request to list fragment projections admitted by a proof token.
  """

  alias AppKit.Core.MemoryControlSupport

  defstruct proof_token_ref: nil, include_provenance?: false, metadata: %{}

  @type t :: %__MODULE__{
          proof_token_ref: String.t(),
          include_provenance?: boolean(),
          metadata: map()
        }

  @spec new(map() | keyword() | t()) ::
          {:ok, t()} | {:error, {:missing_required_fields, [atom()]}} | {:error, atom()}
  def new(attrs) do
    with {:ok, attrs} <- MemoryControlSupport.normalize_attrs(attrs),
         [] <- MemoryControlSupport.required_strings(attrs, [:proof_token_ref]),
         include_provenance? <- MemoryControlSupport.fetch(attrs, :include_provenance?) || false,
         true <- MemoryControlSupport.boolean?(include_provenance?),
         metadata <- MemoryControlSupport.fetch(attrs, :metadata) || %{},
         true <- is_map(metadata) do
      {:ok,
       %__MODULE__{
         proof_token_ref: MemoryControlSupport.fetch(attrs, :proof_token_ref),
         include_provenance?: include_provenance?,
         metadata: metadata
       }}
    else
      fields when is_list(fields) -> {:error, {:missing_required_fields, fields}}
      _error -> {:error, :invalid_memory_fragment_list_request}
    end
  end
end

defmodule AppKit.Core.MemoryProofTokenLookup do
  @moduledoc """
  Operator proof-token lookup request.
  """

  alias AppKit.Core.MemoryControlSupport

  defstruct proof_token_ref: nil,
            expected_tenant_ref: nil,
            reject_stale?: false,
            current_epoch: nil,
            metadata: %{}

  @type t :: %__MODULE__{}

  @spec new(map() | keyword() | t()) ::
          {:ok, t()} | {:error, {:missing_required_fields, [atom()]}} | {:error, atom()}
  def new(attrs) do
    with {:ok, attrs} <- MemoryControlSupport.normalize_attrs(attrs),
         [] <- MemoryControlSupport.required_strings(attrs, [:proof_token_ref]),
         true <-
           MemoryControlSupport.optional_binary?(
             MemoryControlSupport.fetch(attrs, :expected_tenant_ref)
           ),
         reject_stale? <- MemoryControlSupport.fetch(attrs, :reject_stale?) || false,
         true <- MemoryControlSupport.boolean?(reject_stale?),
         true <-
           MemoryControlSupport.optional_positive_integer?(
             MemoryControlSupport.fetch(attrs, :current_epoch)
           ),
         metadata <- MemoryControlSupport.fetch(attrs, :metadata) || %{},
         true <- is_map(metadata) do
      {:ok,
       %__MODULE__{
         proof_token_ref: MemoryControlSupport.fetch(attrs, :proof_token_ref),
         expected_tenant_ref: MemoryControlSupport.fetch(attrs, :expected_tenant_ref),
         reject_stale?: reject_stale?,
         current_epoch: MemoryControlSupport.fetch(attrs, :current_epoch),
         metadata: metadata
       }}
    else
      fields when is_list(fields) -> {:error, {:missing_required_fields, fields}}
      _error -> {:error, :invalid_memory_proof_token_lookup}
    end
  end
end

defmodule AppKit.Core.MemoryFragmentProvenance do
  @moduledoc """
  Operator-safe memory fragment provenance display DTO.
  """

  alias AppKit.Core.MemoryControlSupport

  @contract_name "AppKit.MemoryFragmentProvenance.v1"
  @source_contract_name "OuterBrain.MemoryContextProvenance.v2"
  @required_strings [
    :fragment_ref,
    :proof_token_ref,
    :proof_hash,
    :source_contract_name,
    :source_node_ref,
    :commit_lsn
  ]
  @fields [
    :contract_name,
    :fragment_ref,
    :proof_token_ref,
    :proof_hash,
    :source_contract_name,
    :snapshot_epoch,
    :source_node_ref,
    :commit_lsn,
    :commit_hlc,
    :provenance_refs,
    :evidence_refs,
    :governance_refs,
    :metadata
  ]

  defstruct @fields

  @type t :: %__MODULE__{}

  @spec contract_name() :: String.t()
  def contract_name, do: @contract_name

  @spec new(map() | keyword() | t()) ::
          {:ok, t()}
          | {:error, {:missing_required_fields, [atom()]}}
          | {:error, :invalid_memory_fragment_provenance}
  def new(attrs) do
    with {:ok, attrs} <- MemoryControlSupport.normalize_attrs(attrs),
         :ok <- MemoryControlSupport.reject_forbidden_payload(attrs),
         [] <- missing_required_fields(attrs),
         true <- MemoryControlSupport.sha256?(MemoryControlSupport.fetch(attrs, :proof_hash)),
         true <- MemoryControlSupport.fetch(attrs, :source_contract_name) == @source_contract_name,
         true <-
           MemoryControlSupport.positive_integer?(
             MemoryControlSupport.fetch(attrs, :snapshot_epoch)
           ),
         true <- is_map(MemoryControlSupport.fetch(attrs, :commit_hlc)),
         true <-
           MemoryControlSupport.non_empty_list?(
             MemoryControlSupport.fetch(attrs, :provenance_refs)
           ),
         true <-
           MemoryControlSupport.non_empty_list?(MemoryControlSupport.fetch(attrs, :evidence_refs)),
         true <-
           MemoryControlSupport.non_empty_list?(
             MemoryControlSupport.fetch(attrs, :governance_refs)
           ),
         true <- MemoryControlSupport.optional_map?(MemoryControlSupport.fetch(attrs, :metadata)) do
      {:ok, build(attrs)}
    else
      {:error, reason} -> {:error, reason}
      fields when is_list(fields) -> {:error, {:missing_required_fields, fields}}
      _error -> {:error, :invalid_memory_fragment_provenance}
    end
  end

  defp missing_required_fields(attrs) do
    MemoryControlSupport.required_strings(attrs, @required_strings) ++
      ([
         required_field(attrs, :snapshot_epoch, &MemoryControlSupport.positive_integer?/1),
         required_field(attrs, :commit_hlc, &is_map/1),
         required_field(attrs, :provenance_refs, &MemoryControlSupport.non_empty_list?/1),
         required_field(attrs, :evidence_refs, &MemoryControlSupport.non_empty_list?/1),
         required_field(attrs, :governance_refs, &MemoryControlSupport.non_empty_list?/1)
       ]
       |> Enum.reject(&is_nil/1))
  end

  defp required_field(attrs, field, validator) do
    value = MemoryControlSupport.fetch(attrs, field)
    if validator.(value), do: nil, else: field
  end

  defp build(attrs) do
    struct!(
      __MODULE__,
      attrs
      |> MemoryControlSupport.take_fields(@fields)
      |> Map.put(:contract_name, @contract_name)
      |> Map.update!(:metadata, &(&1 || %{}))
    )
  end
end

defmodule AppKit.Core.MemoryShareUpRequest do
  @moduledoc """
  Operator request to share private memory upward through the governed lower path.
  """

  alias AppKit.Core.MemoryControlSupport

  @fields [
    :fragment_ref,
    :target_scope_ref,
    :share_up_policy_ref,
    :transform_ref,
    :reason,
    :evidence_refs,
    :metadata
  ]
  defstruct fragment_ref: nil,
            target_scope_ref: nil,
            share_up_policy_ref: nil,
            transform_ref: nil,
            reason: nil,
            evidence_refs: [],
            metadata: %{}

  @type t :: %__MODULE__{}

  @spec new(map() | keyword() | t()) ::
          {:ok, t()}
          | {:error, {:missing_required_fields, [atom()]}}
          | {:error, :identity_share_up_forbidden}
          | {:error, :invalid_memory_share_up_request}
  def new(attrs) do
    with {:ok, attrs} <- MemoryControlSupport.normalize_attrs(attrs),
         :ok <- MemoryControlSupport.reject_forbidden_payload(attrs),
         [] <-
           MemoryControlSupport.required_strings(attrs, [
             :fragment_ref,
             :target_scope_ref,
             :share_up_policy_ref,
             :transform_ref,
             :reason
           ]),
         true <-
           MemoryControlSupport.non_empty_list?(MemoryControlSupport.fetch(attrs, :evidence_refs)),
         :ok <- reject_identity_transform(MemoryControlSupport.fetch(attrs, :transform_ref)),
         true <- MemoryControlSupport.optional_map?(MemoryControlSupport.fetch(attrs, :metadata)) do
      {:ok, build(attrs)}
    else
      {:error, reason} -> {:error, reason}
      fields when is_list(fields) -> {:error, {:missing_required_fields, fields}}
      false -> {:error, {:missing_required_fields, [:evidence_refs]}}
    end
  end

  defp reject_identity_transform(transform_ref)
       when transform_ref in ["identity", "identity_transform"],
       do: {:error, :identity_share_up_forbidden}

  defp reject_identity_transform(_transform_ref), do: :ok

  defp build(attrs) do
    struct!(
      __MODULE__,
      attrs
      |> MemoryControlSupport.take_fields(@fields)
      |> Map.update!(:metadata, &(&1 || %{}))
    )
  end
end

defmodule AppKit.Core.MemoryPromotionRequest do
  @moduledoc """
  Operator request to promote shared memory into governed memory.
  """

  alias AppKit.Core.MemoryControlSupport

  @fields [:shared_fragment_ref, :promotion_policy_ref, :reason, :evidence_refs, :metadata]
  defstruct shared_fragment_ref: nil,
            promotion_policy_ref: nil,
            reason: nil,
            evidence_refs: [],
            metadata: %{}

  @type t :: %__MODULE__{}

  @spec new(map() | keyword() | t()) ::
          {:ok, t()} | {:error, {:missing_required_fields, [atom()]}} | {:error, atom()}
  def new(attrs) do
    with {:ok, attrs} <- MemoryControlSupport.normalize_attrs(attrs),
         :ok <- MemoryControlSupport.reject_forbidden_payload(attrs),
         [] <-
           MemoryControlSupport.required_strings(attrs, [
             :shared_fragment_ref,
             :promotion_policy_ref,
             :reason
           ]),
         true <-
           MemoryControlSupport.non_empty_list?(MemoryControlSupport.fetch(attrs, :evidence_refs)),
         true <- MemoryControlSupport.optional_map?(MemoryControlSupport.fetch(attrs, :metadata)) do
      {:ok, build(attrs)}
    else
      {:error, reason} -> {:error, reason}
      fields when is_list(fields) -> {:error, {:missing_required_fields, fields}}
      false -> {:error, {:missing_required_fields, [:evidence_refs]}}
    end
  end

  defp build(attrs) do
    struct!(
      __MODULE__,
      attrs
      |> MemoryControlSupport.take_fields(@fields)
      |> Map.update!(:metadata, &(&1 || %{}))
    )
  end
end

defmodule AppKit.Core.MemoryInvalidationRequest do
  @moduledoc """
  Operator request to invalidate or suppress governed-memory fragments.
  """

  alias AppKit.Core.MemoryControlSupport

  @allowed_reasons [
    :user_deletion,
    :source_correction,
    :source_deletion,
    :policy_change,
    :tenant_offboarding,
    :operator_suppression,
    :semantic_quarantine,
    :retention_expiry
  ]
  @fields [
    :root_fragment_ref,
    :reason,
    :suppression_reason,
    :invalidate_policy_ref,
    :authority_ref,
    :evidence_refs,
    :metadata
  ]
  defstruct root_fragment_ref: nil,
            reason: nil,
            suppression_reason: nil,
            invalidate_policy_ref: nil,
            authority_ref: nil,
            evidence_refs: [],
            metadata: %{}

  @type t :: %__MODULE__{}

  @spec new(map() | keyword() | t()) ::
          {:ok, t()} | {:error, {:missing_required_fields, [atom()]}} | {:error, term()}
  def new(attrs) do
    with {:ok, attrs} <- MemoryControlSupport.normalize_attrs(attrs),
         :ok <- MemoryControlSupport.reject_forbidden_payload(attrs),
         {:ok, reason} <-
           MemoryControlSupport.normalize_reason(
             MemoryControlSupport.fetch(attrs, :reason),
             @allowed_reasons
           ),
         attrs <- Map.put(attrs, :reason, reason),
         [] <- missing_required_fields(attrs),
         true <-
           MemoryControlSupport.non_empty_list?(MemoryControlSupport.fetch(attrs, :evidence_refs)),
         true <- is_map(MemoryControlSupport.fetch(attrs, :authority_ref)),
         true <- MemoryControlSupport.optional_map?(MemoryControlSupport.fetch(attrs, :metadata)) do
      {:ok, build(attrs)}
    else
      {:error, reason} -> {:error, reason}
      fields when is_list(fields) -> {:error, {:missing_required_fields, fields}}
      false -> {:error, :invalid_memory_invalidation_request}
    end
  end

  defp missing_required_fields(%{reason: :operator_suppression} = attrs) do
    MemoryControlSupport.required_strings(attrs, [
      :root_fragment_ref,
      :suppression_reason,
      :invalidate_policy_ref
    ]) ++ missing_non_strings(attrs)
  end

  defp missing_required_fields(attrs) do
    MemoryControlSupport.required_strings(attrs, [:root_fragment_ref, :invalidate_policy_ref]) ++
      missing_non_strings(attrs)
  end

  defp missing_non_strings(attrs) do
    [
      required_field(attrs, :authority_ref, &is_map/1),
      required_field(attrs, :evidence_refs, &MemoryControlSupport.non_empty_list?/1)
    ]
    |> Enum.reject(&is_nil/1)
  end

  defp required_field(attrs, field, validator) do
    value = MemoryControlSupport.fetch(attrs, field)
    if validator.(value), do: nil, else: field
  end

  defp build(attrs) do
    struct!(
      __MODULE__,
      attrs
      |> MemoryControlSupport.take_fields(@fields)
      |> Map.update!(:metadata, &(&1 || %{}))
    )
  end
end
