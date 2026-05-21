defmodule AppKit.Core.AgentIntake.DtosTest do
  use ExUnit.Case, async: true

  alias AppKit.Core.AgentIntake.{
    AgentPendingInteraction,
    AgentRunCursor,
    AgentRunEvent,
    AgentRunEventPage,
    AgentRunRequest,
    PendingInteractionQuery,
    RunOutcomeFuture,
    TurnSubmission
  }

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

  test "agent run requests reject lower selectors, raw endpoints, credentials, and AX terms" do
    base = base_agent_run_request()

    rejected_attrs = [
      %{raw_endpoint: "https://lower.internal/rpc"},
      %{credential_ref: "secret://raw"},
      %{api_key: "plain-key"},
      %{protocol_module: "A2A.Protocol.Message"},
      %{runtime_module: "AxRuntime.Session"},
      %{provider_payload: %{"linear" => "payload"}},
      %{params: %{transport_endpoint: "grpc://runtime.internal"}},
      %{params: %{lower_selector: "Jido.Integration.DirectRuntime"}}
    ]

    for attrs <- rejected_attrs do
      assert {:error, :invalid_agent_run_request} = AgentRunRequest.new(Map.merge(base, attrs))
    end
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

  test "agent run requests carry opaque cursor and pending refs" do
    attrs =
      base_agent_run_request()
      |> Map.put(:resume_cursor_ref, "agent-cursor://tenant-1/runs/1/42")
      |> Map.put(:pending_ref, "agent-pending://tenant-1/pending/1")

    assert {:ok, request} = AgentRunRequest.new(attrs)
    assert request.resume_cursor_ref == "agent-cursor://tenant-1/runs/1/42"
    assert request.pending_ref == "agent-pending://tenant-1/pending/1"
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

  test "turn submissions can resume opaque cursor or pending refs" do
    attrs =
      base_turn_submission()
      |> Map.put(:cursor_ref, "agent-cursor://tenant-1/runs/1/42")
      |> Map.put(:pending_ref, "agent-pending://tenant-1/pending/1")

    assert {:ok, submission} = TurnSubmission.new(attrs)
    assert submission.cursor_ref == "agent-cursor://tenant-1/runs/1/42"
    assert submission.pending_ref == "agent-pending://tenant-1/pending/1"
  end

  test "turn submissions reject lower selectors, raw endpoints, credentials, and A2A terms" do
    base = base_turn_submission()

    rejected_attrs = [
      %{raw_endpoint: "https://lower.internal/rpc"},
      %{token: "plain-token"},
      %{protocol_module: "A2A.Protocol.Message"},
      %{runtime_module: "AxGrpc.Controller"},
      %{provider_body: %{"github" => "payload"}},
      %{params: %{transport_endpoint: "grpc://runtime.internal"}},
      %{params: %{lower_selector: "ExecutionPlane.Process"}}
    ]

    for attrs <- rejected_attrs do
      assert {:error, :invalid_turn_submission} = TurnSubmission.new(Map.merge(base, attrs))
    end
  end

  test "agent run cursor and event page are product-safe catch-up DTOs" do
    assert {:ok, cursor} =
             AgentRunCursor.new(%{
               cursor_ref: "agent-cursor://tenant-1/runs/1/42",
               ledger_ref: "agent-ledger://tenant-1/runs/1",
               tenant_ref: "tenant://one",
               actor_ref: "actor://one",
               last_seq_seen: 42,
               visibility: "product",
               issued_at: "2026-05-20T00:00:00Z",
               expires_at: "2026-05-21T00:00:00Z"
             })

    assert {:ok, event} =
             AgentRunEvent.new(%{
               event_ref: "agent-event://tenant-1/runs/1/43",
               ledger_ref: "agent-ledger://tenant-1/runs/1",
               event_seq: 43,
               event_kind: "conversation_delta",
               visibility: :product,
               observed_at: "2026-05-20T00:00:01Z",
               summary: "assistant response chunk",
               payload_ref: "payload://tenant-1/events/43"
             })

    assert {:ok, page} =
             AgentRunEventPage.new(%{
               cursor: cursor,
               events: [event],
               has_more?: false
             })

    assert page.cursor.last_seq_seen == 42
    assert hd(page.events).event_seq == 43

    assert {:error, :invalid_agent_run_cursor} =
             cursor
             |> Map.from_struct()
             |> Map.put(:cursor_ref, "/tmp/raw-path")
             |> AgentRunCursor.new()

    assert {:error, :invalid_agent_run_event} =
             event
             |> Map.from_struct()
             |> Map.put(:payload_ref, "https://lower.internal/payload")
             |> AgentRunEvent.new()
  end

  test "pending interactions and pending queries are product-safe DTOs" do
    assert {:ok, pending} =
             AgentPendingInteraction.new(%{
               pending_ref: "agent-pending://tenant-1/pending/1",
               ledger_ref: "agent-ledger://tenant-1/runs/1",
               decision_ref: "decision://tenant-1/decisions/1",
               tenant_ref: "tenant://one",
               actor_ref: "actor://one",
               kind: "approval_required",
               prompt_summary: "Approve tool class file.write?",
               requested_action_ref: "action://tenant-1/actions/1",
               authority_ref: "authority://tenant-1/decisions/1",
               opened_seq: 21,
               status: "open",
               expires_at: "2026-05-21T00:00:00Z"
             })

    assert pending.kind == :approval_required
    assert pending.status == :open

    assert {:ok, query} =
             PendingInteractionQuery.new(%{
               tenant_ref: "tenant://one",
               actor_ref: "actor://one",
               run_ref: "run://one",
               status: "open"
             })

    assert query.status == :open

    assert {:error, :invalid_agent_pending_interaction} =
             pending
             |> Map.from_struct()
             |> Map.put(:protocol_module, "A2A.Protocol.Message")
             |> AgentPendingInteraction.new()

    assert {:error, :invalid_pending_interaction_query} =
             query
             |> Map.from_struct()
             |> Map.put(:endpoint, "https://lower.internal")
             |> PendingInteractionQuery.new()
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

  defp base_turn_submission do
    %{
      idempotency_key: "idem-turn",
      actor_ref: "actor://one",
      run_ref: "run://one",
      kind: :user_input,
      payload_ref: "payload://one"
    }
  end
end
