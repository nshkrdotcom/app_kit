defmodule AppKit.Bridges.MezzanineBridge.AgentIntakeAdapterTest do
  use ExUnit.Case, async: true

  alias AppKit.Bridges.MezzanineBridge.{AgentIntakeAdapter, HeadlessAdapter}

  alias AppKit.Core.AgentIntake.{
    AgentRunCursor,
    AgentRunRequest,
    RunOutcomeFuture,
    TurnSubmission
  }

  alias AppKit.Core.{PersistencePosture, RequestContext}

  alias AppKit.Core.RuntimeReadback.{
    CommandResult,
    RefreshRequest,
    RuntimeRunDetail
  }

  alias Mezzanine.Runs.{Acceptance, Event, TurnAcceptance}

  @run_ref "run://mezzanine/tenant-1/agent-1"
  @program_id "22222222-2222-4222-8222-222222222222"
  @work_class_id "33333333-3333-4333-8333-333333333333"
  @digest "sha256:" <> String.duplicate("a", 64)
  @now ~U[2026-07-20 20:00:00.000000Z]

  defmodule FakeOwner do
    alias Mezzanine.Runs.TurnAcceptance

    def accept_run(command, opts) do
      send(Keyword.fetch!(opts, :test_pid), {:accepted_command, command})
      {:ok, Keyword.fetch!(opts, :acceptance)}
    end

    def submit_turn(command, opts) do
      send(Keyword.fetch!(opts, :test_pid), {:submitted_turn_command, command})

      acceptance =
        TurnAcceptance.new!(%{
          command_ref: command.command_ref,
          run_ref: command.run_ref,
          turn_ref: command.turn_ref,
          event_ref: "event://mezzanine/tenant-1/follow-up",
          signal_outbox_ref: "outbox://mezzanine/tenant-1/follow-up",
          cursor: %{
            run_ref: command.run_ref,
            last_event_ref: "event://mezzanine/tenant-1/follow-up",
            sequence: 3
          },
          run_revision: 2,
          state: "accepted",
          idempotent_replay?: Keyword.get(opts, :turn_replay?, false)
        })

      {:ok, Keyword.get(opts, :turn_acceptance, acceptance)}
    end

    def fetch_projection(run_ref, opts) do
      send(Keyword.fetch!(opts, :test_pid), {:projection_read, run_ref})
      {:ok, Keyword.fetch!(opts, :projection)}
    end

    def list_events(run_ref, cursor, opts) do
      send(Keyword.fetch!(opts, :test_pid), {:event_read, run_ref, cursor, opts[:limit]})
      {:ok, Keyword.fetch!(opts, :events)}
    end

    def list_provider_events(turn_ref, after_sequence, opts) do
      send(
        Keyword.fetch!(opts, :test_pid),
        {:provider_event_read, turn_ref, after_sequence, opts[:limit]}
      )

      {:ok, Keyword.get(opts, :provider_events, [])}
    end
  end

  defmodule ConflictingOwner do
    def accept_run(_command, _opts), do: {:error, :idempotency_conflict}
  end

  defmodule FakeWorkControl do
    alias AppKit.Core.PersistencePosture
    alias AppKit.Core.RuntimeReadback.CommandResult

    def control_run(context, request, opts) do
      send(Keyword.fetch!(opts, :test_pid), {:cancel_control, context, request})

      CommandResult.new(%{
        command_ref: "command://mezzanine/tenant-1/cancel-1",
        command_kind: :cancel,
        accepted?: true,
        coalesced?: false,
        status: :accepted,
        authority_state: :admitted,
        authority_refs: [
          "authority://citadel/tenant-1/cancel-1",
          "decision://citadel/tenant-1/cancel-1"
        ],
        workflow_effect_state: "queued_signal",
        projection_state: :cancel_requested,
        trace_id: context.trace_id,
        correlation_id: context.trace_id,
        receipt_ref: "event://mezzanine/tenant-1/cancel-1",
        idempotency_key: request.idempotency_key,
        persistence_posture: PersistencePosture.durable(:runtime_projection)
      })
    end
  end

  defmodule FakeRefreshOwner do
    alias AppKit.Core.PersistencePosture
    alias AppKit.Core.RuntimeReadback.CommandResult

    def request_runtime_refresh(context, request, opts) do
      send(Keyword.fetch!(opts, :test_pid), {:runtime_refresh, context, request})

      case Keyword.fetch(opts, :refresh_result) do
        {:ok, result} ->
          {:ok, result}

        :error ->
          CommandResult.new(%{
            command_ref: "command://mezzanine/tenant-1/refresh-1",
            command_kind: :refresh,
            accepted?: true,
            coalesced?: false,
            status: :accepted,
            authority_state: :admitted,
            authority_refs: ["authority://citadel/tenant-1/refresh-1"],
            workflow_effect_state: "queued_signal",
            projection_state: :pending,
            trace_id: context.trace_id,
            correlation_id: context.trace_id,
            receipt_ref: "event://mezzanine/tenant-1/refresh-1",
            idempotency_key: request.idempotency_key,
            persistence_posture: PersistencePosture.durable(:runtime_projection)
          })
      end
    end
  end

  test "maps AppKit intake to canonical acceptance and preserves the durable owner refs" do
    acceptance = acceptance()

    assert {:ok, %RunOutcomeFuture{} = future} =
             AgentIntakeAdapter.start_agent_run(
               context(),
               request(),
               agent_intake_service: FakeOwner,
               acceptance: acceptance,
               program_id: @program_id,
               work_class_id: @work_class_id,
               test_pid: self()
             )

    assert_receive {:accepted_command, command}
    assert command.run_ref == @run_ref
    assert command.tenant_ref == "tenant-1"
    assert command.installation_ref == "installation://synapse/prod"
    assert command.actor_ref == "actor://synapse/operator"
    assert command.program_id == @program_id
    assert command.work_class_id == @work_class_id
    assert command.first_turn.input_artifact_ref == "artifact://outer-brain/input-1"
    assert command.runtime_profile_ref == "runtime-profile://app-kit/fixture-runtime"
    assert String.starts_with?(command.request_hash, "sha256:")

    assert future.run_ref == @run_ref
    assert future.command_ref == acceptance.command_ref

    assert future.governed_effect_refs["workflow_outbox_ref"] ==
             acceptance.workflow_outbox_ref
  end

  test "normalizes owner conflicts without manufacturing acceptance" do
    assert {:error, error} =
             AgentIntakeAdapter.start_agent_run(
               context(),
               request(),
               agent_intake_service: ConflictingOwner,
               program_id: @program_id,
               work_class_id: @work_class_id
             )

    assert error.code == "idempotency_conflict"
    assert error.kind == :conflict
    refute error.retryable
  end

  test "submits a durable reference-only follow-up turn and maps the owner receipt" do
    submission = turn_submission()

    assert {:ok, %CommandResult{} = result} =
             AgentIntakeAdapter.submit_agent_turn(
               context(),
               submission,
               agent_intake_service: FakeOwner,
               turn_authority_ref: "authority://citadel/tenant-1/turn-1",
               test_pid: self()
             )

    assert_receive {:submitted_turn_command, command}
    assert command.idempotency_key == submission.idempotency_key
    assert command.tenant_ref == "tenant-1"
    assert command.actor_ref == submission.actor_ref
    assert command.authority_ref == "authority://citadel/tenant-1/turn-1"
    assert command.run_ref == submission.run_ref
    assert command.kind == :user_input
    assert command.payload_ref == submission.payload_ref
    assert command.params == submission.params
    assert String.starts_with?(command.command_ref, "command://app-kit/agent-turn/")
    assert String.starts_with?(command.turn_ref, "turn://mezzanine/")
    assert String.starts_with?(command.request_hash, "sha256:")
    assert String.starts_with?(command.payload_digest, "sha256:")
    refute Map.has_key?(Map.from_struct(command), :payload)

    assert result.command_ref == command.command_ref
    assert result.command_kind == :submit_turn
    assert result.accepted?
    refute result.coalesced?
    assert result.authority_refs == ["authority://citadel/tenant-1/turn-1"]
    assert result.workflow_effect_state == "queued_signal"
    assert result.receipt_ref == "event://mezzanine/tenant-1/follow-up"
    assert result.persistence_posture.durable?
  end

  test "preserves durable replay truth and rejects mismatched owner acceptance" do
    opts = [
      agent_intake_service: FakeOwner,
      turn_authority_ref: "authority://citadel/tenant-1/turn-1",
      turn_replay?: true,
      test_pid: self()
    ]

    assert {:ok, %CommandResult{coalesced?: true}} =
             AgentIntakeAdapter.submit_agent_turn(context(), turn_submission(), opts)

    assert_receive {:submitted_turn_command, command}

    mismatched =
      TurnAcceptance.new!(%{
        command_ref: command.command_ref,
        run_ref: command.run_ref,
        turn_ref: "turn://mezzanine/tenant-1/wrong",
        event_ref: "event://mezzanine/tenant-1/follow-up",
        signal_outbox_ref: "outbox://mezzanine/tenant-1/follow-up",
        cursor: %{
          run_ref: command.run_ref,
          last_event_ref: "event://mezzanine/tenant-1/follow-up",
          sequence: 3
        },
        run_revision: 2,
        state: "accepted",
        idempotent_replay?: false
      })

    assert {:error, error} =
             AgentIntakeAdapter.submit_agent_turn(
               context(),
               turn_submission(),
               Keyword.put(opts, :turn_acceptance, mismatched)
             )

    assert error.code == "turn_acceptance_mismatch"
    assert error.kind == :validation
  end

  test "turn submission requires actor continuity and explicit authority before dispatch" do
    opts = [agent_intake_service: FakeOwner, test_pid: self()]

    assert {:error, missing_authority} =
             AgentIntakeAdapter.submit_agent_turn(context(), turn_submission(), opts)

    assert missing_authority.code == "missing_turn_authority_ref"
    assert missing_authority.kind == :validation
    refute_received {:submitted_turn_command, _command}

    mismatched = %{turn_submission() | actor_ref: "actor://synapse/other"}

    assert {:error, actor_error} =
             AgentIntakeAdapter.submit_agent_turn(
               context(),
               mismatched,
               Keyword.put(opts, :turn_authority_ref, "authority://citadel/turn-1")
             )

    assert actor_error.code == "operator_actor_context_mismatch"
    assert actor_error.kind == :authorization
    refute_received {:submitted_turn_command, _command}
  end

  test "agent cancellation delegates to durable recovery control with explicit version truth" do
    assert {:ok, %CommandResult{command_kind: :cancel}} =
             AgentIntakeAdapter.cancel_agent_run(
               context(),
               @run_ref,
               work_control_service: FakeWorkControl,
               cancel_idempotency_key: "synapse-agent-1-cancel-1",
               expected_control_row_version: 7,
               cancel_reason: "Operator requested cancellation",
               test_pid: self()
             )

    assert_receive {:cancel_control, context, request}
    assert context.actor_ref.id == "actor://synapse/operator"
    assert request.run_ref == @run_ref
    assert request.action == :cancel
    assert request.idempotency_key == "synapse-agent-1-cancel-1"
    assert request.params.expected_control_row_version == 7
    assert request.params.reason == "Operator requested cancellation"

    assert {:error, missing_version} =
             AgentIntakeAdapter.cancel_agent_run(
               context(),
               @run_ref,
               work_control_service: FakeWorkControl,
               cancel_idempotency_key: "synapse-agent-1-cancel-2",
               test_pid: self()
             )

    assert missing_version.code == "invalid_expected_control_row_version"
    assert missing_version.kind == :validation
  end

  test "runtime refresh requires an exact durable owner receipt" do
    request =
      RefreshRequest.new!(%{
        idempotency_key: "synapse-agent-1-refresh-1",
        actor_ref: "actor://synapse/operator",
        scope_ref: @run_ref
      })

    assert {:ok, %CommandResult{command_kind: :refresh} = result} =
             HeadlessAdapter.request_runtime_refresh(
               context(),
               request,
               runtime_refresh_service: FakeRefreshOwner,
               test_pid: self()
             )

    assert result.receipt_ref == "event://mezzanine/tenant-1/refresh-1"
    assert result.persistence_posture.durable?
    assert_receive {:runtime_refresh, _context, ^request}

    assert {:error, unavailable} =
             HeadlessAdapter.request_runtime_refresh(context(), request, [])

    assert unavailable.code == "runtime_refresh_owner_not_configured"
    assert unavailable.kind == :boundary

    {:ok, non_durable} =
      CommandResult.new(%{
        command_ref: "command://bridge/local-refresh",
        command_kind: :refresh,
        accepted?: true,
        coalesced?: false,
        status: :accepted,
        authority_refs: ["authority://citadel/refresh"],
        workflow_effect_state: "pending_signal",
        receipt_ref: "event://bridge/local-refresh",
        idempotency_key: request.idempotency_key,
        persistence_posture: PersistencePosture.memory(:runtime_projection)
      })

    assert {:error, invalid_receipt} =
             HeadlessAdapter.request_runtime_refresh(
               context(),
               request,
               runtime_refresh_service: FakeRefreshOwner,
               refresh_result: non_durable,
               test_pid: self()
             )

    assert invalid_receipt.code == "invalid_runtime_refresh_receipt"
  end

  test "await and catch-up read canonical durable projection and ordered events" do
    projection = projection(acceptance())
    opts = owner_opts(projection, events())

    assert {:ok, %RunOutcomeFuture{run_ref: @run_ref}} =
             AgentIntakeAdapter.await_agent_outcome(context(), @run_ref, request(), opts)

    assert_receive {:projection_read, @run_ref}

    assert {:ok, page} = AgentIntakeAdapter.catch_up_agent_events(context(), cursor(), opts)
    assert page.has_more?
    assert Enum.map(page.events, & &1.event_seq) == [1]
    assert page.cursor.last_seq_seen == 1
    assert page.cursor.cursor_ref == "event://mezzanine/tenant-1/1"
    assert page.next_cursor_ref == page.cursor.cursor_ref
    assert_receive {:event_read, @run_ref, nil, 2}
  end

  test "catch-up presents every canonical Mezzanine run-ledger event" do
    owner_events = [
      event(1, "run_accepted"),
      event(2, "turn_accepted"),
      event(3, "provider_event_committed"),
      event(4, "turn_completed"),
      event(5, "run_control_updated")
    ]

    opts =
      projection(acceptance())
      |> owner_opts(owner_events)
      |> Keyword.put(:event_limit, 10)

    assert {:ok, page} = AgentIntakeAdapter.catch_up_agent_events(context(), cursor(), opts)

    assert Enum.map(page.events, & &1.event_kind) == [
             :run_started,
             :conversation_delta,
             :conversation_delta,
             :conversation_delta,
             :execution_update
           ]

    assert page.cursor.last_seq_seen == 5
    refute page.has_more?
  end

  test "headless run detail is durable owner readback, not a bridge-local projection" do
    projection = projection(acceptance())

    assert {:ok, %RuntimeRunDetail{} = detail} =
             HeadlessAdapter.runtime_run_detail(
               context(),
               @run_ref,
               %{},
               owner_opts(projection, events())
             )

    assert detail.run_ref == @run_ref
    assert detail.runtime_row.persistence_posture.durable?
    assert detail.runtime_row.extensions["owner_event_sequence"] == 2
    assert detail.runtime_row.extensions["control"]["state"] == "outcome_unknown"
    assert detail.runtime_row.extensions["control"]["row_version"] == 7
    refute Map.has_key?(detail.runtime_row.extensions["control"], "private_payload")
    assert Enum.map(detail.events, & &1.event_seq) == [1, 2]
    assert detail.turns == []
    assert_receive {:projection_read, @run_ref}
    assert_receive {:event_read, @run_ref, nil, 500}
    refute_received {:provider_event_read, _, _, _}
  end

  test "headless run detail projects the durable model turn and its ordered provider events" do
    projection =
      acceptance()
      |> projection()
      |> put_in([:projection, "model_turn"], model_turn_projection())

    provider_events = [
      provider_event(1, "response.output_text.delta", "provisional"),
      provider_event(2, "response.completed", "committed")
    ]

    assert {:ok, %RuntimeRunDetail{} = detail} =
             HeadlessAdapter.runtime_run_detail(
               context(),
               @run_ref,
               %{},
               owner_opts(projection, events(), provider_events)
             )

    assert [turn] = detail.turns
    assert turn.turn_ref == "turn://mezzanine/tenant-1/agent-1/1"
    assert turn.state == "completed"
    assert turn.reply_artifact_ref == "artifact://jido/tenant-1/reply-1"
    assert turn.cursor["sequence"] == 2
    assert Enum.map(turn.events, & &1.sequence) == [1, 2]
    assert Enum.map(turn.events, & &1.commit_state) == ["provisional", "committed"]

    assert_receive {:provider_event_read, "turn://mezzanine/tenant-1/agent-1/1", 0, 500}
  end

  test "headless run detail rejects provider event gaps and cross-run events" do
    projection =
      acceptance()
      |> projection()
      |> put_in([:projection, "model_turn"], model_turn_projection())

    assert {:error, gap_error} =
             HeadlessAdapter.runtime_run_detail(
               context(),
               @run_ref,
               %{},
               owner_opts(projection, events(), [
                 provider_event(2, "response.completed", "committed")
               ])
             )

    assert gap_error.code == "non_contiguous_provider_event"
    assert gap_error.kind == :validation

    cross_run =
      provider_event(1, "response.completed", "committed")
      |> Map.put(:run_ref, "run://mezzanine/tenant-1/other")

    assert {:error, run_error} =
             HeadlessAdapter.runtime_run_detail(
               context(),
               @run_ref,
               %{},
               owner_opts(projection, events(), [cross_run])
             )

    assert run_error.code == "cursor_run_mismatch"
  end

  test "readback fails closed for cross-tenant, run-mismatched, and non-contiguous owner data" do
    cross_tenant = %{projection(acceptance()) | tenant_ref: "tenant://other"}

    assert {:error, tenant_error} =
             AgentIntakeAdapter.await_agent_outcome(
               context(),
               @run_ref,
               request(),
               owner_opts(cross_tenant, events())
             )

    assert tenant_error.code == "unauthorized_lower_read"
    assert tenant_error.kind == :authorization

    wrong_run = %{projection(acceptance()) | run_ref: "run://mezzanine/tenant-1/other"}

    assert {:error, run_error} =
             HeadlessAdapter.runtime_run_detail(
               context(),
               @run_ref,
               %{},
               owner_opts(wrong_run, events())
             )

    assert run_error.code == "cursor_run_mismatch"
    assert run_error.kind == :validation

    [first, second] = events()
    non_contiguous = [first, %{second | sequence: 3}]

    assert {:error, sequence_error} =
             AgentIntakeAdapter.catch_up_agent_events(
               context(),
               cursor(),
               owner_opts(projection(acceptance()), non_contiguous)
             )

    assert sequence_error.code == "non_contiguous_event"
    assert sequence_error.kind == :validation

    assert {:error, cursor_tenant_error} =
             AgentIntakeAdapter.catch_up_agent_events(
               context(),
               %{cursor() | tenant_ref: "tenant://other"},
               owner_opts(projection(acceptance()), events())
             )

    assert cursor_tenant_error.code == "unauthorized_lower_read"
    assert cursor_tenant_error.kind == :authorization
  end

  defp context do
    {:ok, context} =
      RequestContext.new(%{
        trace_id: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        actor_ref: %{id: "actor://synapse/operator", kind: :human},
        tenant_ref: %{id: "tenant-1"},
        installation_ref: %{
          id: "installation://synapse/prod",
          pack_slug: "synapse",
          status: :active
        }
      })

    context
  end

  defp request do
    AgentRunRequest.new!(%{
      tenant_ref: "tenant://tenant-1",
      installation_ref: "installation://synapse/prod",
      subject_ref: "subject://synapse/agent-1",
      actor_ref: "actor://synapse/operator",
      profile_bundle: %{
        source_profile_ref: :fixture_source,
        runtime_profile_ref: :fixture_runtime,
        tool_scope_ref: :fixture_tools,
        evidence_profile_ref: :fixture_evidence,
        publication_profile_ref: :none,
        review_profile_ref: :fixture_review,
        memory_profile_ref: :none,
        projection_profile_ref: :fixture_projection
      },
      tool_catalog_ref: "tool-catalog://synapse/default",
      budget_ref: "budget://synapse/default",
      recall_scope_ref: "recall://synapse/default",
      idempotency_key: "synapse-agent-1",
      trace_id: "trace://synapse/agent-1",
      correlation_id: "correlation://synapse/agent-1",
      submission_dedupe_key: "synapse-agent-1",
      initial_input_ref: "artifact://outer-brain/input-1",
      params: %{
        run_ref: @run_ref,
        authority_context_ref: "authority-context://synapse/agent-1"
      }
    })
  end

  defp turn_submission do
    TurnSubmission.new!(%{
      idempotency_key: "synapse-agent-1-follow-up-1",
      actor_ref: "actor://synapse/operator",
      run_ref: @run_ref,
      kind: :user_input,
      payload_ref: "artifact://outer-brain/input-2",
      cursor_ref: "event://mezzanine/tenant-1/2",
      params: %{"input_summary" => "Reference-bound follow-up"}
    })
  end

  defp acceptance do
    Acceptance.new!(%{
      command_ref: "command://mezzanine/tenant-1/agent-1",
      run_ref: @run_ref,
      turn_ref: "turn://mezzanine/tenant-1/agent-1/1",
      event_ref: "event://mezzanine/tenant-1/1",
      workflow_outbox_ref: "outbox://mezzanine/tenant-1/agent-1",
      cursor: %{
        run_ref: @run_ref,
        last_event_ref: "event://mezzanine/tenant-1/1",
        sequence: 1
      },
      run_revision: 1,
      state: "accepted"
    })
  end

  defp projection(acceptance) do
    %{
      run_ref: @run_ref,
      tenant_ref: "tenant://tenant-1",
      subject_ref: "subject://synapse/agent-1",
      latest_turn_ref: acceptance.turn_ref,
      latest_event_ref: "event://mezzanine/tenant-1/2",
      status: "accepted",
      event_sequence: 2,
      run_revision: 1,
      control: %{
        state: "outcome_unknown",
        generation: 1,
        attempt_sequence: 1,
        sequence: 6,
        row_version: 7,
        attempt_ref: "attempt://mezzanine/agent-1/1",
        generation_ref: "generation://mezzanine/agent-1/1",
        external_operation_ref: "operation://codex/agent-1",
        fence_epoch: 2,
        reconciliation_attempts: 1,
        last_error: "error://mezzanine/outcome-unknown",
        updated_at: @now,
        private_payload: %{"prompt" => "must not cross AppKit"}
      },
      projection: %{"acceptance" => Acceptance.dump(acceptance)},
      updated_at: @now
    }
  end

  defp model_turn_projection do
    %{
      "turn_ref" => "turn://mezzanine/tenant-1/agent-1/1",
      "run_ref" => @run_ref,
      "tenant_ref" => "tenant://tenant-1",
      "context_artifact_ref" => "artifact://outer-brain/tenant-1/context-1",
      "context_digest" => @digest,
      "prompt_artifact_ref" => "artifact://outer-brain/tenant-1/prompt-1",
      "decision_ref" => "decision://citadel/tenant-1/model-1",
      "grant_ref" => "grant://citadel/tenant-1/model-1",
      "provider_attempt_ref" => "attempt://jido/gemini/tenant-1/1",
      "provider_family" => "gemini",
      "model_ref" => "model://gemini/gemini-2.5-flash",
      "operation_ref" => "operation://inference/completion/tenant-1/1",
      "state" => "completed",
      "provisional_event_sequence" => 2,
      "committed_event_sequence" => 2,
      "last_committed_provider_event_ref" => "provider-event://jido/tenant-1/2",
      "reply_publication_ref" => "publication://outer-brain/tenant-1/reply-1",
      "reply_artifact_ref" => "artifact://jido/tenant-1/reply-1",
      "continuation_context_ref" => "context://outer-brain/tenant-1/2",
      "continuation_context_digest" => @digest,
      "cursor" => %{
        "turn_ref" => "turn://mezzanine/tenant-1/agent-1/1",
        "last_provider_event_ref" => "provider-event://jido/tenant-1/2",
        "sequence" => 2
      },
      "row_version" => 4,
      "updated_at" => @now
    }
  end

  defp provider_event(sequence, event_type, commit_state) do
    %{
      event_ref: "provider-event://jido/tenant-1/#{sequence}",
      run_ref: @run_ref,
      turn_ref: "turn://mezzanine/tenant-1/agent-1/1",
      provider_attempt_ref: "attempt://jido/gemini/tenant-1/1",
      sequence: sequence,
      event_type: event_type,
      stream: "assistant",
      payload_ref: "artifact://jido/tenant-1/provider-event-#{sequence}",
      payload_digest: @digest,
      commit_state: commit_state,
      observed_at: DateTime.add(@now, sequence, :second),
      committed_at:
        if(commit_state == "committed", do: DateTime.add(@now, sequence + 1, :second)),
      row_version: if(commit_state == "committed", do: 2, else: 1)
    }
  end

  defp cursor do
    AgentRunCursor.new!(%{
      cursor_ref: "event://mezzanine/tenant-1/0",
      ledger_ref: @run_ref,
      tenant_ref: "tenant://tenant-1",
      actor_ref: "actor://synapse/operator",
      last_seq_seen: 0,
      visibility: :product
    })
  end

  defp events do
    [event(1, "run_accepted"), event(2, "turn_accepted")]
  end

  defp event(sequence, event_type) do
    Event.new!(%{
      event_ref: "event://mezzanine/tenant-1/#{sequence}",
      run_ref: @run_ref,
      tenant_ref: "tenant://tenant-1",
      event_type: event_type,
      event_version: 1,
      sequence: sequence,
      command_ref: "command://mezzanine/tenant-1/agent-1",
      correlation_ref: "correlation://synapse/agent-1",
      payload_ref: "artifact://mezzanine/tenant-1/#{sequence}",
      payload_digest: @digest,
      recorded_at: DateTime.add(@now, sequence, :second),
      row_version: sequence
    })
  end

  defp owner_opts(projection, events, provider_events \\ []) do
    [
      agent_intake_service: FakeOwner,
      projection: projection,
      events: events,
      provider_events: provider_events,
      event_limit: 1,
      test_pid: self()
    ]
  end
end
