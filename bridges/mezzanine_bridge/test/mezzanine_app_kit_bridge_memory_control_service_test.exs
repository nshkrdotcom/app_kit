defmodule Mezzanine.AppKitBridge.MemoryControlServiceTest do
  use ExUnit.Case, async: true

  alias Mezzanine.AppKitBridge.MemoryControlService

  defmodule ProofTokenStore do
    def fetch("proof://recall/current") do
      {:ok,
       %{
         proof_id: "proof://recall/current",
         proof_hash: String.duplicate("a", 64),
         tenant_ref: "tenant://current",
         installation_id: "installation://current",
         epoch_used: 7,
         source_node_ref: "node://outer-brain/current",
         commit_lsn: "0/16B6C50",
         commit_hlc: %{"wall_time_ms" => 1_785_254_400_000, "logical" => 1},
         evidence_refs: ["evidence://recall/current"],
         governance_decision_ref: "decision://memory/current"
       }}
    end
  end

  defmodule MemoryQuery do
    def list_fragments_by_proof_token(_token, _attrs, _opts) do
      {:ok,
       [
         %{
           fragment_ref: "memory://outer-brain/current",
           tier: "working",
           provenance_refs: ["provenance://outer-brain/current"],
           raw_payload: "must-not-cross"
         }
       ]}
    end
  end

  test "normalizes Mezzanine's stored proof digest for the AppKit public DTO" do
    assert {:ok, [projection]} =
             MemoryControlService.list_fragments_by_proof_token(
               %{
                 proof_token_ref: "proof://recall/current",
                 tenant_ref: "tenant://current"
               },
               proof_token_store: ProofTokenStore,
               memory_read_query: MemoryQuery
             )

    assert projection.proof_hash == "sha256:" <> String.duplicate("a", 64)
    refute Map.has_key?(projection, :raw_payload)
  end
end
