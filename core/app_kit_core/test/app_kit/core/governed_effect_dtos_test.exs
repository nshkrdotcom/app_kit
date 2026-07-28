defmodule AppKit.Core.GovernedEffectDtosTest do
  use ExUnit.Case, async: true

  alias AppKit.Core.{
    EffectAcceptanceDTO,
    EffectAmbiguityDTO,
    EffectCleanupDTO,
    EffectContinuationDTO,
    EffectDispatchCommandDTO,
    EffectReceiptCommandDTO,
    EffectReceiptDTO,
    EffectReviewDTO,
    GovernedEffectDTO,
    GovernedEffectProposalDTO
  }

  test "canonical governed-effect packet round trips through product-safe serialization" do
    modules_and_attrs = [
      {GovernedEffectProposalDTO, proposal_attrs()},
      {EffectReviewDTO, review_attrs()},
      {EffectCleanupDTO, cleanup_attrs()},
      {EffectReceiptDTO, receipt_attrs()},
      {EffectAmbiguityDTO, ambiguity_attrs()},
      {EffectContinuationDTO, continuation_attrs()},
      {GovernedEffectDTO, effect_attrs()},
      {EffectDispatchCommandDTO, %{expected_row_version: 2}},
      {EffectAcceptanceDTO,
       %{
         expected_row_version: 3,
         attempt_ref: "attempt://p04/1",
         external_ref: "codex-thread://p04/1"
       }},
      {EffectReceiptCommandDTO, receipt_command_attrs()}
    ]

    Enum.each(modules_and_attrs, fn {module, attrs} ->
      assert {:ok, dto} = module.new(attrs)
      assert {:ok, ^dto} = dto |> module.dump() |> module.new()
    end)
  end

  test "proposal is exactly one Codex named-file operation and never carries material" do
    assert {:error, :invalid_governed_effect_proposal} =
             proposal_attrs()
             |> put_in([:reviewed_operation, :relative_path], "../escape.txt")
             |> GovernedEffectProposalDTO.new()

    assert {:error, :invalid_governed_effect_proposal} =
             proposal_attrs()
             |> Map.put(:workspace_root, "/tmp/workspace")
             |> GovernedEffectProposalDTO.new()

    assert {:error, :invalid_governed_effect_proposal} =
             proposal_attrs()
             |> put_in([:reviewed_operation, :content], "reviewed file body")
             |> GovernedEffectProposalDTO.new()

    assert {:error, :invalid_governed_effect_proposal} =
             proposal_attrs()
             |> Map.put(:capability_id, "amp.session.turn")
             |> GovernedEffectProposalDTO.new()
  end

  test "governed projection exposes only the exact reviewed manifest and operation" do
    assert {:ok, %GovernedEffectDTO{} = dto} = GovernedEffectDTO.new(effect_attrs())

    assert dto.pinned_tool_manifest["manifest_hash"] ==
             "sha256:" <> String.duplicate("a", 64)

    assert dto.reviewed_operation["relative_path"] == "RESULT.txt"
    assert dto.reviewed_operation["content_digest"] == "sha256:" <> String.duplicate("b", 64)

    dump = GovernedEffectDTO.dump(dto)
    refute Map.has_key?(dump["reviewed_operation"], "content")
    refute Map.has_key?(dump["reviewed_operation"], "workspace_root")

    assert {:error, :invalid_governed_effect_dto} =
             effect_attrs()
             |> put_in([:reviewed_operation, :content], "smuggled file body")
             |> GovernedEffectDTO.new()

    assert {:error, :invalid_governed_effect_dto} =
             effect_attrs()
             |> put_in([:pinned_tool_manifest, :api_key], "smuggled credential")
             |> GovernedEffectDTO.new()
  end

  test "ambiguity is reconciliation-only and cannot encode a blind effect retry" do
    assert {:ok, %EffectReceiptCommandDTO{}} =
             EffectReceiptCommandDTO.new(ambiguous_receipt_command_attrs())

    assert {:error, :invalid_effect_receipt_command} =
             ambiguous_receipt_command_attrs()
             |> put_in([:continuation_target, :command], "retry_effect")
             |> EffectReceiptCommandDTO.new()

    assert {:error, :invalid_effect_receipt_command} =
             receipt_command_attrs()
             |> Map.put(:api_key, "must-not-cross-appkit")
             |> EffectReceiptCommandDTO.new()
  end

  test "hand-built structs cannot bypass command, receipt, or cleanup validation" do
    assert {:error, :invalid_effect_dispatch_command} =
             EffectDispatchCommandDTO.new(%EffectDispatchCommandDTO{expected_row_version: 0})

    invalid_cleanup = %EffectCleanupDTO{
      status: "completed",
      cleanup_ref: "/tmp/not-a-safe-reference",
      session_terminated: :not_a_boolean
    }

    assert {:error, :invalid_effect_cleanup_dto} =
             EffectCleanupDTO.new(invalid_cleanup)

    assert {:error, :invalid_effect_receipt_dto} =
             EffectReceiptDTO.new(%EffectReceiptDTO{
               receipt_ref: "receipt://p04/struct-bypass",
               effect_ref: "effect://p04/1",
               status: "completed",
               cleanup: invalid_cleanup
             })

    assert {:error, :invalid_effect_receipt_command} =
             EffectReceiptCommandDTO.new(%EffectReceiptCommandDTO{
               expected_row_version: 4,
               receipt_ref: "receipt://p04/struct-bypass",
               receipt_state: "failed",
               continuation_target: %{
                 "kind" => "owner_command",
                 "owner" => "outer_brain",
                 "command" => "publish_tool_result",
                 "idempotency_key" => "p04-publish-struct-bypass"
               },
               cleanup: invalid_cleanup
             })
  end

  defp proposal_attrs do
    %{
      effect_ref: "effect://p04/1",
      run_ref: "run://p04/1",
      turn_ref: "turn://p04/1",
      command_ref: "command://p04/1",
      decision_ref: "decision://citadel/p04/1",
      grant_ref: "grant://citadel/p04/1",
      review_ref: "review://mezzanine/p04/1",
      subject_id: "00000000-0000-0000-0000-000000000001",
      run_id: "00000000-0000-0000-0000-000000000002",
      review_unit_id: "00000000-0000-0000-0000-000000000003",
      target_ref: "target://codex/local/1",
      attempt_ref: "attempt://p04/1",
      capability_id: "codex.session.turn",
      effect_mode: "managed_account_local_effect",
      pinned_tool_manifest: %{
        manifest_ref: "manifest://codex/p04/1",
        manifest_hash: "sha256:" <> String.duplicate("a", 64),
        action_ids: ["create_or_replace_one_named_text_file"]
      },
      reviewed_operation: %{
        operation: "create_or_replace",
        workspace_ref: "workspace://p04/1",
        file_ref: "file://p04/RESULT.txt",
        relative_path: "RESULT.txt",
        content_digest: "sha256:" <> String.duplicate("b", 64)
      }
    }
  end

  defp review_attrs do
    %{
      review_ref: "review://mezzanine/p04/1",
      review_unit_id: "00000000-0000-0000-0000-000000000003",
      status: "accepted",
      row_version: 2,
      accepted_actor_ref: "operator://p04"
    }
  end

  defp cleanup_attrs do
    %{
      status: "completed",
      cleanup_ref: "cleanup://p04/1",
      managed_session_ref: "managed-session://p04/1",
      credential_lease_ref: "credential-lease://p04/1",
      materialization_ref: "materialization://p04/1",
      session_terminated: true,
      materialization_removed: true,
      credential_lease_released: true
    }
  end

  defp receipt_attrs do
    %{
      receipt_ref: "receipt://p04/1",
      effect_ref: "effect://p04/1",
      status: "completed",
      attempt_ref: "attempt://p04/1",
      runtime_execution_ref: "execution://p04/1",
      external_ref: "codex-thread://p04/1",
      result_artifact_ref: "artifact://p04/1",
      cleanup: cleanup_attrs()
    }
  end

  defp ambiguity_attrs do
    %{
      effect_ref: "effect://p04/1",
      state: "outcome_unknown",
      continuation_ref: "continuation://p04/1",
      reconciliation_required: true,
      effect_retry_allowed: false
    }
  end

  defp continuation_attrs do
    %{
      continuation_ref: "continuation://p04/1",
      status: "pending",
      target_kind: "owner_command",
      target_owner: "jido_integration",
      target_operation: "reconcile_effect_outcome",
      idempotency_key: "p04-reconcile-1",
      attempt_count: 0
    }
  end

  defp effect_attrs do
    %{
      contract_version: 1,
      effect_ref: "effect://p04/1",
      run_ref: "run://p04/1",
      turn_ref: "turn://p04/1",
      command_ref: "command://p04/1",
      decision_ref: "decision://citadel/p04/1",
      grant_ref: "grant://citadel/p04/1",
      target_ref: "target://codex/local/1",
      owner_execution_ref: "effect-execution://00000000-0000-0000-0000-000000000004",
      status: "completed",
      row_version: 4,
      attempt_ref: "attempt://p04/1",
      runtime_execution_ref: "execution://p04/1",
      external_ref: "codex-thread://p04/1",
      result_artifact_ref: "artifact://p04/1",
      pinned_tool_manifest: proposal_attrs().pinned_tool_manifest,
      reviewed_operation: proposal_attrs().reviewed_operation,
      review: review_attrs(),
      receipt: receipt_attrs(),
      continuation: continuation_attrs()
    }
  end

  defp receipt_command_attrs do
    %{
      expected_row_version: 4,
      receipt_ref: "receipt://p04/1",
      receipt_state: "completed",
      result_artifact_ref: "artifact://p04/1",
      artifact_refs: ["artifact://p04/1"],
      continuation_target: %{
        kind: "owner_command",
        owner: "outer_brain",
        command: "publish_tool_result",
        idempotency_key: "p04-publish-1"
      },
      cleanup: cleanup_attrs()
    }
  end

  defp ambiguous_receipt_command_attrs do
    %{
      expected_row_version: 4,
      receipt_ref: "receipt://p04/ambiguous",
      receipt_state: "ambiguous",
      ambiguity_state: "outcome_unknown",
      continuation_target: %{
        kind: "owner_command",
        owner: "jido_integration",
        command: "reconcile_effect_outcome",
        idempotency_key: "p04-reconcile-1"
      }
    }
  end
end
