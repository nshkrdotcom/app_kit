defmodule AppKit.Core.AgentIntake.DtosTest do
  use ExUnit.Case, async: true

  alias AppKit.Core.AgentIntake.{AgentRunRequest, RunOutcomeFuture, TurnSubmission}

  @profile_bundle %{
    source_profile_ref: :fixture_source,
    runtime_profile_ref: :fixture_runtime,
    tool_scope_ref: :fixture_tools,
    evidence_profile_ref: :fixture_evidence,
    publication_profile_ref: :none,
    review_profile_ref: :fixture_review,
    memory_profile_ref: :none,
    projection_profile_ref: :fixture_projection
  }

  test "agent run requests reject raw prompt and provider shortcut fields" do
    base = %{
      tenant_ref: "tenant://one",
      installation_ref: "installation://one",
      subject_ref: "subject://one",
      actor_ref: "actor://one",
      profile_bundle: @profile_bundle,
      tool_catalog_ref: "tool-catalog://fixture",
      budget_ref: "budget://fixture",
      recall_scope_ref: "recall://fixture",
      idempotency_key: "idem-run",
      trace_id: "trace://one",
      correlation_id: "corr://one",
      submission_dedupe_key: "dedupe-run",
      initial_input_ref: "input://one"
    }

    assert {:ok, %AgentRunRequest{}} = AgentRunRequest.new(base)

    assert {:error, :invalid_agent_run_request} =
             AgentRunRequest.new(Map.put(base, :prompt, "raw"))

    assert {:error, :invalid_agent_run_request} =
             AgentRunRequest.new(Map.put(base, :model_id, "gpt"))
  end

  test "agent run requests accept governed effect diagnostic options" do
    attrs =
      base_agent_run_request()
      |> Map.put(:effect_governance_mode, "staging_live")
      |> Map.put(:diagnostic_lane, "echo")
      |> Map.put(:governed_effect_refs, %{
        effect_ref: "effect://tenant-1/effects/1",
        authority_ref: "authority://tenant-1/decisions/1"
      })

    assert {:ok, request} = AgentRunRequest.new(attrs)
    assert request.effect_governance_mode == :staging_live
    assert request.diagnostic_lane == :echo
    assert request.governed_effect_refs.effect_ref == "effect://tenant-1/effects/1"

    dumped = AgentRunRequest.dump(request)
    assert dumped["effect_governance_mode"] == "staging_live"
    assert dumped["diagnostic_lane"] == "echo"
    assert dumped["governed_effect_refs"]["authority_ref"] == "authority://tenant-1/decisions/1"
  end

  test "turn submissions carry payload refs, not payload bodies" do
    base = %{
      idempotency_key: "idem-turn",
      actor_ref: "actor://one",
      run_ref: "run://one",
      kind: :user_input,
      payload_ref: "payload://one"
    }

    assert {:ok, %TurnSubmission{kind: :user_input}} = TurnSubmission.new(base)

    assert {:ok, %TurnSubmission{kind: :approval}} =
             TurnSubmission.new(%{base | kind: "approval"})

    assert {:error, :invalid_turn_submission} = TurnSubmission.new(Map.put(base, :prompt, "raw"))
    assert {:error, :invalid_turn_submission} = TurnSubmission.new(Map.put(base, :tool_call, %{}))

    assert {:error, :invalid_turn_submission} =
             TurnSubmission.new(%{base | kind: "provider_supplied_future_kind"})
  end

  test "run outcome futures expose polling hints" do
    assert {:ok, %RunOutcomeFuture{accepted?: true}} =
             RunOutcomeFuture.new(%{
               run_ref: "run://one",
               workflow_ref: "workflow://one",
               accepted?: true,
               command_ref: "command://one",
               correlation_id: "corr://one",
               governed_effect_refs: %{
                 effect_ref: "effect://tenant-1/effects/1",
                 receipt_ref: "receipt://tenant-1/receipts/1"
               },
               polling_hint: %{
                 checking?: true,
                 next_poll_at: "2026-04-27T00:00:00Z",
                 poll_interval_ms: 1_000,
                 staleness_ms: 0
               }
             })
  end

  defp base_agent_run_request do
    %{
      tenant_ref: "tenant://one",
      installation_ref: "installation://one",
      subject_ref: "subject://one",
      actor_ref: "actor://one",
      profile_bundle: @profile_bundle,
      tool_catalog_ref: "tool-catalog://fixture",
      budget_ref: "budget://fixture",
      recall_scope_ref: "recall://fixture",
      idempotency_key: "idem-run",
      trace_id: "trace://one",
      correlation_id: "corr://one",
      submission_dedupe_key: "dedupe-run",
      initial_input_ref: "input://one"
    }
  end
end
