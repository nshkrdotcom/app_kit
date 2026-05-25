defmodule AppKit.MemorySurfaceTest do
  use ExUnit.Case, async: true

  alias AppKit.MemorySurface

  test "write request accepts DTO intent and rejects raw body fields" do
    assert {:ok, request} =
             MemorySurface.write_request(%{
               request_ref: "request://write",
               intent: write_intent()
             })

    assert request.intent.content_hash == "sha256:body"

    assert {:error, {:raw_memory_surface_payload_forbidden, :body}} =
             MemorySurface.write_request(%{
               request_ref: "request://write",
               intent: write_intent(),
               body: "raw"
             })
  end

  test "projections and access records are refs and hashes only" do
    assert {:ok, projection} = MemorySurface.projection(projection_attrs())
    assert projection.content_hash == "sha256:body"
    refute Map.has_key?(Map.from_struct(projection), :body)

    assert {:ok, record} = MemorySurface.access_record(access_record_attrs())
    assert record.operation == :write
  end

  test "candidate, promotion, and rollback projections expose bounded refs only" do
    assert {:ok, candidate} = MemorySurface.candidate_projection(candidate_projection_attrs())

    assert candidate.candidate_ref == "memory-candidate://tenant-a/a"
    assert candidate.status == :candidate
    refute Map.has_key?(Map.from_struct(candidate), :memory_body)

    assert {:ok, promotion} = MemorySurface.promotion_projection(promotion_projection_attrs())

    assert promotion.status == :promoted
    assert promotion.promotion_ref == "memory-promotion://tenant-a/a"

    assert {:ok, rollback} = MemorySurface.rollback_projection(rollback_projection_attrs())

    assert rollback.status == :rolled_back
    assert rollback.rollback_ref == "memory-rollback://tenant-a/a"
  end

  defp projection_attrs do
    %{
      memory_ref: memory_ref(),
      evidence_ref: evidence_ref(),
      content_hash: "sha256:body",
      redaction_policy_ref: "policy://redact",
      redacted_excerpt: "bounded"
    }
  end

  defp access_record_attrs do
    %{
      tenant_ref: "tenant://a",
      authority_ref: "authority://a",
      installation_ref: "installation://a",
      idempotency_key: "idem",
      trace_ref: "trace://a",
      memory_ref: memory_ref(),
      operation: :write,
      redaction_policy_ref: "policy://redact"
    }
  end

  defp candidate_projection_attrs do
    %{
      candidate_ref: "memory-candidate://tenant-a/a",
      tenant_ref: "tenant://a",
      memory_ref: memory_ref(),
      evidence_ref: evidence_ref(),
      eval_evidence_refs: ["eval://memory/a"],
      authority_ref: "authority://citadel/memory/a",
      trace_ref: "trace://a",
      redaction_policy_ref: "policy://redact",
      status: :candidate
    }
  end

  defp promotion_projection_attrs do
    %{
      candidate_ref: "memory-candidate://tenant-a/a",
      promotion_ref: "memory-promotion://tenant-a/a",
      rollback_ref: "memory-rollback://tenant-a/a",
      tenant_ref: "tenant://a",
      citadel_authority_ref: "authority://citadel/promotion/a",
      eval_refs: ["eval://memory/a"],
      trace_ref: "trace://promotion/a",
      appkit_projection_ref: "appkit://memory/promotion/a",
      status: :promoted
    }
  end

  defp rollback_projection_attrs do
    %{
      candidate_ref: "memory-candidate://tenant-a/a",
      rollback_ref: "memory-rollback://tenant-a/a",
      restored_ref: "memory://tenant-a/promoted/previous",
      tenant_ref: "tenant://a",
      citadel_authority_ref: "authority://citadel/rollback/a",
      trace_ref: "trace://rollback/a",
      appkit_projection_ref: "appkit://memory/rollback/a",
      status: :rolled_back
    }
  end

  defp write_intent do
    %{
      tenant_ref: "tenant://a",
      authority_ref: "authority://a",
      installation_ref: "installation://a",
      idempotency_key: "idem",
      trace_ref: "trace://a",
      scope_key: scope(),
      content_class: "note",
      content_hash: "sha256:body",
      content_redacted_excerpt: "bounded",
      redaction_policy: %{level: :redacted_excerpt_only, redaction_policy_ref: "policy://redact"},
      ttl_class: "run",
      budget_ref: budget_ref()
    }
  end

  defp memory_ref do
    %{
      memory_id: "memory://a",
      scope_key: scope(),
      tier: :working,
      revision: 1,
      tenant_ref: "tenant://a"
    }
  end

  defp evidence_ref do
    %{
      memory_id: "memory://a",
      evidence_hash: "sha256:body",
      evidence_owner_ref: "owner://memory",
      release_manifest_ref: "release://phase-a",
      redaction_policy_ref: "policy://redact"
    }
  end

  defp scope do
    %{
      tenant_ref: "tenant://a",
      installation_ref: "installation://a",
      subject_ref: "subject://a",
      run_ref: "run://a",
      agent_ref: "agent://a",
      skill_ref: "skill://a"
    }
  end

  defp budget_ref do
    %{
      budget_ref: "budget://a",
      tenant_ref: "tenant://a",
      authority_ref: "authority://a",
      installation_ref: "installation://a",
      trace_ref: "trace://a"
    }
  end
end
