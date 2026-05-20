defmodule AppKit.Core.GovernedEffectDtosTest do
  use ExUnit.Case, async: true

  alias AppKit.Core.{
    AuthorityDecisionDTO,
    EffectEvidenceDTO,
    EffectReceiptDTO,
    EffectTimelineDTO,
    GovernedEffectDTO
  }

  test "governed effect DTO round trips through string-keyed serialization" do
    assert_round_trip(GovernedEffectDTO, governed_effect_attrs())
    assert_round_trip(AuthorityDecisionDTO, authority_decision_attrs())
    assert_round_trip(EffectReceiptDTO, effect_receipt_attrs())
    assert_round_trip(EffectEvidenceDTO, effect_evidence_attrs())
    assert_round_trip(EffectTimelineDTO, effect_timeline_attrs())
  end

  test "governed effect DTOs reject non-serializable and raw material fields" do
    assert {:error, :invalid_governed_effect_dto} =
             GovernedEffectDTO.new(Map.put(governed_effect_attrs(), :metadata, %{pid: self()}))

    assert {:error, :invalid_effect_receipt_dto} =
             EffectReceiptDTO.new(Map.put(effect_receipt_attrs(), :raw_payload, "raw lower"))

    assert {:error, :invalid_effect_evidence_dto} =
             EffectEvidenceDTO.new(Map.put(effect_evidence_attrs(), :memory_body, "raw memory"))
  end

  defp assert_round_trip(module, attrs) do
    assert {:ok, dto} = module.new(attrs)
    dumped = module.dump(dto)
    assert {:ok, round_tripped} = module.new(dumped)
    assert round_tripped == dto
  end

  defp governed_effect_attrs do
    %{
      effect_ref: "effect://tenant-1/effects/1",
      effect_type: "diagnostic.echo",
      command_ref: "command://tenant-1/commands/1",
      tenant_ref: "tenant://tenant-1",
      actor_ref: "actor://tenant-1/operator",
      installation_ref: "installation://tenant-1/synapse",
      status: "proposed",
      trace_ref: "trace://tenant-1/effects/1",
      authority_ref: "authority://tenant-1/decisions/1",
      receipt_ref: "receipt://tenant-1/receipts/1",
      dispatch_ref: "dispatch://tenant-1/effects/1",
      expected_version: 1,
      metadata: %{"lane" => "diagnostic"}
    }
  end

  defp authority_decision_attrs do
    %{
      authority_ref: "authority://tenant-1/decisions/1",
      effect_ref: "effect://tenant-1/effects/1",
      decision: "allow",
      decision_hash: "sha256:authority",
      boundary_class: "diagnostic",
      posture: "allow_diagnostic",
      policy_refs: ["policy://tenant-1/diagnostic"],
      metadata: %{"risk" => "low"}
    }
  end

  defp effect_receipt_attrs do
    %{
      receipt_ref: "receipt://tenant-1/receipts/1",
      effect_ref: "effect://tenant-1/effects/1",
      status: "success",
      evidence_refs: ["evidence://tenant-1/effects/1"],
      trace_ref: "trace://tenant-1/effects/1",
      metadata: %{"result" => "echoed"}
    }
  end

  defp effect_evidence_attrs do
    %{
      effect_ref: "effect://tenant-1/effects/1",
      receipt_ref: "receipt://tenant-1/receipts/1",
      trace_ref: "trace://tenant-1/effects/1",
      trace_summary_hash: "sha256:trace",
      evidence_refs: ["evidence://tenant-1/effects/1"],
      metadata: %{"redaction" => "standard"}
    }
  end

  defp effect_timeline_attrs do
    %{
      effect_ref: "effect://tenant-1/effects/1",
      trace_summary_hash: "sha256:trace",
      entries: [
        %{
          "sequence" => 1,
          "event_kind" => "effect_transition",
          "status" => "proposed",
          "entry_hash" => "sha256:entry-1"
        }
      ],
      metadata: %{"count" => 1}
    }
  end
end
