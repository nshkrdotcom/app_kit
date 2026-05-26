defmodule AppKit.ContextSurfaceTest do
  use ExUnit.Case, async: true

  alias AppKit.ContextSurface
  alias AppKit.ContextSurface.ContextPacketProjection

  test "compile requests carry refs only and reject raw context payloads" do
    assert {:ok, request} = ContextSurface.compile_request(compile_attrs())
    assert request.model_class_allowlist == ["model-class://fixture"]
    refute Map.has_key?(Map.from_struct(request), :prompt_body)

    assert {:error, {:raw_context_surface_payload_forbidden, :raw_prompt}} =
             compile_attrs()
             |> Map.put(:raw_prompt, "hidden prompt")
             |> ContextSurface.compile_request()

    assert {:error, {:raw_context_surface_payload_forbidden, :execution_plane_lane}} =
             compile_attrs()
             |> Map.put(:execution_plane_lane, :process)
             |> ContextSurface.compile_request()
  end

  test "packet projections wrap OuterBrain Context ABI packets as product-safe summaries" do
    assert {:ok, %ContextPacketProjection{} = projection} =
             compile_attrs()
             |> Map.put(:receipt_ref, "context-packet-receipt://a")
             |> Map.put(:admission_status, :admitted)
             |> ContextSurface.packet_projection()

    assert projection.context_packet_ref =~ "context-packet://"
    assert projection.packet_hash =~ "sha256:"
    assert projection.tenant_ref == "tenant://a"
    assert projection.redaction_posture == :refs_only
  end

  test "route model eval and operator review projections expose governed refs" do
    assert {:ok, route} = ContextSurface.route_decision_projection(route_attrs())
    assert route.selected_route_kind == :fixture
    assert route.reason_codes == ["route.reason.fixture.v1"]

    assert {:ok, model} = ContextSurface.model_invocation_projection(model_attrs())
    assert model.prompt_artifact_ref == "prompt-artifact://a"
    assert model.provider_payload_ref == "provider-payload://a"
    assert model.redaction_posture == :refs_only

    assert {:ok, eval} = ContextSurface.eval_verdict_projection(eval_attrs())
    assert eval.verdict == :pass

    assert {:ok, review} = ContextSurface.operator_review_projection(review_attrs())
    assert review.operator_state == :pending
    assert review.promotion_refs == ["promotion://candidate-a"]
    assert review.rollback_refs == ["rollback://candidate-a"]
  end

  test "model invocation projections reject raw provider payloads and invalid hashes" do
    assert {:error, {:raw_context_surface_payload_forbidden, :provider_payload}} =
             model_attrs()
             |> Map.put(:provider_payload, %{messages: []})
             |> ContextSurface.model_invocation_projection()

    assert {:error, {:invalid_context_surface_hash, :payload_hash}} =
             model_attrs()
             |> Map.put(:payload_hash, "not-sha")
             |> ContextSurface.model_invocation_projection()

    assert {:error, {:invalid_context_surface_hash, :payload_hash}} =
             model_attrs()
             |> Map.put(:payload_hash, "sha256:" <> String.duplicate("z", 64))
             |> ContextSurface.model_invocation_projection()
  end

  defp compile_attrs do
    %{
      request_ref: "request://context/compile",
      tenant_ref: "tenant://a",
      authority_ref: "authority://a",
      user_request_ref: "artifact://user-request/a",
      system_instruction_ref: "artifact://system-instruction/a",
      memory_refs: ["memory://a"],
      budget_ref: "budget://a",
      model_class_allowlist: ["model-class://fixture"],
      route_policy_ref: "route-policy://fixture",
      trace_ref: "trace://context/a",
      idempotency_key: "idem-context-a",
      redaction_policy_ref: "redaction://context/default"
    }
  end

  defp route_attrs do
    %{
      route_decision_ref: "route-decision://a",
      context_packet_ref: "context-packet://a",
      route_policy_ref: "route-policy://fixture",
      selected_route_kind: :fixture,
      selected_model_profile_ref: "model-profile://fixture",
      provider_or_runtime_ref: "runtime://fixture",
      verifier_ref: "verifier://fixture",
      fallback_plan_ref: "fallback://none",
      cost_estimate_ref: "cost-estimate://fixture",
      budget_status_ref: "budget-status://ok",
      authority_ref: "authority://a",
      trace_ref: "trace://route/a",
      reason_codes: ["route.reason.fixture.v1"]
    }
  end

  defp model_attrs do
    %{
      model_invocation_ref: "model-invocation://a",
      model_receipt_ref: "model-receipt://a",
      context_packet_ref: "context-packet://a",
      route_decision_ref: "route-decision://a",
      prompt_artifact_ref: "prompt-artifact://a",
      provider_payload_ref: "provider-payload://a",
      payload_hash: "sha256:" <> String.duplicate("a", 64),
      model_profile_ref: "model-profile://fixture",
      endpoint_ref: "endpoint://fixture",
      provider_ref: "provider://fixture",
      credential_lease_ref: "credential-lease://fixture",
      cost_ref: "cost://fixture",
      trace_ref: "trace://model/a"
    }
  end

  defp eval_attrs do
    %{
      eval_verdict_ref: "eval-verdict://a",
      context_packet_ref: "context-packet://a",
      route_decision_ref: "route-decision://a",
      model_receipt_ref: "model-receipt://a",
      verdict: :pass,
      severity_class: "clean",
      decision_evidence_ref: "decision-evidence://eval/a",
      trace_ref: "trace://eval/a"
    }
  end

  defp review_attrs do
    %{
      review_ref: "review://context/a",
      context_packet_ref: "context-packet://a",
      route_decision_ref: "route-decision://a",
      eval_verdict_ref: "eval-verdict://a",
      promotion_refs: ["promotion://candidate-a"],
      rollback_refs: ["rollback://candidate-a"],
      operator_state: :pending,
      trace_refs: ["trace://context/a"]
    }
  end
end
