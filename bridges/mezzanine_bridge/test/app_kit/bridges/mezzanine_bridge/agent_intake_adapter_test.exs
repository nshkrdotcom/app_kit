defmodule AppKit.Bridges.MezzanineBridge.AgentIntakeAdapterTest do
  use ExUnit.Case, async: true

  alias AppKit.Bridges.MezzanineBridge.{AgentIntakeAdapter, HeadlessAdapter}
  alias AppKit.Core.AgentIntake.{AgentRunCursor, AgentRunRequest, RunOutcomeFuture}
  alias AppKit.Core.RequestContext
  alias AppKit.Core.RuntimeReadback.RuntimeRunDetail
  alias Mezzanine.Runs.{Acceptance, Event}

  @run_ref "run://mezzanine/tenant-1/agent-1"
  @program_id "22222222-2222-4222-8222-222222222222"
  @work_class_id "33333333-3333-4333-8333-333333333333"
  @digest "sha256:" <> String.duplicate("a", 64)
  @now ~U[2026-07-20 20:00:00.000000Z]

  defmodule FakeOwner do
    def accept_run(command, opts) do
      send(Keyword.fetch!(opts, :test_pid), {:accepted_command, command})
      {:ok, Keyword.fetch!(opts, :acceptance)}
    end

    def fetch_projection(run_ref, opts) do
      send(Keyword.fetch!(opts, :test_pid), {:projection_read, run_ref})
      {:ok, Keyword.fetch!(opts, :projection)}
    end

    def list_events(run_ref, cursor, opts) do
      send(Keyword.fetch!(opts, :test_pid), {:event_read, run_ref, cursor, opts[:limit]})
      {:ok, Keyword.fetch!(opts, :events)}
    end
  end

  defmodule ConflictingOwner do
    def accept_run(_command, _opts), do: {:error, :idempotency_conflict}
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
    assert Enum.map(detail.events, & &1.event_seq) == [1, 2]
    assert_receive {:projection_read, @run_ref}
    assert_receive {:event_read, @run_ref, nil, 500}
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
      projection: %{"acceptance" => Acceptance.dump(acceptance)},
      updated_at: @now
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

  defp owner_opts(projection, events) do
    [
      agent_intake_service: FakeOwner,
      projection: projection,
      events: events,
      event_limit: 1,
      test_pid: self()
    ]
  end
end
