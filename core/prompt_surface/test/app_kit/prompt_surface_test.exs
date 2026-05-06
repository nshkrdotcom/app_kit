defmodule AppKit.PromptSurfaceTest do
  use ExUnit.Case, async: true

  alias AppKit.PromptSurface

  test "author requests and projections reject raw prompt bodies" do
    assert {:ok, request} = PromptSurface.author_request(author_attrs())
    assert request.content_hash == "sha256:prompt"

    assert {:error, {:raw_prompt_surface_payload_forbidden, :prompt_body}} =
             author_attrs()
             |> Map.put(:prompt_body, "raw")
             |> PromptSurface.author_request()
  end

  test "promotion rollback and A/B DTOs carry refs only" do
    assert {:ok, promote} = PromptSurface.promote_request(promote_attrs())
    assert promote.guard_chain_ref == "guard-chain://a"

    assert {:ok, rollback} =
             PromptSurface.rollback_request(%{
               request_ref: "request://rollback",
               prompt_id: "prompt://a",
               target_revision: 1,
               decision_evidence_ref: "decision://rollback"
             })

    assert rollback.target_revision == 1

    assert {:ok, ab} =
             PromptSurface.ab_assign_request(%{
               request_ref: "request://ab",
               prompt_id: "prompt://a",
               variant_revisions: [1, 2],
               ab_assignment_key: "subject-1"
             })

    assert ab.variant_revisions == [1, 2]
  end

  test "lineage projections are generated from prompt lineage refs" do
    assert {:ok, projection} =
             PromptSurface.lineage_projection(%{
               lineage_ref: "prompt-lineage://a/1",
               prompt_id: "prompt://a",
               revision: 1,
               derivation_reason: :author,
               decision_evidence_ref: "decision://a"
             })

    assert projection.derivation_reason == :author
  end

  defp author_attrs do
    %{
      request_ref: "request://author",
      tenant_ref: "tenant://a",
      authority_ref: "authority://a",
      installation_ref: "installation://a",
      prompt_id: "prompt://a",
      content_hash: "sha256:prompt"
    }
  end

  defp promote_attrs do
    %{
      request_ref: "request://promote",
      prompt_ref: prompt_ref(),
      eval_suite_ref: "eval-suite://a",
      guard_chain_ref: "guard-chain://a",
      decision_evidence_ref: "decision://promote"
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
