defmodule AppKit.Core.Substrate.DTOsTest do
  use ExUnit.Case, async: true

  alias AppKit.Core.Substrate.{
    ProfileBundle,
    Ref,
    RuntimeCommandResult,
    RuntimeEventRow,
    RuntimeProjectionEnvelope
  }

  test "refs reject provider selectors and raw paths" do
    assert {:ok, ref} = Ref.new(%{id: "subject-1", kind: :subject})
    assert Ref.dump(ref)["id"] == "subject-1"
    assert {:error, :invalid_substrate_ref} = Ref.new(%{id: "/tmp/raw"})
    assert {:error, :invalid_substrate_ref} = Ref.new(%{id: "subject-1", github_pr_id: "1"})
  end

  test "profile bundle is explicit and dumpable" do
    assert {:ok, bundle} =
             ProfileBundle.new(%{
               source_profile_ref: :synthetic_task,
               runtime_profile_ref: :execution_plane_fixture,
               tool_scope_ref: :local_coding_v1,
               evidence_profile_ref: :file_artifacts_v1,
               publication_profile_ref: :none,
               review_profile_ref: :operator_optional,
               memory_profile_ref: :none,
               projection_profile_ref: :runtime_readback_v1
             })

    assert ProfileBundle.dump(bundle)["runtime_profile_ref"] == "execution_plane_fixture"
  end

  test "runtime DTOs reject unsafe maps and dump string-keyed maps" do
    assert {:ok, row} =
             RuntimeEventRow.new(%{
               event_ref: "event-1",
               event_seq: 0,
               event_kind: "accepted",
               tenant_ref: "tenant-1",
               installation_ref: "installation-1",
               subject_ref: "subject-1",
               run_ref: "run-1"
             })

    assert RuntimeEventRow.dump(row)["event_ref"] == "event-1"

    assert {:error, :invalid_runtime_command_result} =
             RuntimeCommandResult.new(%{
               command_ref: "command-1",
               command_kind: "refresh",
               status: "accepted",
               idempotency_key: "idem-1",
               workspace_path: "/home/user/project"
             })

    assert {:ok, result} =
             RuntimeCommandResult.new(%{
               command_ref: "command-1",
               command_kind: "refresh",
               status: "accepted",
               idempotency_key: "idem-1"
             })

    assert RuntimeCommandResult.dump(result)["command_kind"] == "refresh"

    assert {:ok, envelope} =
             RuntimeProjectionEnvelope.new(%{
               schema_ref: "runtime_state_snapshot.v1",
               schema_version: 1,
               projection_ref: "projection-1",
               projection_name: "state",
               projection_kind: "runtime_state_snapshot",
               tenant_ref: "tenant-1",
               installation_ref: "installation-1",
               profile_ref: "profile-1",
               scope_ref: "scope-1",
               row_key: "state",
               payload: %{"ok" => true}
             })

    assert RuntimeProjectionEnvelope.dump(envelope)["schema_version"] == 1
  end
end
