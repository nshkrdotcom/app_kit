defmodule AppKit.CoordinationSurfaceTest do
  use ExUnit.Case, async: true

  alias AppKit.CoordinationSurface

  alias AppKit.CoordinationSurface.{
    CoordinationProjection,
    HumanInterventionRequest,
    ReplayBundleProjection,
    RunControlRequest
  }

  test "projects coordination state through DTO refs only" do
    assert {:ok, %CoordinationProjection{} = projection} =
             CoordinationSurface.coordination_projection(coordination_attrs())

    assert projection.router_decision.selected_role_ref == "role://worker"
    assert projection.role_selection.prompt_ref == "prompt://role/worker"
    assert projection.provider_pool.provider_pool_ref == "provider-pool://mock"
    assert projection.verifier_state.verifier_result_ref == "verifier-result://pass"
    assert projection.turn_timeline.turn_refs == ["turn://worker/1"]
    assert projection.memory_refs == ["memory://role/worker"]
    assert projection.context_budget_refs == ["context-budget://worker"]
    assert projection.replay_bundle.replay_bundle_ref == "replay-bundle://trinity/demo"

    refute projection |> Map.from_struct() |> Map.has_key?(:provider_payload)
  end

  test "creates run controls, retry requests, human intervention requests, and replay bundles" do
    assert {:ok, %RunControlRequest{} = control} =
             CoordinationSurface.run_control(%{
               request_ref: "request://coordination/pause",
               coordination_run_ref: "coordination-run://demo",
               authority_ref: "authority://coordination",
               actor_ref: "operator://demo",
               control_class: :pause,
               trace_refs: ["trace://control/pause"]
             })

    assert control.control_class == :pause

    assert {:ok, retry} =
             CoordinationSurface.retry_turn(%{
               request_ref: "request://coordination/retry",
               coordination_run_ref: "coordination-run://demo",
               failed_turn_ref: "turn://worker/failed",
               authority_ref: "authority://coordination",
               actor_ref: "operator://demo",
               replay_ref: "replay://turn/failed",
               trace_refs: ["trace://retry"]
             })

    assert retry.failed_turn_ref == "turn://worker/failed"

    assert {:ok, %HumanInterventionRequest{} = intervention} =
             CoordinationSurface.human_intervention_request(%{
               request_ref: "request://coordination/human",
               coordination_run_ref: "coordination-run://demo",
               authority_ref: "authority://coordination",
               operator_action_ref: "operator-action://review",
               handoff_ref: "handoff://worker/reviewer",
               trace_refs: ["trace://human"]
             })

    assert intervention.operator_action_ref == "operator-action://review"

    assert {:ok, %ReplayBundleProjection{} = replay_bundle} =
             CoordinationSurface.replay_bundle(%{
               replay_bundle_ref: "replay-bundle://trinity/demo",
               coordination_run_ref: "coordination-run://demo",
               trace_refs: ["trace://trinity/demo"],
               replay_refs: ["replay://router", "replay://verifier"],
               redaction_posture: :refs_only
             })

    assert replay_bundle.redaction_posture == :refs_only
  end

  test "fails closed for missing refs and raw lower payloads" do
    assert {:error, {:missing_required_ref, :authority_ref}} =
             coordination_attrs()
             |> Map.delete(:authority_ref)
             |> CoordinationSurface.coordination_projection()

    assert {:error, {:raw_coordination_surface_payload_forbidden, :provider_payload}} =
             coordination_attrs()
             |> put_in([:router_decision, :provider_payload], %{body: "hidden"})
             |> CoordinationSurface.coordination_projection()
  end

  defp coordination_attrs do
    %{
      coordination_run_ref: "coordination-run://demo",
      tenant_ref: "tenant://demo",
      authority_ref: "authority://coordination",
      trace_refs: ["trace://trinity/demo"],
      memory_refs: ["memory://role/worker"],
      context_budget_refs: ["context-budget://worker"],
      router_decision: %{
        router_decision_ref: "router-decision://demo",
        router_artifact_ref: "router://mock",
        selected_role_ref: "role://worker",
        confidence_band: :high,
        trace_ref: "trace://router",
        replay_ref: "replay://router"
      },
      role_selection: %{
        role_ref: "role://worker",
        prompt_ref: "prompt://role/worker",
        capability_refs: ["capability://code"],
        model_profile_refs: ["model-profile://mock/worker"],
        tool_policy_ref: "tool-policy://worker",
        memory_profile_ref: "memory-profile://worker",
        guardrail_profile_ref: "guardrail-profile://worker",
        verifier_profile_ref: "verifier-profile://worker",
        budget_ref: "budget://worker",
        context_budget_ref: "context-budget://worker",
        handoff_policy_ref: "handoff-policy://worker",
        gepa_target_refs: ["gepa-target://role/worker"]
      },
      provider_pool: %{
        provider_pool_ref: "provider-pool://mock",
        slot_refs: ["provider-slot://mock/worker"],
        model_profile_refs: ["model-profile://mock/worker"],
        endpoint_profile_refs: ["endpoint-profile://mock/worker"],
        operation_policy_refs: ["operation-policy://route"],
        readiness_refs: ["readiness://mock/worker"]
      },
      verifier_state: %{
        verifier_policy_ref: "verifier-policy://worker",
        verifier_result_ref: "verifier-result://pass",
        score_schema_ref: "score-schema://verifier",
        termination_policy_ref: "termination-policy://repair",
        replay_ref: "replay://verifier",
        trace_ref: "trace://verifier"
      },
      turn_timeline: %{
        turn_refs: ["turn://worker/1"],
        agent_refs: ["agent://worker"],
        inference_call_refs: ["inference-call://mock/1"],
        verifier_refs: ["verifier-result://pass"],
        handoff_refs: ["handoff://worker/reviewer"],
        trace_refs: ["trace://turn/1"]
      },
      replay_bundle: %{
        replay_bundle_ref: "replay-bundle://trinity/demo",
        coordination_run_ref: "coordination-run://demo",
        trace_refs: ["trace://trinity/demo"],
        replay_refs: ["replay://router", "replay://verifier"],
        redaction_posture: :refs_only
      }
    }
  end
end
