defmodule AppKit.Core.PersistencePosture do
  @moduledoc """
  AppKit-owned persistence posture for product-safe projections.

  The posture is projection evidence only. It does not authorize lower writes,
  provider effects, or runtime readback.
  """

  @profiles %{
    mickey_mouse: %{
      persistence_profile_ref: "persistence-profile://mickey-mouse",
      persistence_tier_ref: "persistence-tier://memory-ephemeral",
      capture_level_ref: "capture-level://off",
      store_set_ref: "store-set://memory/ref-only",
      retention_policy_ref: "retention://lost-on-process-exit",
      debug_tap_ref: "debug-tap://noop",
      durable?: false,
      retained?: true
    },
    memory_debug: %{
      persistence_profile_ref: "persistence-profile://memory-debug",
      persistence_tier_ref: "persistence-tier://memory-ephemeral",
      capture_level_ref: "capture-level://redacted-debug",
      store_set_ref: "store-set://memory/redacted-ring",
      retention_policy_ref: "retention://lost-on-process-exit",
      debug_tap_ref: "debug-tap://memory-ring",
      durable?: false,
      retained?: true
    },
    off: %{
      persistence_profile_ref: "persistence-profile://projection-off",
      persistence_tier_ref: "persistence-tier://off",
      capture_level_ref: "capture-level://off",
      store_set_ref: "store-set://off",
      retention_policy_ref: "retention://disabled",
      debug_tap_ref: "debug-tap://noop",
      durable?: false,
      retained?: false
    },
    durable_projection: %{
      persistence_profile_ref: "persistence-profile://durable-projection",
      persistence_tier_ref: "persistence-tier://durable",
      capture_level_ref: "capture-level://redacted-summary",
      store_set_ref: "store-set://durable/redacted-projection",
      retention_policy_ref: "retention://operator-configured",
      debug_tap_ref: "debug-tap://noop",
      durable?: true,
      retained?: true
    }
  }

  @components %{
    authority_projection: "component://app-kit/authority-projection",
    headless_surface: "component://app-kit/headless-surface",
    runtime_projection: "component://app-kit/runtime-projection",
    evidence_audit: "component://app-kit/evidence-audit",
    projection_bridge: "component://app-kit/projection-bridge"
  }

  @profile_lookup %{
    "mickey_mouse" => :mickey_mouse,
    "memory-default" => :mickey_mouse,
    "persistence://memory/default" => :mickey_mouse,
    "persistence-profile://mickey-mouse" => :mickey_mouse,
    "memory_debug" => :memory_debug,
    "persistence-profile://memory-debug" => :memory_debug,
    "off" => :off,
    "persistence-profile://projection-off" => :off,
    "durable_projection" => :durable_projection,
    "persistence-profile://durable-projection" => :durable_projection
  }

  @unsupported_profile_strings [
    "local_restart_safe",
    "local-restart-safe",
    "integration_postgres",
    "integration-postgres",
    "ops_durable",
    "ops-durable",
    "full_debug_tracked",
    "full-debug-tracked"
  ]

  @type component ::
          :authority_projection
          | :headless_surface
          | :runtime_projection
          | :evidence_audit
          | :projection_bridge

  @type t :: %{
          component_ref: String.t(),
          persistence_profile_ref: String.t(),
          persistence_tier_ref: String.t(),
          capture_level_ref: String.t(),
          store_set_ref: String.t(),
          store_partition_ref: String.t(),
          retention_policy_ref: String.t(),
          debug_tap_ref: String.t(),
          persistence_receipt_ref: String.t(),
          durable?: boolean(),
          retained?: boolean(),
          raw_payload_persistence?: false
        }

  @spec memory(component()) :: t()
  def memory(component), do: resolve(component, %{})

  @spec off(component()) :: t()
  def off(component), do: resolve(component, %{persistence_profile: :off})

  @spec durable(component()) :: t()
  def durable(component), do: resolve(component, %{persistence_profile: :durable_projection})

  @spec resolve(component(), map() | keyword() | nil) :: t()
  def resolve(component, attrs \\ %{}) do
    attrs = normalize_attrs(attrs)

    case Map.get(attrs, :persistence_posture) do
      posture when is_map(posture) ->
        posture
        |> normalize_attrs()
        |> Map.merge(base(component, profile_from_attrs(posture)), fn _key, value, _base ->
          value
        end)
        |> ensure_component(component)

      _other ->
        base(component, profile_from_attrs(attrs))
    end
  end

  @spec retained?(t()) :: boolean()
  def retained?(posture), do: Map.get(posture, :retained?) == true

  @spec raw_payload_persistence?(t()) :: false
  def raw_payload_persistence?(_posture), do: false

  @spec debug_tap_failed(map()) :: map()
  def debug_tap_failed(posture) when is_map(posture) do
    posture
    |> Map.put(:debug_tap_result, :failed_non_mutating)
    |> Map.put(:debug_sidecar_mutated_state?, false)
  end

  defp base(component, profile) do
    profile_values = Map.fetch!(@profiles, profile)
    component_ref = Map.fetch!(@components, component)

    profile_values
    |> Map.put(:component_ref, component_ref)
    |> Map.put(:store_partition_ref, component_ref <> "/tenant-ref")
    |> Map.put(:persistence_receipt_ref, receipt_ref(component, profile))
    |> Map.put(:raw_payload_persistence?, false)
  end

  defp ensure_component(posture, component) do
    posture
    |> Map.put_new(:component_ref, Map.fetch!(@components, component))
    |> Map.put_new(:store_partition_ref, Map.fetch!(@components, component) <> "/tenant-ref")
    |> Map.put_new(:persistence_receipt_ref, receipt_ref(component, :mickey_mouse))
    |> Map.put(:raw_payload_persistence?, false)
  end

  defp profile_from_attrs(attrs) do
    attrs = normalize_attrs(attrs)

    attrs
    |> Map.get(:persistence_profile, Map.get(attrs, :persistence_profile_ref, :mickey_mouse))
    |> normalize_profile()
  end

  defp normalize_profile(profile) when is_atom(profile) and is_map_key(@profiles, profile),
    do: profile

  defp normalize_profile(nil), do: :mickey_mouse

  defp normalize_profile(profile) when is_atom(profile) do
    unsupported_profile!(profile)
  end

  defp normalize_profile(profile) when is_binary(profile) do
    profile = String.trim(profile)

    cond do
      Map.has_key?(@profile_lookup, profile) -> Map.fetch!(@profile_lookup, profile)
      String.contains?(profile, "projection-off") -> :off
      String.contains?(profile, "memory-debug") -> :memory_debug
      unsupported_profile?(profile) -> unsupported_profile!(profile)
      String.contains?(profile, "durable") -> :durable_projection
      profile == "" -> :mickey_mouse
      true -> unsupported_profile!(profile)
    end
  end

  defp normalize_profile(profile), do: unsupported_profile!(profile)

  defp unsupported_profile?(profile) when is_binary(profile) do
    Enum.any?(@unsupported_profile_strings, &String.contains?(profile, &1))
  end

  defp unsupported_profile!(profile) do
    raise ArgumentError,
          "unsupported persistence profile #{inspect(profile)}; durable adapters require explicit supported AppKit preflight"
  end

  defp normalize_attrs(nil), do: %{}
  defp normalize_attrs(attrs) when is_list(attrs), do: attrs |> Map.new() |> normalize_attrs()

  defp normalize_attrs(attrs) when is_map(attrs) do
    Map.new(attrs, fn
      {key, value} when is_binary(key) -> {string_key(key), value}
      {key, value} -> {key, value}
    end)
  end

  defp normalize_attrs(_attrs), do: %{}

  defp string_key("persistence_profile"), do: :persistence_profile
  defp string_key("persistence_profile_ref"), do: :persistence_profile_ref
  defp string_key("persistence_posture"), do: :persistence_posture
  defp string_key("persistence_tier_ref"), do: :persistence_tier_ref
  defp string_key("capture_level_ref"), do: :capture_level_ref
  defp string_key("store_set_ref"), do: :store_set_ref
  defp string_key("store_partition_ref"), do: :store_partition_ref
  defp string_key("retention_policy_ref"), do: :retention_policy_ref
  defp string_key("debug_tap_ref"), do: :debug_tap_ref
  defp string_key("persistence_receipt_ref"), do: :persistence_receipt_ref
  defp string_key("retained?"), do: :retained?
  defp string_key("durable?"), do: :durable?
  defp string_key(key), do: key

  defp receipt_ref(component, profile) do
    "persistence-receipt://app-kit/#{component}/#{profile}"
  end
end
