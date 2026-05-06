defmodule AppKit.ReplayViewerTest do
  use ExUnit.Case, async: true

  alias AppKit.ReplayViewer

  test "renders replay waterfall from bounded trace refs only" do
    assert {:ok, waterfall} =
             ReplayViewer.waterfall(%{
               viewer_ref: "viewer://replay/one",
               tenant_ref: "tenant://alpha",
               source_trace_ref: "trace://source",
               replay_trace_ref: "trace://replay",
               decision_class: :diverged,
               divergence_markers: [
                 %{
                   divergence_ref: "divergence://one",
                   phase: "guard_decision",
                   severity: "warn",
                   redacted_excerpt_class: "bounded_or_hash_ref_only"
                 }
               ]
             })

    assert waterfall.side_effect_posture == :suppressed_view_only
    assert Enum.count(waterfall.components) == 3
  end

  test "rejects raw provider and tool payloads" do
    assert {:error, {:raw_replay_viewer_payload_forbidden, :provider_payload}} =
             ReplayViewer.waterfall(%{
               viewer_ref: "viewer://replay/one",
               tenant_ref: "tenant://alpha",
               source_trace_ref: "trace://source",
               replay_trace_ref: "trace://replay",
               decision_class: :clean,
               provider_payload: %{private: true}
             })
  end
end
