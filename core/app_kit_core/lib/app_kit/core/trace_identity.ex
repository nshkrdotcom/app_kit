defmodule AppKit.Core.TraceIdentity do
  @moduledoc """
  W3C trace-id validation and request-edge minting for AppKit.
  """

  @trace_id_length 32
  @zero_trace_id String.duplicate("0", @trace_id_length)
  @trace_id_pattern ~r/\A[0-9a-f]{32}\z/

  @type trust_posture :: :trusted | :untrusted

  @type edge_resolution :: %{
          trace_id: String.t(),
          client_trace_id: String.t() | nil,
          disposition: :minted | :preserved | :replaced
        }

  @spec mint() :: String.t()
  def mint do
    case :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower) do
      @zero_trace_id -> mint()
      trace_id -> trace_id
    end
  end

  @spec valid?(term()) :: boolean()
  def valid?(value) when is_binary(value) do
    Regex.match?(@trace_id_pattern, value) and value != @zero_trace_id
  end

  def valid?(_value), do: false

  @spec ensure(term()) :: {:ok, String.t()} | {:error, :invalid_trace_id}
  def ensure(nil), do: {:ok, mint()}

  def ensure(value) when is_binary(value) do
    if valid?(value), do: {:ok, value}, else: {:error, :invalid_trace_id}
  end

  def ensure(_value), do: {:error, :invalid_trace_id}

  @spec ensure_optional(term()) :: {:ok, String.t() | nil} | {:error, :invalid_trace_id}
  def ensure_optional(nil), do: {:ok, nil}

  def ensure_optional(value) when is_binary(value) do
    if valid?(value), do: {:ok, value}, else: {:error, :invalid_trace_id}
  end

  def ensure_optional(_value), do: {:error, :invalid_trace_id}

  @spec resolve_edge_trace(term(), keyword()) ::
          {:ok, edge_resolution()} | {:error, :invalid_trace_id}
  def resolve_edge_trace(trace_id, opts \\ []) do
    trust = normalize_trust(Keyword.get(opts, :trust, :untrusted))

    cond do
      is_nil(trace_id) ->
        {:ok, %{trace_id: mint(), client_trace_id: nil, disposition: :minted}}

      not is_binary(trace_id) ->
        {:error, :invalid_trace_id}

      not valid?(trace_id) ->
        {:error, :invalid_trace_id}

      trust == :trusted ->
        {:ok, %{trace_id: trace_id, client_trace_id: nil, disposition: :preserved}}

      true ->
        {:ok, %{trace_id: mint(), client_trace_id: trace_id, disposition: :replaced}}
    end
  end

  @spec normalize_trust(term()) :: trust_posture()
  def normalize_trust(:trusted), do: :trusted
  def normalize_trust("trusted"), do: :trusted
  def normalize_trust(true), do: :trusted
  def normalize_trust(_value), do: :untrusted
end
