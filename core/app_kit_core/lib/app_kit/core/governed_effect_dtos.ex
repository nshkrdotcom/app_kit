defmodule AppKit.Core.GovernedEffectDTOSupport do
  @moduledoc false

  alias AppKit.Core.Substrate.Dump

  @forbidden_field_fragments ~w[
    access_token
    api_key
    authorization
    credential_material
    memory_body
    memory_content
    password
    private_key
    prompt_body
    prompt_content
    provider_payload
    raw_memory
    raw_payload
    raw_prompt
    raw_secret
    secret
    token
  ]

  @spec normalize(map() | keyword() | struct()) :: {:ok, map()} | {:error, :invalid_attrs}
  def normalize(attrs) when is_list(attrs), do: {:ok, Map.new(attrs)}
  def normalize(%_{} = attrs), do: {:ok, Map.from_struct(attrs)}
  def normalize(attrs) when is_map(attrs), do: {:ok, attrs}
  def normalize(_attrs), do: {:error, :invalid_attrs}

  @spec value(map(), atom()) :: term()
  def value(attrs, key) when is_map(attrs),
    do: Map.get(attrs, key, Map.get(attrs, to_string(key)))

  @spec required_string(map(), atom()) :: {:ok, String.t()} | {:error, :missing_required_string}
  def required_string(attrs, key) do
    case string(attrs, key) do
      value when is_binary(value) -> {:ok, value}
      _missing -> {:error, :missing_required_string}
    end
  end

  @spec string(map(), atom()) :: String.t() | nil
  def string(attrs, key), do: value(attrs, key) |> string_value()

  @spec string_value(term()) :: String.t() | nil
  def string_value(nil), do: nil
  def string_value(value) when is_atom(value), do: Atom.to_string(value)
  def string_value(value) when is_binary(value) and value != "", do: value
  def string_value(_value), do: nil

  @spec optional_integer(map(), atom()) :: integer() | nil | :invalid
  def optional_integer(attrs, key) do
    case value(attrs, key) do
      nil -> nil
      value when is_integer(value) -> value
      _other -> :invalid
    end
  end

  @spec optional_map(map(), atom(), map()) :: map() | :invalid
  def optional_map(attrs, key, default \\ %{}) do
    case value(attrs, key) do
      nil -> default
      value when is_map(value) -> stringify_keys(value)
      _other -> :invalid
    end
  end

  @spec optional_list(map(), atom(), list()) :: list() | :invalid
  def optional_list(attrs, key, default \\ []) do
    case value(attrs, key) do
      nil -> default
      value when is_list(value) -> stringify_keys(value)
      _other -> :invalid
    end
  end

  @spec reject_forbidden_material(map()) :: :ok | :error
  def reject_forbidden_material(attrs) when is_map(attrs) do
    if forbidden_material?(attrs), do: :error, else: :ok
  end

  @spec serializable?(term()) :: boolean()
  def serializable?(%DateTime{}), do: true
  def serializable?(%NaiveDateTime{}), do: true
  def serializable?(value) when is_binary(value), do: true
  def serializable?(value) when is_number(value), do: true
  def serializable?(value) when is_boolean(value), do: true
  def serializable?(nil), do: true
  def serializable?(value) when is_atom(value), do: true
  def serializable?(value) when is_list(value), do: Enum.all?(value, &serializable?/1)

  def serializable?(value) when is_map(value) do
    Enum.all?(value, fn {key, nested} ->
      serializable_key?(key) and serializable?(nested)
    end)
  end

  def serializable?(_value), do: false

  @spec dump(struct()) :: map()
  def dump(%_{} = dto) do
    dto
    |> Map.from_struct()
    |> Dump.dump_value()
    |> Map.reject(fn {_key, value} -> is_nil(value) end)
  end

  @spec stringify_keys(term()) :: term()
  def stringify_keys(%_{} = value), do: value |> Map.from_struct() |> stringify_keys()

  def stringify_keys(%{} = value),
    do: Map.new(value, fn {key, item} -> {to_string(key), stringify_keys(item)} end)

  def stringify_keys(values) when is_list(values), do: Enum.map(values, &stringify_keys/1)
  def stringify_keys(value) when is_atom(value), do: Atom.to_string(value)
  def stringify_keys(value), do: value

  defp forbidden_material?(%{} = attrs) do
    Enum.any?(attrs, fn {key, value} ->
      forbidden_key?(key) or forbidden_material?(value)
    end)
  end

  defp forbidden_material?(values) when is_list(values),
    do: Enum.any?(values, &forbidden_material?/1)

  defp forbidden_material?(_value), do: false

  defp forbidden_key?(key) when is_atom(key), do: key |> Atom.to_string() |> forbidden_key?()

  defp forbidden_key?(key) when is_binary(key) do
    normalized = String.downcase(key)
    Enum.any?(@forbidden_field_fragments, &String.contains?(normalized, &1))
  end

  defp forbidden_key?(_key), do: false

  defp serializable_key?(key), do: is_atom(key) or is_binary(key) or is_integer(key)
end

defmodule AppKit.Core.GovernedEffectDTO do
  @moduledoc "Product-safe governed-effect lifecycle projection."

  alias AppKit.Core.GovernedEffectDTOSupport, as: Support

  @enforce_keys [:effect_ref, :effect_type, :command_ref, :tenant_ref, :status, :trace_ref]
  defstruct @enforce_keys ++
              [
                :actor_ref,
                :installation_ref,
                :authority_ref,
                :receipt_ref,
                :dispatch_ref,
                :expected_version,
                metadata: %{}
              ]

  @type t :: %__MODULE__{}

  def new(%__MODULE__{} = value), do: {:ok, value}

  def new(attrs) do
    with {:ok, attrs} <- Support.normalize(attrs),
         :ok <- Support.reject_forbidden_material(attrs),
         true <- Support.serializable?(attrs),
         {:ok, effect_ref} <- Support.required_string(attrs, :effect_ref),
         {:ok, effect_type} <- Support.required_string(attrs, :effect_type),
         {:ok, command_ref} <- Support.required_string(attrs, :command_ref),
         {:ok, tenant_ref} <- Support.required_string(attrs, :tenant_ref),
         {:ok, status} <- Support.required_string(attrs, :status),
         {:ok, trace_ref} <- Support.required_string(attrs, :trace_ref),
         expected_version <- Support.optional_integer(attrs, :expected_version),
         true <- expected_version != :invalid,
         metadata when is_map(metadata) <- Support.optional_map(attrs, :metadata, %{}) do
      {:ok,
       %__MODULE__{
         effect_ref: effect_ref,
         effect_type: effect_type,
         command_ref: command_ref,
         tenant_ref: tenant_ref,
         actor_ref: Support.string(attrs, :actor_ref),
         installation_ref: Support.string(attrs, :installation_ref),
         status: status,
         trace_ref: trace_ref,
         authority_ref: Support.string(attrs, :authority_ref),
         receipt_ref: Support.string(attrs, :receipt_ref),
         dispatch_ref: Support.string(attrs, :dispatch_ref),
         expected_version: expected_version,
         metadata: metadata
       }}
    else
      _other -> {:error, :invalid_governed_effect_dto}
    end
  end

  def dump(%__MODULE__{} = value), do: Support.dump(value)
end

defmodule AppKit.Core.AuthorityDecisionDTO do
  @moduledoc "Product-safe authority decision projection for governed effects."

  alias AppKit.Core.GovernedEffectDTOSupport, as: Support

  @enforce_keys [:authority_ref, :effect_ref, :decision]
  defstruct @enforce_keys ++
              [
                :decision_hash,
                :boundary_class,
                :posture,
                :reason,
                policy_refs: [],
                metadata: %{}
              ]

  @type t :: %__MODULE__{}

  def new(%__MODULE__{} = value), do: {:ok, value}

  def new(attrs) do
    with {:ok, attrs} <- Support.normalize(attrs),
         :ok <- Support.reject_forbidden_material(attrs),
         true <- Support.serializable?(attrs),
         {:ok, authority_ref} <- Support.required_string(attrs, :authority_ref),
         {:ok, effect_ref} <- Support.required_string(attrs, :effect_ref),
         {:ok, decision} <- Support.required_string(attrs, :decision),
         policy_refs when is_list(policy_refs) <- Support.optional_list(attrs, :policy_refs, []),
         true <- Enum.all?(policy_refs, &is_binary/1),
         metadata when is_map(metadata) <- Support.optional_map(attrs, :metadata, %{}) do
      {:ok,
       %__MODULE__{
         authority_ref: authority_ref,
         effect_ref: effect_ref,
         decision: decision,
         decision_hash: Support.string(attrs, :decision_hash),
         boundary_class: Support.string(attrs, :boundary_class),
         posture: Support.string(attrs, :posture),
         reason: Support.string(attrs, :reason),
         policy_refs: policy_refs,
         metadata: metadata
       }}
    else
      _other -> {:error, :invalid_authority_decision_dto}
    end
  end

  def dump(%__MODULE__{} = value), do: Support.dump(value)
end

defmodule AppKit.Core.EffectReceiptDTO do
  @moduledoc "Product-safe governed-effect receipt projection."

  alias AppKit.Core.GovernedEffectDTOSupport, as: Support

  @enforce_keys [:receipt_ref, :effect_ref, :status]
  defstruct @enforce_keys ++ [:trace_ref, evidence_refs: [], metadata: %{}]

  @type t :: %__MODULE__{}

  def new(%__MODULE__{} = value), do: {:ok, value}

  def new(attrs) do
    with {:ok, attrs} <- Support.normalize(attrs),
         :ok <- Support.reject_forbidden_material(attrs),
         true <- Support.serializable?(attrs),
         {:ok, receipt_ref} <- Support.required_string(attrs, :receipt_ref),
         {:ok, effect_ref} <- Support.required_string(attrs, :effect_ref),
         {:ok, status} <- Support.required_string(attrs, :status),
         evidence_refs when is_list(evidence_refs) <-
           Support.optional_list(attrs, :evidence_refs, []),
         true <- Enum.all?(evidence_refs, &is_binary/1),
         metadata when is_map(metadata) <- Support.optional_map(attrs, :metadata, %{}) do
      {:ok,
       %__MODULE__{
         receipt_ref: receipt_ref,
         effect_ref: effect_ref,
         status: status,
         trace_ref: Support.string(attrs, :trace_ref),
         evidence_refs: evidence_refs,
         metadata: metadata
       }}
    else
      _other -> {:error, :invalid_effect_receipt_dto}
    end
  end

  def dump(%__MODULE__{} = value), do: Support.dump(value)
end

defmodule AppKit.Core.EffectEvidenceDTO do
  @moduledoc "Product-safe governed-effect evidence refs."

  alias AppKit.Core.GovernedEffectDTOSupport, as: Support

  @enforce_keys [:effect_ref]
  defstruct @enforce_keys ++
              [:receipt_ref, :trace_ref, :trace_summary_hash, evidence_refs: [], metadata: %{}]

  @type t :: %__MODULE__{}

  def new(%__MODULE__{} = value), do: {:ok, value}

  def new(attrs) do
    with {:ok, attrs} <- Support.normalize(attrs),
         :ok <- Support.reject_forbidden_material(attrs),
         true <- Support.serializable?(attrs),
         {:ok, effect_ref} <- Support.required_string(attrs, :effect_ref),
         evidence_refs when is_list(evidence_refs) <-
           Support.optional_list(attrs, :evidence_refs, []),
         true <- Enum.all?(evidence_refs, &is_binary/1),
         metadata when is_map(metadata) <- Support.optional_map(attrs, :metadata, %{}) do
      {:ok,
       %__MODULE__{
         effect_ref: effect_ref,
         receipt_ref: Support.string(attrs, :receipt_ref),
         trace_ref: Support.string(attrs, :trace_ref),
         trace_summary_hash: Support.string(attrs, :trace_summary_hash),
         evidence_refs: evidence_refs,
         metadata: metadata
       }}
    else
      _other -> {:error, :invalid_effect_evidence_dto}
    end
  end

  def dump(%__MODULE__{} = value), do: Support.dump(value)
end

defmodule AppKit.Core.EffectTimelineDTO do
  @moduledoc "Product-safe governed-effect lifecycle timeline."

  alias AppKit.Core.GovernedEffectDTOSupport, as: Support

  @enforce_keys [:effect_ref]
  defstruct @enforce_keys ++ [:trace_summary_hash, entries: [], metadata: %{}]

  @type t :: %__MODULE__{}

  def new(%__MODULE__{} = value), do: {:ok, value}

  def new(attrs) do
    with {:ok, attrs} <- Support.normalize(attrs),
         :ok <- Support.reject_forbidden_material(attrs),
         true <- Support.serializable?(attrs),
         {:ok, effect_ref} <- Support.required_string(attrs, :effect_ref),
         entries when is_list(entries) <- Support.optional_list(attrs, :entries, []),
         true <- Enum.all?(entries, &is_map/1),
         metadata when is_map(metadata) <- Support.optional_map(attrs, :metadata, %{}) do
      {:ok,
       %__MODULE__{
         effect_ref: effect_ref,
         trace_summary_hash: Support.string(attrs, :trace_summary_hash),
         entries: entries,
         metadata: metadata
       }}
    else
      _other -> {:error, :invalid_effect_timeline_dto}
    end
  end

  def dump(%__MODULE__{} = value), do: Support.dump(value)
end
