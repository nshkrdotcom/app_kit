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

  defp optional_string(attrs, field) do
    case fetch(attrs, field) do
      value when is_binary(value) and value != "" -> value
      _other -> nil
    end
  end

  defp fetch(attrs, field), do: Map.get(attrs, field) || Map.get(attrs, Atom.to_string(field))
end
