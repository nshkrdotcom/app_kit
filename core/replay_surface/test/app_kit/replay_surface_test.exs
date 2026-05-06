defmodule AppKit.ReplaySurfaceTest do
  use ExUnit.Case, async: true

  alias AppKit.ReplaySurface

  test "builds replay projections from contract-shaped refs" do
    assert {:ok, projection} =
             ReplaySurface.bundle_projection(%{
               tenant_ref: "tenant://a",
               authority_ref: "authority://a",
               installation_ref: "installation://a",
               idempotency_key: "idem-replay",
               trace_ref: "replay-bundle://a",
               source_trace_ref: "trace://source",
               replay_trace_ref: "trace://replay",
               divergence_refs: ["replay-divergence://a"],
               decision_class: :diverged,
               cost_class: :replay,
               operator_action: "review",
               release_manifest_ref: "release://phase-c"
             })

    assert projection.decision_class == :diverged

    assert {:ok, drift} =
             ReplaySurface.drift_projection(%{
               drift_signal_ref: "drift-signal://a",
               signal_class: :latency_drift,
               magnitude_class: "bounded_delta",
               window_ref: "drift-window://a"
             })

    assert drift.signal_class == :latency_drift
  end

  test "rejects raw replay payloads and unknown drift classes" do
    assert {:error, {:raw_replay_surface_payload_forbidden, :model_output}} =
             ReplaySurface.drift_projection(%{
               drift_signal_ref: "drift-signal://a",
               signal_class: :latency_drift,
               magnitude_class: "bounded_delta",
               window_ref: "drift-window://a",
               model_output: "raw"
             })

    assert {:error, :unknown_replay_drift_signal_class} =
             ReplaySurface.drift_projection(%{
               drift_signal_ref: "drift-signal://a",
               signal_class: :free_form,
               magnitude_class: "bounded_delta",
               window_ref: "drift-window://a"
             })
  end
end
