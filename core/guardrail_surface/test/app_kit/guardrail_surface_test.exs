defmodule AppKit.GuardrailSurfaceTest do
  use ExUnit.Case, async: true

  alias AppKit.GuardrailSurface

  test "guard chain projections and audit projections are bounded" do
    assert {:ok, chain} =
             GuardrailSurface.chain_view_projection(%{
               guard_chain_ref: "guard-chain://a",
               detector_refs: ["detector://length"],
               redaction_posture_floor: :partial,
               policy_revision_ref: "policy://guard/v1"
             })

    assert chain.redaction_posture_floor == :partial

    assert {:ok, audit} =
             GuardrailSurface.audit_projection(%{
               audit_ref: "audit://guard",
               decision_ref: "guard-decision://a",
               trace_ref: "trace://a",
               bounded_violation_refs: ["guard-violation://a"]
             })

    assert audit.bounded_violation_refs == ["guard-violation://a"]
  end

  test "decision projections reject raw violation payloads" do
    assert {:ok, projection} =
             GuardrailSurface.decision_projection(%{
               decision_ref: "guard-decision://a",
               decision: decision_attrs()
             })

    assert projection.redaction_posture == :block

    assert {:error, {:raw_guardrail_surface_payload_forbidden, :violation_body}} =
             GuardrailSurface.decision_projection(%{
               decision_ref: "guard-decision://a",
               decision: decision_attrs(),
               violation_body: "raw"
             })
  end

  test "override requests are bounded duration" do
    assert {:ok, override} =
             GuardrailSurface.override_request(%{
               request_ref: "request://override",
               decision_ref: "guard-decision://a",
               permission_ref: "permission://guard/override",
               reason_ref: "decision://operator",
               duration_seconds: 60
             })

    assert override.duration_seconds == 60

    assert {:error, :guard_override_duration_unbounded} =
             GuardrailSurface.override_request(%{
               request_ref: "request://override",
               decision_ref: "guard-decision://a",
               permission_ref: "permission://guard/override",
               reason_ref: "decision://operator",
               duration_seconds: 3601
             })
  end

  defp decision_attrs do
    %{
      tenant_ref: "tenant://a",
      authority_ref: "authority://a",
      installation_ref: "installation://a",
      idempotency_key: "idem-guard",
      trace_ref: "trace://a",
      prompt_ref: prompt_ref(),
      payload_kind: :input_prompt,
      detector_chain_ref: "guard-chain://a",
      decision_class: :block,
      redaction_posture: :block,
      operator_action: "reject"
    }
  end

  defp prompt_ref do
    %{
      prompt_id: "prompt://a",
      revision: 1,
      tenant_ref: "tenant://a",
      installation_ref: "installation://a",
      content_hash: "sha256:prompt",
      redaction_policy_ref: "redaction://prompt",
      lineage_ref: "prompt-lineage://a/1"
    }
  end
end
