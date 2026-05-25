defmodule AppKit.MemorySurface do
  @moduledoc """
  DTO-only memory surface.
  """

  alias OuterBrain.MemoryContracts

  defmodule MemoryWriteRequest do
    @moduledoc "DTO for governed memory writes."
    @enforce_keys [:request_ref, :intent]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            request_ref: String.t(),
            intent: MemoryContracts.MemoryWriteIntent.t()
          }
  end

  defmodule MemoryQueryRequest do
    @moduledoc "DTO for governed memory queries."
    @enforce_keys [:request_ref, :intent]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            request_ref: String.t(),
            intent: MemoryContracts.MemoryQueryIntent.t()
          }
  end

  defmodule MemoryEvictRequest do
    @moduledoc "DTO for governed memory eviction."
    @enforce_keys [:request_ref, :memory_ref, :reason_ref]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            request_ref: String.t(),
            memory_ref: MemoryContracts.MemoryRef.t(),
            reason_ref: String.t()
          }
  end

  defmodule MemoryProjection do
    @moduledoc "Redacted memory projection."
    @enforce_keys [:memory_ref, :evidence_ref, :content_hash, :redaction_policy_ref]
    defstruct [:redacted_excerpt | @enforce_keys]

    @type t :: %__MODULE__{
            memory_ref: MemoryContracts.MemoryRef.t(),
            evidence_ref: MemoryContracts.MemoryEvidenceRef.t(),
            content_hash: String.t(),
            redaction_policy_ref: String.t(),
            redacted_excerpt: String.t() | nil
          }
  end

  defmodule MemoryAccessRecord do
    @moduledoc "Operator-visible access record."
    @enforce_keys [
      :tenant_ref,
      :authority_ref,
      :installation_ref,
      :idempotency_key,
      :trace_ref,
      :memory_ref,
      :operation,
      :redaction_policy_ref
    ]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            tenant_ref: String.t(),
            authority_ref: String.t(),
            installation_ref: String.t(),
            idempotency_key: String.t(),
            trace_ref: String.t(),
            memory_ref: MemoryContracts.MemoryRef.t(),
            operation: atom(),
            redaction_policy_ref: String.t()
          }
  end

  defmodule CandidateProjection do
    @moduledoc "Product-safe memory candidate projection."
    @enforce_keys [
      :candidate_ref,
      :tenant_ref,
      :memory_ref,
      :evidence_ref,
      :eval_evidence_refs,
      :authority_ref,
      :trace_ref,
      :redaction_policy_ref,
      :status
    ]
    defstruct [:promotion_ref, :rollback_ref | @enforce_keys]

    @type t :: %__MODULE__{
            candidate_ref: String.t(),
            tenant_ref: String.t(),
            memory_ref: MemoryContracts.MemoryRef.t(),
            evidence_ref: MemoryContracts.MemoryEvidenceRef.t(),
            eval_evidence_refs: [String.t()],
            authority_ref: String.t(),
            trace_ref: String.t(),
            redaction_policy_ref: String.t(),
            status: atom(),
            promotion_ref: String.t() | nil,
            rollback_ref: String.t() | nil
          }
  end

  defmodule PromotionProjection do
    @moduledoc "Product-safe memory promotion projection."
    @enforce_keys [
      :candidate_ref,
      :promotion_ref,
      :rollback_ref,
      :tenant_ref,
      :citadel_authority_ref,
      :eval_refs,
      :trace_ref,
      :appkit_projection_ref,
      :status
    ]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            candidate_ref: String.t(),
            promotion_ref: String.t(),
            rollback_ref: String.t(),
            tenant_ref: String.t(),
            citadel_authority_ref: String.t(),
            eval_refs: [String.t()],
            trace_ref: String.t(),
            appkit_projection_ref: String.t(),
            status: :promoted
          }
  end

  defmodule RollbackProjection do
    @moduledoc "Product-safe memory rollback projection."
    @enforce_keys [
      :candidate_ref,
      :rollback_ref,
      :restored_ref,
      :tenant_ref,
      :citadel_authority_ref,
      :trace_ref,
      :appkit_projection_ref,
      :status
    ]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            candidate_ref: String.t(),
            rollback_ref: String.t(),
            restored_ref: String.t(),
            tenant_ref: String.t(),
            citadel_authority_ref: String.t(),
            trace_ref: String.t(),
            appkit_projection_ref: String.t(),
            status: :rolled_back
          }
  end

  @operations [:write, :read, :evict]
  @raw_keys [
    :body,
    :raw_body,
    :payload,
    :raw_payload,
    "body",
    "raw_body",
    "payload",
    "raw_payload"
  ]

  @spec write_request(map()) :: {:ok, MemoryWriteRequest.t()} | {:error, term()}
  def write_request(attrs) when is_map(attrs) do
    with :ok <- reject_raw_payload(attrs),
         {:ok, request_ref} <- required_string(attrs, :request_ref),
         {:ok, intent} <- attrs |> fetch(:intent) |> MemoryContracts.write_intent() do
      {:ok, %MemoryWriteRequest{request_ref: request_ref, intent: intent}}
    end
  end

  @spec query_request(map()) :: {:ok, MemoryQueryRequest.t()} | {:error, term()}
  def query_request(attrs) when is_map(attrs) do
    with :ok <- reject_raw_payload(attrs),
         {:ok, request_ref} <- required_string(attrs, :request_ref),
         {:ok, intent} <- attrs |> fetch(:intent) |> MemoryContracts.query_intent() do
      {:ok, %MemoryQueryRequest{request_ref: request_ref, intent: intent}}
    end
  end

  @spec evict_request(map()) :: {:ok, MemoryEvictRequest.t()} | {:error, term()}
  def evict_request(attrs) when is_map(attrs) do
    with :ok <- reject_raw_payload(attrs),
         {:ok, request_ref} <- required_string(attrs, :request_ref),
         {:ok, memory_ref} <- attrs |> fetch(:memory_ref) |> MemoryContracts.memory_ref(),
         {:ok, reason_ref} <- required_string(attrs, :reason_ref) do
      {:ok,
       %MemoryEvictRequest{
         request_ref: request_ref,
         memory_ref: memory_ref,
         reason_ref: reason_ref
       }}
    end
  end

  @spec projection(map()) :: {:ok, MemoryProjection.t()} | {:error, term()}
  def projection(attrs) when is_map(attrs) do
    with :ok <- reject_raw_payload(attrs),
         {:ok, memory_ref} <- attrs |> fetch(:memory_ref) |> MemoryContracts.memory_ref(),
         {:ok, evidence_ref} <- attrs |> fetch(:evidence_ref) |> MemoryContracts.evidence_ref(),
         {:ok, content_hash} <- required_string(attrs, :content_hash),
         {:ok, redaction_policy_ref} <- required_string(attrs, :redaction_policy_ref) do
      {:ok,
       %MemoryProjection{
         memory_ref: memory_ref,
         evidence_ref: evidence_ref,
         content_hash: content_hash,
         redaction_policy_ref: redaction_policy_ref,
         redacted_excerpt: optional_string(attrs, :redacted_excerpt)
       }}
    end
  end

  @spec access_record(map()) :: {:ok, MemoryAccessRecord.t()} | {:error, term()}
  def access_record(attrs) when is_map(attrs) do
    with :ok <- reject_raw_payload(attrs),
         {:ok, memory_ref} <- attrs |> fetch(:memory_ref) |> MemoryContracts.memory_ref(),
         {:ok, operation} <- required_operation(attrs),
         {:ok, redaction_policy_ref} <- required_string(attrs, :redaction_policy_ref),
         :ok <- required_access_refs(attrs) do
      {:ok,
       %MemoryAccessRecord{
         tenant_ref: fetch(attrs, :tenant_ref),
         authority_ref: fetch(attrs, :authority_ref),
         installation_ref: fetch(attrs, :installation_ref),
         idempotency_key: fetch(attrs, :idempotency_key),
         trace_ref: fetch(attrs, :trace_ref),
         memory_ref: memory_ref,
         operation: operation,
         redaction_policy_ref: redaction_policy_ref
       }}
    end
  end

  @spec candidate_projection(map()) :: {:ok, CandidateProjection.t()} | {:error, term()}
  def candidate_projection(attrs) when is_map(attrs) do
    with :ok <- reject_raw_payload(attrs),
         {:ok, candidate} <- MemoryContracts.memory_candidate(attrs) do
      {:ok,
       %CandidateProjection{
         candidate_ref: candidate.candidate_ref,
         tenant_ref: candidate.tenant_ref,
         memory_ref: candidate.memory_ref,
         evidence_ref: candidate.evidence_ref,
         eval_evidence_refs: candidate.eval_evidence_refs,
         authority_ref: candidate.authority_ref,
         trace_ref: candidate.trace_ref,
         redaction_policy_ref: candidate.redaction_policy_ref,
         status: candidate.status,
         promotion_ref: candidate.promotion_ref,
         rollback_ref: candidate.rollback_ref
       }}
    end
  end

  @spec promotion_projection(map()) :: {:ok, PromotionProjection.t()} | {:error, term()}
  def promotion_projection(attrs) when is_map(attrs) do
    with :ok <- reject_raw_payload(attrs),
         {:ok, candidate_ref} <- required_string(attrs, :candidate_ref),
         {:ok, promotion_ref} <- required_string(attrs, :promotion_ref),
         {:ok, rollback_ref} <- required_string(attrs, :rollback_ref),
         {:ok, tenant_ref} <- required_string(attrs, :tenant_ref),
         {:ok, citadel_authority_ref} <- required_string(attrs, :citadel_authority_ref),
         {:ok, eval_refs} <- required_string_list(attrs, :eval_refs),
         {:ok, trace_ref} <- required_string(attrs, :trace_ref),
         {:ok, appkit_projection_ref} <- required_string(attrs, :appkit_projection_ref),
         :ok <- require_status(attrs, :promoted) do
      {:ok,
       %PromotionProjection{
         candidate_ref: candidate_ref,
         promotion_ref: promotion_ref,
         rollback_ref: rollback_ref,
         tenant_ref: tenant_ref,
         citadel_authority_ref: citadel_authority_ref,
         eval_refs: eval_refs,
         trace_ref: trace_ref,
         appkit_projection_ref: appkit_projection_ref,
         status: :promoted
       }}
    end
  end

  @spec rollback_projection(map()) :: {:ok, RollbackProjection.t()} | {:error, term()}
  def rollback_projection(attrs) when is_map(attrs) do
    with :ok <- reject_raw_payload(attrs),
         {:ok, candidate_ref} <- required_string(attrs, :candidate_ref),
         {:ok, rollback_ref} <- required_string(attrs, :rollback_ref),
         {:ok, restored_ref} <- required_string(attrs, :restored_ref),
         {:ok, tenant_ref} <- required_string(attrs, :tenant_ref),
         {:ok, citadel_authority_ref} <- required_string(attrs, :citadel_authority_ref),
         {:ok, trace_ref} <- required_string(attrs, :trace_ref),
         {:ok, appkit_projection_ref} <- required_string(attrs, :appkit_projection_ref),
         :ok <- require_status(attrs, :rolled_back) do
      {:ok,
       %RollbackProjection{
         candidate_ref: candidate_ref,
         rollback_ref: rollback_ref,
         restored_ref: restored_ref,
         tenant_ref: tenant_ref,
         citadel_authority_ref: citadel_authority_ref,
         trace_ref: trace_ref,
         appkit_projection_ref: appkit_projection_ref,
         status: :rolled_back
       }}
    end
  end

  defp required_access_refs(attrs) do
    case Enum.find(
           [:tenant_ref, :authority_ref, :installation_ref, :idempotency_key, :trace_ref],
           fn field ->
             required_string(attrs, field) != {:ok, fetch(attrs, field)}
           end
         ) do
      nil -> :ok
      field -> {:error, {:missing_access_record_ref, field}}
    end
  end

  defp required_operation(attrs) do
    operation = fetch(attrs, :operation)
    if operation in @operations, do: {:ok, operation}, else: {:error, :invalid_memory_operation}
  end

  defp reject_raw_payload(attrs) do
    case Enum.find(@raw_keys, &Map.has_key?(attrs, &1)) do
      nil -> :ok
      key -> {:error, {:raw_memory_surface_payload_forbidden, key}}
    end
  end

  defp required_string(attrs, field) do
    case fetch(attrs, field) do
      value when is_binary(value) ->
        if String.trim(value) == "", do: {:error, {:missing_field, field}}, else: {:ok, value}

      _other ->
        {:error, {:missing_field, field}}
    end
  end

  defp required_string_list(attrs, field) do
    case fetch(attrs, field) do
      values when is_list(values) and values != [] ->
        if Enum.all?(values, &(is_binary(&1) and String.trim(&1) != "")) do
          {:ok, Enum.uniq(values)}
        else
          {:error, {:missing_field, field}}
        end

      _other ->
        {:error, {:missing_field, field}}
    end
  end

  defp require_status(attrs, expected) do
    if fetch(attrs, :status) == expected do
      :ok
    else
      {:error, {:invalid_status, expected}}
    end
  end

  defp optional_string(attrs, field) do
    case fetch(attrs, field) do
      value when is_binary(value) and value != "" -> value
      _other -> nil
    end
  end

  defp fetch(attrs, field), do: Map.get(attrs, field) || Map.get(attrs, Atom.to_string(field))
end
