defmodule AppKit.Core.RuntimeSurface.Support do
  @moduledoc false

  @forbidden_keys MapSet.new(~w[
    api_key
    authorization
    credential
    credential_value
    password
    provider_payload
    raw_secret
    secret
    token
    access_token
  ])

  def normalize(attrs) when is_list(attrs), do: {:ok, Map.new(attrs)}
  def normalize(%_{} = attrs), do: {:ok, Map.from_struct(attrs)}
  def normalize(attrs) when is_map(attrs), do: {:ok, attrs}
  def normalize(_attrs), do: {:error, :invalid_attrs}

  def value(attrs, key) when is_map(attrs) do
    Map.get(attrs, key) || Map.get(attrs, Atom.to_string(key))
  end

  def value(_attrs, _key), do: nil

  def string(attrs, key), do: value(attrs, key) |> string_value()

  def string_value(value) when is_atom(value), do: Atom.to_string(value)
  def string_value(value) when is_binary(value) and value != "", do: value
  def string_value(_value), do: nil

  def required_string(attrs, key) do
    case string(attrs, key) do
      value when is_binary(value) -> {:ok, value}
      _missing -> {:error, :missing_required_string}
    end
  end

  def optional_map(attrs, key, default \\ %{}) do
    case value(attrs, key) do
      nil -> default
      value when is_map(value) -> stringify_keys(value)
      _other -> :invalid
    end
  end

  def optional_list(attrs, key, default \\ []) do
    case value(attrs, key) do
      nil -> default
      value when is_list(value) -> value
      value -> [value]
    end
  end

  def boolean(attrs, key, default \\ false) do
    case value(attrs, key) do
      nil -> default
      value when is_boolean(value) -> value
      _other -> :invalid
    end
  end

  def status(attrs, key, allowed) do
    case value(attrs, key) do
      value when is_atom(value) -> status_from_atom(value, allowed)
      value when is_binary(value) -> status_from_string(value, allowed)
      _other -> {:error, :invalid_status}
    end
  end

  def optional_non_negative_integer(attrs, key, default) do
    case value(attrs, key) do
      nil -> default
      value when is_integer(value) and value >= 0 -> value
      _other -> :invalid
    end
  end

  def reject_forbidden_material(attrs) when is_map(attrs) do
    if forbidden_material?(attrs), do: :error, else: :ok
  end

  def stringify_keys(value) when is_map(value) do
    Map.new(value, fn {key, nested} -> {to_string(key), stringify_keys(nested)} end)
  end

  def stringify_keys(value) when is_list(value), do: Enum.map(value, &stringify_keys/1)
  def stringify_keys(value), do: value

  defp status_from_string(value, allowed) do
    Enum.find(allowed, &(Atom.to_string(&1) == value))
    |> case do
      nil -> {:error, :invalid_status}
      status -> {:ok, status}
    end
  end

  defp status_from_atom(value, allowed) do
    if value in allowed, do: {:ok, value}, else: {:error, :invalid_status}
  end

  defp forbidden_material?(%{} = attrs) do
    Enum.any?(attrs, fn {key, value} ->
      MapSet.member?(@forbidden_keys, to_string(key)) or forbidden_material?(value)
    end)
  end

  defp forbidden_material?([_ | _] = values), do: Enum.any?(values, &forbidden_material?/1)
  defp forbidden_material?(_value), do: false
end

defmodule AppKit.Core.RuntimeSurface.RuntimeProfileApplyResult do
  @moduledoc "Public result for applying a product runtime profile through AppKit."

  alias AppKit.Core.RuntimeSurface.Support

  @statuses [:unchanged, :updated, :failed]
  defstruct [
    :status,
    :tenant_ref,
    :profile_ref,
    :program_ref,
    :policy_bundle_ref,
    :work_class_ref,
    :placement_profile_ref,
    metadata: %{}
  ]

  @type t :: %__MODULE__{
          status: :unchanged | :updated | :failed,
          tenant_ref: String.t() | nil,
          profile_ref: String.t() | nil,
          program_ref: String.t() | nil,
          policy_bundle_ref: String.t() | nil,
          work_class_ref: String.t() | nil,
          placement_profile_ref: String.t() | nil,
          metadata: map()
        }

  def new(%__MODULE__{} = value), do: {:ok, value}

  def new(attrs) do
    with {:ok, attrs} <- Support.normalize(attrs),
         {:ok, status} <- Support.status(attrs, :status, @statuses),
         metadata when is_map(metadata) <- Support.optional_map(attrs, :metadata, %{}) do
      {:ok,
       %__MODULE__{
         status: status,
         tenant_ref: Support.string(attrs, :tenant_ref),
         profile_ref: Support.string(attrs, :profile_ref),
         program_ref: Support.string(attrs, :program_ref),
         policy_bundle_ref: Support.string(attrs, :policy_bundle_ref),
         work_class_ref: Support.string(attrs, :work_class_ref),
         placement_profile_ref: Support.string(attrs, :placement_profile_ref),
         metadata: metadata
       }}
    else
      _other -> {:error, :invalid_runtime_profile_apply_result}
    end
  end
end

defmodule AppKit.Core.RuntimeSurface.RuntimeStatusSnapshot do
  @moduledoc "Operator-safe runtime status and preflight projection."

  alias AppKit.Core.RuntimeSurface.Support

  defstruct [:tenant_ref, :program_ref, health: %{}, preflight: %{}, metadata: %{}]

  @type t :: %__MODULE__{
          tenant_ref: String.t() | nil,
          program_ref: String.t() | nil,
          health: map(),
          preflight: map(),
          metadata: map()
        }

  def new(%__MODULE__{} = value), do: {:ok, value}

  def new(attrs) do
    with {:ok, attrs} <- Support.normalize(attrs),
         health when is_map(health) <- Support.optional_map(attrs, :health, %{}),
         preflight when is_map(preflight) <- Support.optional_map(attrs, :preflight, %{}),
         metadata when is_map(metadata) <- Support.optional_map(attrs, :metadata, %{}) do
      {:ok,
       %__MODULE__{
         tenant_ref: Support.string(attrs, :tenant_ref),
         program_ref: Support.string(attrs, :program_ref),
         health: health,
         preflight: preflight,
         metadata: metadata
       }}
    else
      _other -> {:error, :invalid_runtime_status_snapshot}
    end
  end
end

defmodule AppKit.Core.RuntimeSurface.RuntimeLogRow do
  @moduledoc "Redacted runtime/operator log row."

  alias AppKit.Core.RuntimeSurface.Support

  defstruct [:ref, :event_kind, :occurred_at, :summary, payload: %{}, metadata: %{}]

  @type t :: %__MODULE__{
          ref: String.t() | nil,
          event_kind: String.t() | nil,
          occurred_at: term(),
          summary: String.t() | nil,
          payload: map(),
          metadata: map()
        }

  def new(%__MODULE__{} = value), do: {:ok, value}

  def new(attrs) do
    with {:ok, attrs} <- Support.normalize(attrs),
         payload when is_map(payload) <- Support.optional_map(attrs, :payload, %{}),
         metadata when is_map(metadata) <- Support.optional_map(attrs, :metadata, %{}) do
      {:ok,
       %__MODULE__{
         ref: Support.string(attrs, :ref) || Support.string(attrs, :id),
         event_kind: Support.string(attrs, :event_kind) || Support.string(attrs, :kind),
         occurred_at: Support.value(attrs, :occurred_at),
         summary: Support.string(attrs, :summary),
         payload: payload,
         metadata: metadata
       }}
    else
      _other -> {:error, :invalid_runtime_log_row}
    end
  end
end

defmodule AppKit.Core.RuntimeSurface.RuntimeLogPage do
  @moduledoc "Page of redacted runtime/operator log rows."

  alias AppKit.Core.RuntimeSurface.{RuntimeLogRow, Support}

  defstruct entries: [], total_count: 0, next_cursor: nil, has_more?: false, metadata: %{}

  @type t :: %__MODULE__{
          entries: [RuntimeLogRow.t()],
          total_count: non_neg_integer(),
          next_cursor: String.t() | nil,
          has_more?: boolean(),
          metadata: map()
        }

  def new(%__MODULE__{} = value), do: {:ok, value}

  def new(attrs) do
    with {:ok, attrs} <- Support.normalize(attrs),
         {:ok, entries} <- log_rows(Support.optional_list(attrs, :entries, [])),
         total_count when is_integer(total_count) <-
           Support.optional_non_negative_integer(attrs, :total_count, length(entries)),
         has_more? when is_boolean(has_more?) <- Support.boolean(attrs, :has_more?, false),
         metadata when is_map(metadata) <- Support.optional_map(attrs, :metadata, %{}) do
      {:ok,
       %__MODULE__{
         entries: entries,
         total_count: total_count,
         next_cursor: Support.string(attrs, :next_cursor),
         has_more?: has_more?,
         metadata: metadata
       }}
    else
      _other -> {:error, :invalid_runtime_log_page}
    end
  end

  defp log_rows(rows) when is_list(rows) do
    Enum.reduce_while(rows, {:ok, []}, fn row, {:ok, acc} ->
      case RuntimeLogRow.new(row) do
        {:ok, row} -> {:cont, {:ok, [row | acc]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, rows} -> {:ok, Enum.reverse(rows)}
      error -> error
    end
  end
end

defmodule AppKit.Core.RuntimeSurface.LiveEffectReceipt do
  @moduledoc "Provider live-effect proof state without raw provider material."

  alias AppKit.Core.RuntimeSurface.Support

  @statuses [
    :credential_present,
    :credential_redeemed,
    :provider_request_sent,
    :provider_response_received,
    :receipt_recorded,
    :product_readback_confirmed,
    :skipped,
    :denied,
    :failed
  ]
  defstruct [
    :effect_ref,
    :tenant_ref,
    :provider,
    :effect,
    :status,
    capability_ids: [],
    credential_present?: false,
    credential_redeemed?: false,
    provider_request_sent?: false,
    provider_response_received?: false,
    receipt_recorded?: false,
    product_readback_confirmed?: false,
    receipt_refs: %{},
    metadata: %{}
  ]

  @type t :: %__MODULE__{
          effect_ref: String.t(),
          tenant_ref: String.t() | nil,
          provider: String.t(),
          effect: String.t(),
          status:
            :credential_present
            | :credential_redeemed
            | :provider_request_sent
            | :provider_response_received
            | :receipt_recorded
            | :product_readback_confirmed
            | :skipped
            | :denied
            | :failed,
          capability_ids: [String.t()],
          credential_present?: boolean(),
          credential_redeemed?: boolean(),
          provider_request_sent?: boolean(),
          provider_response_received?: boolean(),
          receipt_recorded?: boolean(),
          product_readback_confirmed?: boolean(),
          receipt_refs: map(),
          metadata: map()
        }

  def new(%__MODULE__{} = value), do: {:ok, value}

  def new(attrs) do
    with {:ok, attrs} <- Support.normalize(attrs),
         :ok <- Support.reject_forbidden_material(attrs),
         {:ok, effect_ref} <- Support.required_string(attrs, :effect_ref),
         {:ok, provider} <- Support.required_string(attrs, :provider),
         {:ok, effect} <- Support.required_string(attrs, :effect),
         {:ok, status} <- Support.status(attrs, :status, @statuses),
         capability_ids <- Support.optional_list(attrs, :capability_ids, []),
         true <- Enum.all?(capability_ids, &is_binary/1),
         credential_present? when is_boolean(credential_present?) <-
           Support.boolean(attrs, :credential_present?, false),
         credential_redeemed? when is_boolean(credential_redeemed?) <-
           Support.boolean(attrs, :credential_redeemed?, false),
         provider_request_sent? when is_boolean(provider_request_sent?) <-
           Support.boolean(attrs, :provider_request_sent?, false),
         provider_response_received? when is_boolean(provider_response_received?) <-
           Support.boolean(attrs, :provider_response_received?, false),
         receipt_recorded? when is_boolean(receipt_recorded?) <-
           Support.boolean(attrs, :receipt_recorded?, false),
         product_readback_confirmed? when is_boolean(product_readback_confirmed?) <-
           Support.boolean(attrs, :product_readback_confirmed?, false),
         receipt_refs when is_map(receipt_refs) <- Support.optional_map(attrs, :receipt_refs, %{}),
         metadata when is_map(metadata) <- Support.optional_map(attrs, :metadata, %{}) do
      {:ok,
       %__MODULE__{
         effect_ref: effect_ref,
         tenant_ref: Support.string(attrs, :tenant_ref),
         provider: provider,
         effect: effect,
         status: status,
         capability_ids: capability_ids,
         credential_present?: credential_present?,
         credential_redeemed?: credential_redeemed?,
         provider_request_sent?: provider_request_sent?,
         provider_response_received?: provider_response_received?,
         receipt_recorded?: receipt_recorded?,
         product_readback_confirmed?: product_readback_confirmed?,
         receipt_refs: receipt_refs,
         metadata: metadata
       }}
    else
      _other -> {:error, :invalid_live_effect_receipt}
    end
  end
end
