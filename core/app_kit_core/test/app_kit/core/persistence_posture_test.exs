defmodule AppKit.Core.PersistencePostureTest do
  use ExUnit.Case, async: true

  alias AppKit.Core.PersistencePosture

  test "memory posture is ref-only and non-durable by default" do
    posture = PersistencePosture.memory(:runtime_projection)

    assert posture.persistence_profile_ref == "persistence-profile://mickey-mouse"
    assert posture.store_set_ref == "store-set://memory/ref-only"
    assert posture.retained? == true
    assert posture.durable? == false
    assert posture.raw_payload_persistence? == false
  end

  test "projection retention off disables storage without changing raw policy" do
    posture = PersistencePosture.off(:authority_projection)

    assert posture.retained? == false
    assert posture.store_set_ref == "store-set://off"
    assert posture.raw_payload_persistence? == false
  end

  test "debug tap failure records non-mutation evidence" do
    posture =
      :evidence_audit
      |> PersistencePosture.memory()
      |> PersistencePosture.debug_tap_failed()

    assert posture.debug_tap_result == :failed_non_mutating
    assert posture.debug_sidecar_mutated_state? == false
    assert posture.persistence_profile_ref == "persistence-profile://mickey-mouse"
  end
end
