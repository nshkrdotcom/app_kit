defmodule AppKit.HiveSurfaceTest do
  use ExUnit.Case, async: true

  alias AppKit.HiveSurface

  test "projects hive state through refs-only DTOs" do
    assert {:ok, projection} = HiveSurface.projection(projection_attrs())
    assert projection.redaction_posture == "refs_only"
    refute Map.has_key?(projection, :agent_message_body)

    assert {:ok, trace} =
             projection_attrs()
             |> Map.put(:trace_ref, "trace://hive")
             |> Map.put(:workflow_lifecycle_ref, "workflow://life-1")
             |> HiveSurface.trace_projection()

    assert trace.workflow_lifecycle_ref == "workflow://life-1"
  end

  test "rejects raw message, memory, provider, and private state fields" do
    assert {:error, {:raw_field_rejected, [:agent_message_body]}} =
             projection_attrs()
             |> Map.put(:agent_message_body, "raw")
             |> HiveSurface.projection()
  end

  test "builds projections from typed JidoHive records" do
    assert {:ok, projection} =
             HiveSurface.from_records(%{
               agents: [agent_record()],
               messages: [routed_message()],
               memory_decisions: [memory_decision()],
               patterns: [pattern_spec()]
             })

    assert projection.agent_refs == ["agent://worker-1"]
    assert projection.message_refs == ["message://1"]
  end

  defp projection_attrs do
    %{
      projection_ref: "hive-projection://1",
      tenant_ref: "tenant-a",
      installation_ref: "installation://main",
      agent_refs: ["agent://worker-1"],
      message_refs: ["message://1"],
      memory_scope_refs: ["memory-scope://tenant-a/run-1/shared"],
      pattern_refs: ["coordination-pattern://orchestrator-worker"],
      budget_refs: ["budget://run-1"],
      trace_refs: ["trace://hive-1"]
    }
  end

  defp agent_record do
    %JidoHive.AgentCoordinator.CoordinationRecord{
      record_ref: "coordination://agent-1",
      agent_ref: "agent://worker-1",
      tenant_ref: "tenant-a",
      installation_ref: "installation://main",
      workflow_lifecycle_ref: "workflow://life-1",
      budget_ref: "budget://run-1",
      memory_scope_ref: "memory-scope://tenant-a/run-1/shared",
      trace_ref: "trace://agent-1",
      store_mode: :memory,
      effect_status: :coordination_recorded_no_provider_effect,
      redaction_posture: "refs_only"
    }
  end

  defp routed_message do
    %JidoHive.InterAgentMessaging.RoutedMessage{
      message_ref: "message://1",
      sender_agent_ref: "agent://worker-1",
      recipient_agent_ref: "agent://reviewer",
      tenant_ref: "tenant-a",
      installation_ref: "installation://main",
      context_budget_ref: "context-budget://run-1",
      trace_ref: "trace://message-1",
      delivery_status: :accepted_no_provider_effect,
      redaction_posture: "hash_only"
    }
  end

  defp memory_decision do
    %JidoHive.SharedMemoryFacade.Decision{
      decision_ref: "shared-memory-decision://1",
      tenant_ref: "tenant-a",
      installation_ref: "installation://main",
      agent_ref: "agent://worker-1",
      memory_scope_ref: "memory-scope://tenant-a/run-1/shared",
      operation: :shared_write,
      memory_ref: "memory://shared/fact-1",
      trace_ref: "trace://memory-1",
      decision: :allow,
      redaction_posture: "hash_only"
    }
  end

  defp pattern_spec do
    %JidoHive.CoordinationPatterns.PatternSpec{
      pattern_ref: "coordination-pattern://orchestrator-worker",
      pattern_name: :orchestrator_worker,
      tenant_ref: "tenant-a",
      installation_ref: "installation://main",
      authority_ref: "authority://ops",
      budget_profile_ref: "budget-profile://run-1",
      trace_ref: "trace://pattern-1",
      max_agents: 4,
      max_turns: 8,
      max_messages: 16,
      max_tokens: 4_000,
      cancellation_policy_ref: "cancel-policy://bounded",
      memory_policy_ref: "memory-policy://shared-grants",
      replay_policy: :suppress_provider_effects,
      connector_policy_ref: "connector-policy://approved",
      approved_connector_refs: ["connector://search"],
      redaction_posture: "refs_only"
    }
  end
end
