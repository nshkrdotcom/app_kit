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

  defmodule MemoryCommandOwner do
    def request_share_up(attrs, _opts) do
      send(self(), {:share_up_owner, attrs})

      {:ok,
       %{
         operation_ref: "operation://outer-brain/share-up/1",
         receipt_ref: "receipt://outer-brain/share-up/1",
         status: "completed",
         message: "Owner committed share-up",
         metadata: %{proof_token_ref: "proof://outer-brain/share-up/1"}
       }}
    end

    def request_promotion(attrs, _opts) do
      send(self(), {:promotion_owner, attrs})

      {:ok,
       %{
         operation_ref: "operation://mezzanine/promotion/1",
         receipt_ref: "receipt://mezzanine/promotion/1",
         status: :accepted
       }}
    end

    def request_invalidation(attrs, _opts) do
      send(self(), {:invalidation_owner, attrs})

      {:ok,
       %{
         operation_ref: "operation://mezzanine/invalidation/1",
         receipt_ref: "receipt://mezzanine/invalidation/1",
         status: :completed
       }}
    end
  end

  defmodule InvalidMemoryCommandOwner do
    def request_share_up(_attrs, _opts), do: {:ok, "candidate-id-only"}
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

  test "memory commands require owner-prepared durable operation receipts" do
    attrs = %{fragment_ref: "memory://outer-brain/private/1"}

    assert {:error, :memory_share_up_owner_not_configured} =
             MemoryControlService.request_share_up(attrs)

    assert {:ok, share_up} =
             MemoryControlService.request_share_up(attrs,
               share_up_command_service: MemoryCommandOwner
             )

    assert share_up.status == :completed
    assert share_up.action_ref.id == "operation://outer-brain/share-up/1"
    assert share_up.metadata.receipt_ref == "receipt://outer-brain/share-up/1"
    assert_received {:share_up_owner, ^attrs}

    assert {:ok, promotion} =
             MemoryControlService.request_promotion(
               %{shared_fragment_ref: "memory://outer-brain/shared/1"},
               promotion_command_service: MemoryCommandOwner
             )

    assert promotion.status == :accepted
    assert promotion.action_ref.id == "operation://mezzanine/promotion/1"

    assert {:ok, invalidation} =
             MemoryControlService.request_invalidation(
               %{root_fragment_ref: "memory://outer-brain/shared/1"},
               invalidation_command_service: MemoryCommandOwner
             )

    assert invalidation.status == :completed
    assert invalidation.action_ref.id == "operation://mezzanine/invalidation/1"
  end

  test "memory command bridge never manufactures acceptance from incomplete lower output" do
    assert {:error, :invalid_memory_owner_receipt} =
             MemoryControlService.request_share_up(
               %{fragment_ref: "memory://outer-brain/private/1"},
               share_up_command_service: InvalidMemoryCommandOwner
             )
  end
end
