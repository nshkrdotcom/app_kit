defmodule AppKit.ReplayViewer do
  @moduledoc """
  Replay viewer contracts over AppKit replay DTOs and bounded trace exports.
  """

  alias AppKit.Web.Components

  defmodule ReplayWaterfall do
    @moduledoc "Replay waterfall render state."
    @enforce_keys [
      :viewer_ref,
      :tenant_ref,
      :source_trace_ref,
      :replay_trace_ref,
      :decision_class,
      :divergence_markers,
      :side_effect_posture,
      :components
    ]
    defstruct @enforce_keys

    @type t :: %__MODULE__{}
  end

  @raw_keys [
    :body,
    :raw_body,
    :payload,
    :raw_payload,
    :prompt_body,
    :memory_body,
    :provider_payload,
    :provider_response,
    :model_output,
    :tool_output,
    :provider_invoker,
    :network_invoker,
    "body",
    "raw_body",
    "payload",
    "raw_payload",
    "prompt_body",
    "memory_body",
    "provider_payload",
    "provider_response",
    "model_output",
    "tool_output",
    "provider_invoker",
    "network_invoker"
  ]

  @spec waterfall(map()) :: {:ok, ReplayWaterfall.t()} | {:error, term()}
  def waterfall(attrs) when is_map(attrs) do
    with :ok <- reject_raw(attrs),
         :ok <- Components.reject_raw_assigns(attrs),
         {:ok, viewer_ref} <- required_string(attrs, :viewer_ref),
         {:ok, tenant_ref} <- required_string(attrs, :tenant_ref),
         {:ok, source_trace_ref} <- required_string(attrs, :source_trace_ref),
         {:ok, replay_trace_ref} <- required_string(attrs, :replay_trace_ref),
         {:ok, decision_class} <- decision_class(attrs),
         {:ok, markers} <- markers(attrs),
         {:ok, components} <- components(source_trace_ref, replay_trace_ref, decision_class) do
      {:ok,
       %ReplayWaterfall{
         viewer_ref: viewer_ref,
         tenant_ref: tenant_ref,
         source_trace_ref: source_trace_ref,
         replay_trace_ref: replay_trace_ref,
         decision_class: decision_class,
         divergence_markers: markers,
         side_effect_posture: :suppressed_view_only,
         components: components
       }}
    end
  end

  def waterfall(_attrs), do: {:error, :invalid_replay_viewer_attrs}

  defp components(source_trace_ref, replay_trace_ref, decision_class) do
    with {:ok, source} <- Components.ref_badge("Source trace", source_trace_ref),
         {:ok, replay} <- Components.ref_badge("Replay trace", replay_trace_ref),
         {:ok, decision} <- Components.decision_class("Replay decision", decision_class) do
      {:ok, [source, replay, decision]}
    end
  end

  defp markers(attrs) do
    markers = fetch(attrs, :divergence_markers, [])

    if is_list(markers) and Enum.all?(markers, &safe_marker?/1) do
      {:ok, markers}
    else
      {:error, :invalid_replay_divergence_marker}
    end
  end

  defp safe_marker?(marker) when is_map(marker) do
    required_present?(marker, [:divergence_ref, :phase, :severity, :redacted_excerpt_class])
  end

  defp safe_marker?(_marker), do: false

  defp decision_class(attrs) do
    case fetch(attrs, :decision_class) do
      value when value in [:clean, :diverged, :denied, :inconclusive] -> {:ok, value}
      value when value in ["clean", "diverged", "denied", "inconclusive"] -> {:ok, value}
      _value -> {:error, :invalid_replay_decision_class}
    end
  end

  defp reject_raw(attrs) do
    case Enum.find(@raw_keys, &Map.has_key?(attrs, &1)) do
      nil -> :ok
      key -> {:error, {:raw_replay_viewer_payload_forbidden, key}}
    end
  end

  defp required_present?(attrs, fields) do
    Enum.all?(fields, &present_string?(fetch(attrs, &1)))
  end

  defp required_string(attrs, field) do
    case fetch(attrs, field) do
      value when is_binary(value) and value != "" -> {:ok, value}
      _value -> {:error, {:missing_replay_viewer_ref, field}}
    end
  end

  defp present_string?(value), do: is_binary(value) and String.trim(value) != ""
  defp fetch(attrs, field), do: fetch(attrs, field, nil)

  defp fetch(attrs, field, default),
    do: Map.get(attrs, field) || Map.get(attrs, Atom.to_string(field), default)
end
