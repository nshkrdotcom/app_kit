defmodule AppKit.Core.MemoryControlDtosTest do
  use ExUnit.Case, async: true

  alias AppKit.Core.{
    MemoryFragmentListRequest,
    MemoryFragmentProjection,
    MemoryFragmentProvenance,
    MemoryInvalidationRequest,
    MemoryPromotionRequest,
    MemoryProofTokenLookup,
    MemoryShareUpRequest
  }

  test "operator-safe fragment projection exposes proof and ordering evidence without raw payloads" do
    assert {:ok, projection} = MemoryFragmentProjection.new(fragment_projection_attrs())

    assert projection.contract_name == "AppKit.MemoryFragmentProjection.v1"
    assert projection.fragment_ref == "memory-private://alpha/private-1"
    assert projection.proof_token_ref == "proof://recall/1"
    assert projection.proof_hash == valid_hash("proof")
    assert projection.source_node_ref == "node://memory-reader@host/reader-1"
    assert projection.snapshot_epoch == 42
    assert projection.commit_lsn == "16/B374D848"
    assert projection.commit_hlc.logical == 1
    assert projection.staleness_class == "fresh"
    assert projection.cluster_invalidation_status == "none"

    refute Map.has_key?(Map.from_struct(projection), :payload)
    refute Map.has_key?(Map.from_struct(projection), :raw_payload)
    refute Map.has_key?(Map.from_struct(projection), :content)
  end

  test "fragment projection rejects raw fragment payload leaks and invalid staleness class" do
    assert {:error, {:raw_payload_forbidden, :payload}} =
             fragment_projection_attrs()
             |> Map.put(:payload, %{"text" => "private memory"})
             |> MemoryFragmentProjection.new()

    assert {:error, {:invalid_enum, :staleness_class}} =
             fragment_projection_attrs()
             |> Map.put(:staleness_class, "maybe_fresh")
             |> MemoryFragmentProjection.new()
  end

  test "list, proof lookup, and provenance DTOs preserve proof-token provenance boundary" do
    assert {:ok, list_request} =
             MemoryFragmentListRequest.new(%{
               proof_token_ref: "proof://recall/1",
               include_provenance?: true,
               metadata: %{operator_reason: "audit recall"}
             })

    assert {:ok, lookup} =
             MemoryProofTokenLookup.new(%{
               proof_token_ref: "proof://recall/1",
               expected_tenant_ref: "tenant://alpha",
               reject_stale?: true,
               current_epoch: 42
             })

    assert {:ok, provenance} =
             MemoryFragmentProvenance.new(%{
               fragment_ref: "memory-private://alpha/private-1",
               proof_token_ref: "proof://recall/1",
               proof_hash: valid_hash("proof"),
               source_contract_name: "OuterBrain.MemoryContextProvenance.v2",
               snapshot_epoch: 42,
               source_node_ref: "node://memory-reader@host/reader-1",
               commit_lsn: "16/B374D848",
               commit_hlc: %{wall_ns: 1_800_000_000_000_000_000, logical: 1, node: "reader-1"},
               provenance_refs: ["provenance://outer-brain/context/1"],
               evidence_refs: [%{ref: "evidence://recall/1", kind: "proof"}],
               governance_refs: [%{ref: "governance://memory/read", kind: "read"}]
             })

    assert list_request.include_provenance?
    assert lookup.reject_stale?
    assert lookup.current_epoch == 42
    assert provenance.source_contract_name == "OuterBrain.MemoryContextProvenance.v2"
  end

  test "write request DTOs require non-identity share-up, promotion, and operator suppression evidence" do
    assert {:ok, share_up} =
             MemoryShareUpRequest.new(%{
               fragment_ref: "memory-private://alpha/private-1",
               target_scope_ref: "scope://team-alpha",
               share_up_policy_ref: "share-up-policy://team-alpha",
               transform_ref: "transform://redact-pii",
               reason: "share useful project memory",
               evidence_refs: [%{ref: "evidence://operator/share-up", kind: "operator"}]
             })

    assert {:ok, promotion} =
             MemoryPromotionRequest.new(%{
               shared_fragment_ref: "memory-shared://alpha/shared-1",
               promotion_policy_ref: "promote-policy://governed",
               reason: "approved for governed memory",
               evidence_refs: [%{ref: "evidence://operator/promote", kind: "operator"}]
             })

    assert {:ok, invalidation} =
             MemoryInvalidationRequest.new(%{
               root_fragment_ref: "memory-private://alpha/private-1",
               reason: :operator_suppression,
               suppression_reason: "contains obsolete customer preference",
               invalidate_policy_ref: "invalidate-policy://default",
               authority_ref: %{ref: "authority://operator/suppression", kind: "operator"},
               evidence_refs: [%{ref: "evidence://operator/invalidate", kind: "operator"}]
             })

    assert share_up.transform_ref == "transform://redact-pii"
    assert promotion.shared_fragment_ref == "memory-shared://alpha/shared-1"
    assert invalidation.reason == :operator_suppression

    assert {:error, :identity_share_up_forbidden} =
             MemoryShareUpRequest.new(%{
               share_up
               | transform_ref: "identity"
             })

    assert {:error, {:missing_required_fields, [:suppression_reason]}} =
             MemoryInvalidationRequest.new(%{
               invalidation
               | suppression_reason: nil
             })
  end

  defp fragment_projection_attrs do
    %{
      fragment_ref: "memory-private://alpha/private-1",
      tenant_ref: "tenant://alpha",
      installation_ref: "installation://alpha",
      tier: "private",
      proof_token_ref: "proof://recall/1",
      proof_hash: valid_hash("proof"),
      source_node_ref: "node://memory-reader@host/reader-1",
      snapshot_epoch: 42,
      commit_lsn: "16/B374D848",
      commit_hlc: %{wall_ns: 1_800_000_000_000_000_000, logical: 1, node: "reader-1"},
      provenance_refs: ["provenance://outer-brain/context/1"],
      evidence_refs: [%{ref: "evidence://recall/1", kind: "proof"}],
      governance_refs: [%{ref: "governance://memory/read", kind: "read"}],
      cluster_invalidation_status: "none",
      staleness_class: "fresh",
      redaction_posture: "operator_safe",
      metadata: %{recall_kind: "operator_lookup"}
    }
  end

  defp valid_hash(seed) do
    "sha256:" <> Base.encode16(:crypto.hash(:sha256, seed), case: :lower)
  end
end
