defmodule AppKit.Core.Evolution.SurfaceError do
  @moduledoc "Product-safe Chassis Evolution surface error."

  @derive {Inspect, only: [:code, :message, :detail, :retry_after_ms]}
  @enforce_keys [:code, :message]
  defstruct [:code, :message, detail: %{}, retry_after_ms: nil]

  @type t :: %__MODULE__{
          code: atom(),
          message: String.t(),
          detail: map(),
          retry_after_ms: non_neg_integer() | nil
        }

  @spec new(map() | keyword()) :: {:ok, t()} | {:error, :invalid_surface_error}
  def new(attrs) when is_map(attrs) or is_list(attrs) do
    attrs = attrs |> Map.new() |> normalize_keys()

    with code when is_atom(code) <- Map.get(attrs, :code),
         message when is_binary(message) and message != "" <- Map.get(attrs, :message),
         detail when is_map(detail) <- Map.get(attrs, :detail, %{}),
         retry_after_ms <- Map.get(attrs, :retry_after_ms),
         true <- is_nil(retry_after_ms) or valid_retry_after?(retry_after_ms) do
      {:ok,
       %__MODULE__{
         code: code,
         message: message,
         detail: detail,
         retry_after_ms: retry_after_ms
       }}
    else
      _ -> {:error, :invalid_surface_error}
    end
  end

  @spec new!(map() | keyword()) :: t()
  def new!(attrs) do
    case new(attrs) do
      {:ok, error} ->
        error

      {:error, reason} ->
        raise ArgumentError, message: "invalid evolution surface error: #{reason}"
    end
  end

  defp normalize_keys(attrs) do
    Map.new(attrs, fn {key, value} -> {normalize_key(key), value} end)
  end

  defp normalize_key(key) when is_atom(key), do: key
  defp normalize_key(key) when is_binary(key), do: String.to_existing_atom(key)
  defp normalize_key(key), do: key

  defp valid_retry_after?(value), do: is_integer(value) and value >= 0
end

defmodule AppKit.Core.Evolution.DTO.RedactedDiffRef do
  @moduledoc "Reference to lower-read diff material without exposing raw diff bytes."

  alias AppKit.Core.Evolution.SurfaceError

  @derive {Inspect, only: [:diff_ref, :digest_ref, :lower_read_lease_ref, :lease_required?]}
  @enforce_keys [:diff_ref]
  defstruct [:diff_ref, :digest_ref, :lower_read_lease_ref, lease_required?: true]

  @type t :: %__MODULE__{
          diff_ref: String.t(),
          digest_ref: String.t() | nil,
          lower_read_lease_ref: String.t() | nil,
          lease_required?: boolean()
        }

  @spec new(String.t() | map() | keyword()) :: {:ok, t()} | {:error, SurfaceError.t()}
  def new(diff_ref) when is_binary(diff_ref), do: new(%{diff_ref: diff_ref})

  def new(attrs) when is_map(attrs) or is_list(attrs) do
    attrs = attrs |> Map.new() |> normalize_keys()

    with :ok <- required_binary(attrs, :diff_ref),
         :ok <- optional_binary(attrs, :digest_ref),
         :ok <- optional_binary(attrs, :lower_read_lease_ref),
         :ok <- optional_boolean(attrs, :lease_required?) do
      {:ok,
       %__MODULE__{
         diff_ref: Map.fetch!(attrs, :diff_ref),
         digest_ref: Map.get(attrs, :digest_ref),
         lower_read_lease_ref: Map.get(attrs, :lower_read_lease_ref),
         lease_required?: Map.get(attrs, :lease_required?, true)
       }}
    end
  end

  def new(_attrs), do: invalid(:diff_ref, "diff_ref is required")

  @spec new!(String.t() | map() | keyword()) :: t()
  def new!(attrs) do
    case new(attrs) do
      {:ok, ref} -> ref
      {:error, error} -> raise ArgumentError, message: error.message
    end
  end

  defp normalize_keys(attrs) do
    Map.new(attrs, fn {key, value} -> {normalize_key(key), value} end)
  end

  defp normalize_key(key) when is_atom(key), do: key
  defp normalize_key("lease_required?"), do: :lease_required?
  defp normalize_key(key) when is_binary(key), do: String.to_existing_atom(key)
  defp normalize_key(key), do: key

  defp required_binary(attrs, key) do
    case Map.get(attrs, key) do
      value when is_binary(value) and value != "" -> :ok
      _ -> invalid(key, "#{key} is required")
    end
  end

  defp optional_binary(attrs, key) do
    case Map.get(attrs, key) do
      nil -> :ok
      value when is_binary(value) -> :ok
      _ -> invalid(key, "#{key} must be a string")
    end
  end

  defp optional_boolean(attrs, key) do
    case Map.get(attrs, key) do
      nil -> :ok
      value when is_boolean(value) -> :ok
      _ -> invalid(key, "#{key} must be a boolean")
    end
  end

  defp invalid(field, message) do
    {:error,
     SurfaceError.new!(%{
       code: :invalid_dto,
       message: message,
       detail: %{field: field}
     })}
  end
end

defmodule AppKit.Core.Evolution.DTO.ScoreSummary do
  @moduledoc "Bounded score matrix summary for Chassis Evolution candidates."

  alias AppKit.Core.Evolution.SurfaceError

  @derive {Inspect, only: [:overall_score, :dimensions, :policy_refs]}
  defstruct overall_score: nil, dimensions: %{}, policy_refs: []

  @type t :: %__MODULE__{
          overall_score: number() | nil,
          dimensions: map(),
          policy_refs: [String.t()]
        }

  @spec new(map() | keyword() | nil) :: {:ok, t()} | {:error, SurfaceError.t()}
  def new(nil), do: {:ok, %__MODULE__{}}

  def new(attrs) when is_map(attrs) or is_list(attrs) do
    attrs = attrs |> Map.new() |> normalize_keys()
    dimensions = Map.get(attrs, :dimensions, %{})
    policy_refs = Map.get(attrs, :policy_refs, [])

    with true <-
           is_nil(Map.get(attrs, :overall_score)) or is_number(Map.get(attrs, :overall_score)),
         true <- is_map(dimensions),
         true <- is_list(policy_refs) and Enum.all?(policy_refs, &is_binary/1) do
      {:ok,
       %__MODULE__{
         overall_score: Map.get(attrs, :overall_score),
         dimensions: dimensions,
         policy_refs: policy_refs
       }}
    else
      _ ->
        {:error,
         SurfaceError.new!(%{
           code: :invalid_dto,
           message: "score_summary is invalid",
           detail: %{field: :score_summary}
         })}
    end
  end

  def new(_attrs) do
    {:error,
     SurfaceError.new!(%{
       code: :invalid_dto,
       message: "score_summary is invalid",
       detail: %{field: :score_summary}
     })}
  end

  @spec new!(map() | keyword() | nil) :: t()
  def new!(attrs) do
    case new(attrs) do
      {:ok, summary} -> summary
      {:error, error} -> raise ArgumentError, message: error.message
    end
  end

  defp normalize_keys(attrs) do
    Map.new(attrs, fn {key, value} -> {normalize_key(key), value} end)
  end

  defp normalize_key(key) when is_atom(key), do: key
  defp normalize_key(key) when is_binary(key), do: String.to_existing_atom(key)
  defp normalize_key(key), do: key
end

defmodule AppKit.Core.Evolution.DTO.EvolutionBatchSummary do
  @moduledoc "Product-safe Chassis Evolution failure batch summary."

  alias AppKit.Core.Evolution.DTO.Support

  @derive {Inspect,
           only: [
             :batch_ref,
             :tenant_ref,
             :summary,
             :candidate_count,
             :receipt_refs,
             :redaction_posture
           ]}
  @enforce_keys [:batch_ref, :tenant_ref, :summary]
  defstruct [
    :batch_ref,
    :tenant_ref,
    :summary,
    candidate_count: 0,
    receipt_refs: [],
    redaction_posture: :redacted
  ]

  @type t :: %__MODULE__{}

  def new(attrs), do: Support.struct_new(__MODULE__, attrs, [:batch_ref, :tenant_ref, :summary])
  def new!(attrs), do: Support.struct_new!(__MODULE__, attrs, [:batch_ref, :tenant_ref, :summary])
end

defmodule AppKit.Core.Evolution.DTO.EvolutionBatchPage do
  @moduledoc "Bounded page of Chassis Evolution failure batch summaries."

  alias AppKit.Core.Evolution.DTO.{EvolutionBatchSummary, Support}
  alias AppKit.Core.Evolution.SurfaceError

  @derive {Inspect, only: [:batches, :next_cursor, :limit]}
  defstruct batches: [], next_cursor: nil, limit: 10

  @type t :: %__MODULE__{
          batches: [EvolutionBatchSummary.t()],
          next_cursor: String.t() | nil,
          limit: pos_integer()
        }

  def new(attrs) when is_map(attrs) or is_list(attrs) do
    attrs = attrs |> Map.new() |> Support.normalize_keys()
    limit = Map.get(attrs, :limit, 10)

    with true <- is_integer(limit) and limit > 0,
         true <- is_nil(Map.get(attrs, :next_cursor)) or is_binary(Map.get(attrs, :next_cursor)),
         {:ok, batches} <- batches(Map.get(attrs, :batches, [])) do
      {:ok,
       %__MODULE__{batches: batches, next_cursor: Map.get(attrs, :next_cursor), limit: limit}}
    else
      _ ->
        {:error,
         SurfaceError.new!(%{code: :invalid_dto, message: "evolution batch page is invalid"})}
    end
  end

  def new(_attrs),
    do:
      {:error,
       SurfaceError.new!(%{code: :invalid_dto, message: "evolution batch page is invalid"})}

  def new!(attrs) do
    case new(attrs) do
      {:ok, page} -> page
      {:error, error} -> raise ArgumentError, message: error.message
    end
  end

  defp batches(values) when is_list(values) do
    Enum.reduce_while(values, {:ok, []}, fn value, {:ok, acc} ->
      case EvolutionBatchSummary.new(value) do
        {:ok, batch} -> {:cont, {:ok, [batch | acc]}}
        {:error, error} -> {:halt, {:error, error}}
      end
    end)
    |> case do
      {:ok, batches} -> {:ok, Enum.reverse(batches)}
      error -> error
    end
  end

  defp batches(_values),
    do: {:error, SurfaceError.new!(%{code: :invalid_dto, message: "batches must be a list"})}
end

defmodule AppKit.Core.Evolution.DTO.EvolutionStatus do
  @moduledoc "Product-safe Chassis Evolution status projection."

  alias AppKit.Core.Evolution.DTO.Support

  @derive {Inspect,
           only: [
             :evolution_ref,
             :state,
             :candidate_refs,
             :receipt_refs,
             :trace_refs,
             :redaction_posture
           ]}
  @enforce_keys [:evolution_ref, :state]
  defstruct [
    :evolution_ref,
    :state,
    candidate_refs: [],
    receipt_refs: [],
    trace_refs: [],
    redaction_posture: :redacted
  ]

  @type t :: %__MODULE__{}

  def new(attrs), do: Support.struct_new(__MODULE__, attrs, [:evolution_ref, :state])
  def new!(attrs), do: Support.struct_new!(__MODULE__, attrs, [:evolution_ref, :state])
end

defmodule AppKit.Core.Evolution.DTO.CandidateSummary do
  @moduledoc "Product-safe Chassis Evolution candidate summary."

  alias AppKit.Core.Evolution.DTO.{RedactedDiffRef, ScoreSummary, Support}
  alias AppKit.Core.Evolution.SurfaceError

  @derive {Inspect,
           only: [
             :candidate_ref,
             :evolution_ref,
             :state,
             :score_summary,
             :diff_ref_redacted,
             :receipt_refs,
             :trace_refs,
             :redaction_posture,
             :operator_action_hints
           ]}
  @enforce_keys [:candidate_ref, :diff_ref_redacted]
  defstruct [
    :candidate_ref,
    :evolution_ref,
    :state,
    :score_summary,
    :diff_ref_redacted,
    receipt_refs: [],
    trace_refs: [],
    redaction_posture: :redacted,
    operator_action_hints: []
  ]

  @type t :: %__MODULE__{}

  def new(attrs) when is_map(attrs) or is_list(attrs) do
    attrs = attrs |> Map.new() |> Support.normalize_keys() |> Support.drop_private_keys()

    with :ok <- Support.required_binary(attrs, :candidate_ref),
         {:ok, diff_ref} <- diff_ref(attrs),
         {:ok, score_summary} <- ScoreSummary.new(Map.get(attrs, :score_summary)),
         :ok <- Support.list_of_strings(attrs, :receipt_refs),
         :ok <- Support.list_of_strings(attrs, :trace_refs) do
      {:ok,
       %__MODULE__{
         candidate_ref: Map.fetch!(attrs, :candidate_ref),
         evolution_ref: Map.get(attrs, :evolution_ref),
         state: Map.get(attrs, :state),
         score_summary: score_summary,
         diff_ref_redacted: diff_ref,
         receipt_refs: Map.get(attrs, :receipt_refs, []),
         trace_refs: Map.get(attrs, :trace_refs, []),
         redaction_posture: Map.get(attrs, :redaction_posture, :redacted),
         operator_action_hints: Map.get(attrs, :operator_action_hints, [])
       }}
    end
  end

  def new(_attrs), do: Support.invalid(:candidate_ref, "candidate_ref is required")

  def new!(attrs) do
    case new(attrs) do
      {:ok, summary} -> summary
      {:error, error} -> raise ArgumentError, message: error.message
    end
  end

  defp diff_ref(attrs) do
    case Map.get(attrs, :diff_ref_redacted) || Map.get(attrs, :diff_ref) do
      %RedactedDiffRef{} = diff_ref ->
        {:ok, diff_ref}

      value when is_binary(value) ->
        RedactedDiffRef.new(value)

      value when is_map(value) or is_list(value) ->
        RedactedDiffRef.new(value)

      nil ->
        {:error,
         SurfaceError.new!(%{code: :invalid_dto, message: "diff_ref_redacted is required"})}
    end
  end
end

defmodule AppKit.Core.Evolution.DTO.TrialSummary do
  @moduledoc "Product-safe replay/trial summary."

  alias AppKit.Core.Evolution.DTO.{ScoreSummary, Support}

  @derive {Inspect,
           only: [:trial_ref, :candidate_ref, :state, :score_summary, :receipt_refs, :trace_refs]}
  @enforce_keys [:trial_ref, :candidate_ref, :state]
  defstruct [:trial_ref, :candidate_ref, :state, :score_summary, receipt_refs: [], trace_refs: []]

  @type t :: %__MODULE__{}

  def new(attrs) when is_map(attrs) or is_list(attrs) do
    attrs = attrs |> Map.new() |> Support.normalize_keys() |> Support.drop_private_keys()

    with {:ok, score_summary} <- ScoreSummary.new(Map.get(attrs, :score_summary)),
         {:ok, trial} <-
           Support.struct_new(__MODULE__, attrs, [:trial_ref, :candidate_ref, :state]) do
      {:ok, %{trial | score_summary: score_summary}}
    end
  end

  def new(attrs), do: Support.struct_new(__MODULE__, attrs, [:trial_ref, :candidate_ref, :state])

  def new!(attrs),
    do: Support.struct_new!(__MODULE__, attrs, [:trial_ref, :candidate_ref, :state])
end

defmodule AppKit.Core.Evolution.DTO.SwapStatus do
  @moduledoc "Product-safe state-preserving swap status."

  alias AppKit.Core.Evolution.DTO.Support

  @derive {Inspect, only: [:swap_ref, :state, :receipt_refs, :health_status, :rollback_ref]}
  @enforce_keys [:swap_ref, :state]
  defstruct [:swap_ref, :state, :health_status, :rollback_ref, receipt_refs: []]

  @type t :: %__MODULE__{}

  def new(attrs), do: Support.struct_new(__MODULE__, attrs, [:swap_ref, :state])
  def new!(attrs), do: Support.struct_new!(__MODULE__, attrs, [:swap_ref, :state])
end

defmodule AppKit.Core.Evolution.DTO.PromotionRequestResult do
  @moduledoc "Result of requesting candidate promotion."

  alias AppKit.Core.Evolution.DTO.Support

  @derive {Inspect, only: [:candidate_ref, :status, :workflow_ref, :receipt_refs]}
  @enforce_keys [:candidate_ref, :status]
  defstruct [:candidate_ref, :status, :workflow_ref, receipt_refs: []]

  @type t :: %__MODULE__{}

  def new(attrs), do: Support.struct_new(__MODULE__, attrs, [:candidate_ref, :status])
  def new!(attrs), do: Support.struct_new!(__MODULE__, attrs, [:candidate_ref, :status])
end

defmodule AppKit.Core.Evolution.DTO.OperatorConsentResult do
  @moduledoc "Result of recording explicit operator consent."

  alias AppKit.Core.Evolution.DTO.Support

  @derive {Inspect, only: [:candidate_ref, :decision, :consent_ref, :signal_ref, :recorded_at]}
  @enforce_keys [:candidate_ref, :decision, :consent_ref]
  defstruct [:candidate_ref, :decision, :consent_ref, :signal_ref, :recorded_at, receipt_refs: []]

  @type t :: %__MODULE__{}

  def new(attrs),
    do: Support.struct_new(__MODULE__, attrs, [:candidate_ref, :decision, :consent_ref])

  def new!(attrs),
    do: Support.struct_new!(__MODULE__, attrs, [:candidate_ref, :decision, :consent_ref])
end

defmodule AppKit.Core.Evolution.DTO.Support do
  @moduledoc false

  alias AppKit.Core.Evolution.SurfaceError

  @private_keys [
    :raw_diff,
    :raw_prompt,
    :private_prompt,
    :private_transcript,
    :provider_payload,
    :credential,
    :credentials,
    :secret,
    :state_volume_path,
    "raw_diff",
    "raw_prompt",
    "private_prompt",
    "private_transcript",
    "provider_payload",
    "credential",
    "credentials",
    "secret",
    "state_volume_path"
  ]

  def struct_new(module, attrs, required_fields) when is_map(attrs) or is_list(attrs) do
    attrs = attrs |> Map.new() |> normalize_keys() |> drop_private_keys()

    with :ok <- require_fields(attrs, required_fields),
         :ok <- list_of_strings(attrs, :receipt_refs),
         :ok <- list_of_strings(attrs, :trace_refs) do
      {:ok, struct(module, attrs)}
    end
  end

  def struct_new(_module, _attrs, [field | _]), do: invalid(field, "#{field} is required")

  def struct_new!(module, attrs, required_fields) do
    case struct_new(module, attrs, required_fields) do
      {:ok, value} -> value
      {:error, error} -> raise ArgumentError, message: error.message
    end
  end

  def normalize_keys(attrs) do
    Map.new(attrs, fn {key, value} -> {normalize_key(key), value} end)
  end

  def drop_private_keys(attrs), do: Map.drop(attrs, @private_keys)

  def required_binary(attrs, key) do
    case Map.get(attrs, key) do
      value when is_binary(value) and value != "" -> :ok
      _ -> invalid(key, "#{key} is required")
    end
  end

  def list_of_strings(attrs, key) do
    case Map.get(attrs, key, []) do
      values when is_list(values) ->
        if Enum.all?(values, &is_binary/1),
          do: :ok,
          else: invalid(key, "#{key} must contain strings")

      _ ->
        invalid(key, "#{key} must be a list")
    end
  end

  def invalid(field, message) do
    {:error, SurfaceError.new!(%{code: :invalid_dto, message: message, detail: %{field: field}})}
  end

  defp require_fields(_attrs, []), do: :ok

  defp require_fields(attrs, [field | rest]) do
    case Map.get(attrs, field) do
      nil -> invalid(field, "#{field} is required")
      "" -> invalid(field, "#{field} is required")
      _value -> require_fields(attrs, rest)
    end
  end

  defp normalize_key(key) when is_atom(key), do: key

  defp normalize_key(key) when is_binary(key) do
    String.to_existing_atom(key)
  rescue
    ArgumentError -> key
  end

  defp normalize_key(key), do: key
end

defmodule AppKit.EvolutionSurface.RedactedDiffRef do
  @moduledoc "Backward-compatible alias for the evolution DTO redacted diff reference."

  defdelegate new(attrs), to: AppKit.Core.Evolution.DTO.RedactedDiffRef
  defdelegate new!(attrs), to: AppKit.Core.Evolution.DTO.RedactedDiffRef
end
