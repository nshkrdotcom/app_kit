defmodule AppKit.Bridges.MezzanineBridgeBoundaryProtocolTest do
  use ExUnit.Case, async: true

  alias GroundPlane.Boundary.Codec
  alias GroundPlane.Boundary.Envelope
  alias GroundPlane.Boundary.Fixtures

  test "AppKit to Mezzanine boundary fixture is serializable and deterministic" do
    envelope = Fixtures.boundary_envelopes().appkit_mezzanine

    assert envelope.origin == "app_kit"
    assert envelope.target == "mezzanine"
    assert envelope.metadata.transport == "direct-module"

    encoded = Envelope.encode!(envelope)

    assert Codec.encode!(envelope) == encoded
    assert String.starts_with?(Envelope.digest(envelope), "sha256:")

    assert %{
             "origin" => "app_kit",
             "target" => "mezzanine",
             "operation" => "intake.fetch_candidates"
           } = Codec.decode!(encoded)
  end

  test "AppKit bridge boundary envelope rejects local runtime values and raw credentials" do
    assert {:error, :boundary_pid_not_serializable} =
             Envelope.new(%{
               id: "boundary://app_kit/mezzanine/bad-runtime-value",
               origin: "app_kit",
               target: "mezzanine",
               operation: "intake.fetch_candidates",
               tenant_id: "tenant-a",
               payload: %{pid: self()}
             })

    assert {:error, {:raw_credential_key_forbidden, "api_key"}} =
             Codec.encode(%{
               tenant_id: "tenant-a",
               payload: %{role_ref: "role://issue-tracker"},
               api_key: "raw-secret"
             })
  end
end
