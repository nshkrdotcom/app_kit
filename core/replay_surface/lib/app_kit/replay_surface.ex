defmodule AppKit.ReplaySurface do
  @moduledoc """
  DTO-only replay surface.
  """

  alias AITrace.ReplayContracts

  @drift_classes [
    :prompt_drift,
    :tool_call_drift,
    :guard_decision_drift,
    :memory_access_drift,
    :cost_attribution_drift,
    :latency_drift
  ]
  @raw_keys [
    :body,
    :raw_body,
    :payload,
    :raw_payload,
    :model_output,
    :provider_payload,
    :replay_divergence_excerpt,
    "body",
    "raw_body",
    "payload",
    "raw_payload",
    "model_output",
    "provider_payload",
    "replay_divergence_excerpt"
  ]

  defmodule ReplaySubmitRequest do
    @moduledoc "Replay submit request DTO."
    @enforce_keys [:request_ref, :replay_request]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            request_ref: String.t(),
            replay_request: ReplayContracts.ReplayRequest.t()
          }
  end

  defmodule ReplayBundleProjection do
    @moduledoc "Replay bundle projection DTO."
    @enforce_keys [
      :bundle_ref,
      :source_trace_ref,
      :replay_trace_ref,
      :decision_class,
      :divergence_refs
    ]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            bundle_ref: String.t(),
            source_trace_ref: String.t(),
            replay_trace_ref: String.t(),
            decision_class: atom(),
            divergence_refs: [String.t()]
          }
  end

  defmodule ReplayDivergenceProjection do
    @moduledoc "Replay divergence projection DTO."
    @enforce_keys [
      :divergence_ref,
      :phase,
      :severity,
      :redacted_excerpt_class,
      :remediation_class
    ]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            divergence_ref: String.t(),
            phase: atom(),
            severity: atom(),
            redacted_excerpt_class: atom(),
            remediation_class: atom()
          }
  end

  defmodule ReplayAcceptRequest do
    @moduledoc "Replay accept request DTO."
    @enforce_keys [:request_ref, :bundle_ref, :decision_evidence_ref]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            request_ref: String.t(),
            bundle_ref: String.t(),
            decision_evidence_ref: String.t()
          }
  end

  defmodule ReplayDriftProjection do
    @moduledoc "Replay drift projection DTO."
    @enforce_keys [:drift_signal_ref, :signal_class, :magnitude_class, :window_ref]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            drift_signal_ref: String.t(),
            signal_class: atom(),
            magnitude_class: String.t(),
            window_ref: String.t()
          }
  end

  @spec submit_request(map()) :: {:ok, ReplaySubmitRequest.t()} | {:error, term()}
  def submit_request(attrs) when is_map(attrs) do
    with :ok <- reject_raw(attrs),
         :ok <- required_strings(attrs, [:request_ref]),
         {:ok, request} <- attrs |> fetch(:replay_request) |> ReplayContracts.replay_request() do
      {:ok,
       %ReplaySubmitRequest{request_ref: fetch!(attrs, :request_ref), replay_request: request}}
    end
  end

  @spec bundle_projection(map()) :: {:ok, ReplayBundleProjection.t()} | {:error, term()}
  def bundle_projection(attrs) when is_map(attrs) do
    with :ok <- reject_raw(attrs),
         {:ok, bundle} <- ReplayContracts.replay_bundle(attrs) do
      {:ok,
       %ReplayBundleProjection{
         bundle_ref: bundle.trace_ref,
         source_trace_ref: bundle.source_trace_ref,
         replay_trace_ref: bundle.replay_trace_ref,
         decision_class: bundle.decision_class,
         divergence_refs: bundle.divergence_refs
       }}
    end
  end

  @spec divergence_projection(map()) :: {:ok, ReplayDivergenceProjection.t()} | {:error, term()}
  def divergence_projection(attrs) when is_map(attrs) do
    with :ok <- reject_raw(attrs),
         {:ok, divergence} <- ReplayContracts.replay_divergence(attrs) do
      {:ok,
       %ReplayDivergenceProjection{
         divergence_ref: divergence.divergence_ref,
         phase: divergence.phase,
         severity: divergence.severity,
         redacted_excerpt_class: divergence.redacted_excerpt_class,
         remediation_class: divergence.remediation_class
       }}
    end
  end

  @spec accept_request(map()) :: {:ok, ReplayAcceptRequest.t()} | {:error, term()}
  def accept_request(attrs) when is_map(attrs) do
    with :ok <- reject_raw(attrs),
         :ok <- required_strings(attrs, [:request_ref, :bundle_ref, :decision_evidence_ref]) do
      {:ok,
       %ReplayAcceptRequest{
         request_ref: fetch!(attrs, :request_ref),
         bundle_ref: fetch!(attrs, :bundle_ref),
         decision_evidence_ref: fetch!(attrs, :decision_evidence_ref)
       }}
    end
  end

  @spec drift_projection(map()) :: {:ok, ReplayDriftProjection.t()} | {:error, term()}
  def drift_projection(attrs) when is_map(attrs) do
    with :ok <- reject_raw(attrs),
         :ok <- required_strings(attrs, [:drift_signal_ref, :magnitude_class, :window_ref]),
         {:ok, signal_class} <- drift_class(fetch(attrs, :signal_class)) do
      {:ok,
       %ReplayDriftProjection{
         drift_signal_ref: fetch!(attrs, :drift_signal_ref),
         signal_class: signal_class,
         magnitude_class: fetch!(attrs, :magnitude_class),
         window_ref: fetch!(attrs, :window_ref)
       }}
    end
  end

  defp drift_class(signal_class) do
    if signal_class in @drift_classes do
      {:ok, signal_class}
    else
      {:error, :unknown_replay_drift_signal_class}
    end
  end

  defp reject_raw(attrs) do
    case Enum.find(@raw_keys, &Map.has_key?(attrs, &1)) do
      nil -> :ok
      key -> {:error, {:raw_replay_surface_payload_forbidden, key}}
    end
  end

  defp required_strings(attrs, fields) do
    case Enum.find(fields, &(not present_string?(fetch(attrs, &1)))) do
      nil -> :ok
      field -> {:error, {:missing_replay_surface_ref, field}}
    end
  end

  defp present_string?(value) when is_binary(value), do: String.trim(value) != ""
  defp present_string?(_value), do: false
  defp fetch!(attrs, field), do: fetch(attrs, field)
  defp fetch(attrs, field), do: Map.get(attrs, field) || Map.get(attrs, Atom.to_string(field))
end
