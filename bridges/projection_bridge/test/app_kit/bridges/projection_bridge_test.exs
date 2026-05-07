defmodule AppKit.Bridges.ProjectionBridgeTest do
  use ExUnit.Case, async: true

  alias AppKit.Bridges.ProjectionBridge
  alias AppKit.Core.RunRef

  test "builds an operator-facing projection" do
    assert {:ok, run_ref} = RunRef.new(%{run_id: "run-1", scope_id: "workspace/main"})

    assert {:ok, projection} =
             ProjectionBridge.operator_projection(run_ref, %{
               route_name: :compile_workspace,
               state: :waiting_review,
               last_event: :review_requested
             })

    assert projection.route_status.route_name == :compile_workspace
    assert projection.last_event == :review_requested

    assert projection.persistence_posture.persistence_profile_ref ==
             "persistence-profile://mickey-mouse"

    assert projection.persistence_posture.raw_payload_persistence? == false
  end

  test "operator projection can disable retention without changing route status" do
    assert {:ok, run_ref} = RunRef.new(%{run_id: "run-1", scope_id: "workspace/main"})

    assert {:ok, projection} =
             ProjectionBridge.operator_projection(run_ref, %{
               route_name: :compile_workspace,
               state: :waiting_review,
               persistence_profile: :off
             })

    assert projection.route_status.route_name == :compile_workspace
    assert projection.persistence_posture.retained? == false
  end
end
