defmodule AppKit.Bridges.MezzanineBridgeGovernedEffectIntegrationTest do
  use ExUnit.Case, async: false

  alias AppKit.Core.{GovernedEffectDTO, RequestContext}
  alias AppKit.Bridges.MezzanineBridge
  alias AppKit.EffectSurface
  alias Mezzanine.Control.ControlSession
  alias Mezzanine.Programs.{PolicyBundle, Program}
  alias Mezzanine.Review.ReviewUnit
  alias Mezzanine.Runs.{Run, RunSeries}
  alias Mezzanine.Work.{WorkClass, WorkObject}

  @repos [
    Mezzanine.Audit.Repo,
    Mezzanine.Execution.Repo,
    Mezzanine.Decisions.Repo,
    Mezzanine.OpsDomain.Repo
  ]

  setup_all do
    Enum.each(
      [
        :mezzanine_audit_engine,
        :mezzanine_execution_engine,
        :mezzanine_decision_engine,
        :mezzanine_ops_domain
      ],
      fn app ->
        {:ok, _started} = Application.ensure_all_started(app)
      end
    )
  end

  setup do
    Enum.each(@repos, fn repo ->
      :ok = Ecto.Adapters.SQL.Sandbox.checkout(repo)
      Ecto.Adapters.SQL.Sandbox.mode(repo, {:shared, self()})
    end)

    :ok
  end

  test "AppKit drives durable review, dispatch, ambiguity, continuation, and restart-safe readback" do
    fixture = effect_fixture()
    context = context!(fixture)
    proposal = proposal_attrs(fixture)

    assert {:ok, %GovernedEffectDTO{status: "authorized"} = opened} =
             EffectSurface.propose_effect(context, proposal)

    assert opened.review.status == "pending"
    assert opened.review.review_ref == proposal.review_ref
    assert opened.decision_ref == proposal.decision_ref
    assert opened.grant_ref == proposal.grant_ref

    assert opened.pinned_tool_manifest["manifest_hash"] ==
             proposal.pinned_tool_manifest.manifest_hash

    assert opened.reviewed_operation["relative_path"] ==
             proposal.reviewed_operation.relative_path

    assert opened.reviewed_operation["content_digest"] ==
             proposal.reviewed_operation.content_digest

    assert {:error, %{code: "bridge_error"}} =
             EffectSurface.begin_dispatch(
               context,
               opened.owner_execution_ref,
               %{expected_row_version: opened.row_version}
             )

    assert {:ok, %{status: :completed}} =
             MezzanineBridge.record_decision_by_id(
               context,
               fixture.review.id,
               %{
                 decision: "accept",
                 reason: "reviewed exact named-file digest",
                 trace_id: context.trace_id,
                 causation_id: "cause://p04/review",
                 idempotency_key: "p04-review-#{fixture.review.id}"
               },
               program_id: fixture.program.id
             )

    assert {:ok, %GovernedEffectDTO{status: "dispatching"} = dispatching} =
             EffectSurface.begin_dispatch(
               context,
               opened.owner_execution_ref,
               %{expected_row_version: opened.row_version}
             )

    assert dispatching.review.status == "accepted"
    assert dispatching.review.accepted_actor_ref == context.actor_ref.id

    assert {:ok, %GovernedEffectDTO{status: "running"} = running} =
             EffectSurface.record_accepted(
               context,
               opened.owner_execution_ref,
               %{
                 expected_row_version: dispatching.row_version,
                 attempt_ref: proposal.attempt_ref,
                 external_ref: "codex-thread://p04/#{fixture.review.id}",
                 accepted_receipt_ref: "receipt://p04/accepted/#{fixture.review.id}"
               }
             )

    assert {:ok, %GovernedEffectDTO{status: "ambiguous"} = ambiguous} =
             EffectSurface.record_receipt(
               context,
               opened.owner_execution_ref,
               %{
                 expected_row_version: running.row_version,
                 receipt_ref: "receipt://p04/ambiguous/#{fixture.review.id}",
                 receipt_state: "ambiguous",
                 ambiguity_state: "outcome_unknown",
                 continuation_target: %{
                   kind: "owner_command",
                   owner: "jido_integration",
                   command: "reconcile_effect_outcome",
                   idempotency_key: "p04-reconcile-#{fixture.review.id}"
                 },
                 cleanup: %{
                   status: "completed",
                   cleanup_ref: "cleanup://p04/#{fixture.review.id}",
                   managed_session_ref: "managed-session://p04/#{fixture.review.id}",
                   credential_lease_ref: "credential-lease://p04/#{fixture.review.id}",
                   materialization_ref: "materialization://p04/#{fixture.review.id}",
                   session_terminated: true,
                   materialization_removed: true,
                   credential_lease_released: true
                 }
               }
             )

    assert ambiguous.receipt.cleanup.materialization_removed
    assert ambiguous.ambiguity.state == "outcome_unknown"
    refute ambiguous.ambiguity.effect_retry_allowed
    assert ambiguous.continuation.target_operation == "reconcile_effect_outcome"

    assert {:ok, %GovernedEffectDTO{} = by_owner_ref} =
             EffectSurface.get_effect(context, opened.owner_execution_ref)

    assert {:ok, %GovernedEffectDTO{} = by_idempotency} =
             EffectSurface.get_effect_by_idempotency(context, context.idempotency_key)

    assert by_owner_ref == by_idempotency
    assert by_owner_ref.status == "ambiguous"

    safe_dump = GovernedEffectDTO.dump(by_owner_ref)
    refute contains_struct?(safe_dump)
    refute Map.has_key?(safe_dump["reviewed_operation"], "content")
    refute Map.has_key?(safe_dump["reviewed_operation"], "workspace_root")

    execution_id =
      String.replace_prefix(opened.owner_execution_ref, "effect-execution://", "")

    Ecto.Adapters.SQL.query!(
      Mezzanine.Execution.Repo,
      """
      UPDATE execution_records
      SET dispatch_envelope =
        jsonb_set(
          dispatch_envelope,
          '{reviewed_operation,content}',
          to_jsonb('smuggled file body'::text),
          true
        )
      WHERE id = $1::uuid
      """,
      [Ecto.UUID.dump!(execution_id)]
    )

    assert {:error, :invalid_governed_effect_dto} =
             EffectSurface.get_effect(context, opened.owner_execution_ref)
  end

  test "AppKit rejects secrets and blind effect retry before a durable command" do
    fixture = effect_fixture()
    context = context!(fixture)

    unsafe_proposal =
      fixture
      |> proposal_attrs()
      |> Map.put(:workspace_root, "/tmp/ambient-workspace")

    assert {:error, :invalid_governed_effect_proposal} =
             EffectSurface.propose_effect(context, unsafe_proposal)

    assert {:error, :invalid_effect_receipt_command} =
             EffectSurface.record_receipt(
               context,
               "effect-execution://00000000-0000-0000-0000-000000000001",
               %{
                 expected_row_version: 1,
                 receipt_ref: "receipt://p04/unknown",
                 receipt_state: "outcome_unknown",
                 continuation_target: %{
                   kind: "owner_command",
                   owner: "jido_integration",
                   command: "retry_effect",
                   idempotency_key: "p04-blind-retry"
                 }
               }
             )
  end

  defp effect_fixture do
    tenant_id = "tenant-p04-#{System.unique_integer([:positive])}"
    actor = %{tenant_id: tenant_id}

    {:ok, program} =
      Program.create_program(
        %{
          slug: "p04-#{System.unique_integer([:positive])}",
          name: "P04 AppKit Governed Effect",
          product_family: "operator_stack",
          configuration: %{},
          metadata: %{}
        },
        actor: actor,
        tenant: tenant_id
      )

    {:ok, policy_bundle} =
      PolicyBundle.load_bundle(
        %{
          program_id: program.id,
          name: "p04",
          version: "1.0.0",
          policy_kind: :workflow_md,
          source_ref: "WORKFLOW.md",
          body: "# P04 governed effect",
          metadata: %{}
        },
        actor: actor,
        tenant: tenant_id
      )

    {:ok, work_class} =
      WorkClass.create_work_class(
        %{
          program_id: program.id,
          name: "p04_effect_#{System.unique_integer([:positive])}",
          kind: "coding_task",
          intake_schema: %{"required" => ["title"]},
          policy_bundle_id: policy_bundle.id,
          default_review_profile: %{"required" => true},
          default_run_profile: %{"runtime" => "session"}
        },
        actor: actor,
        tenant: tenant_id
      )

    {:ok, work_object} =
      WorkObject.ingest(
        %{
          program_id: program.id,
          work_class_id: work_class.id,
          external_ref: "app-kit:p04:#{System.unique_integer([:positive])}",
          title: "Reviewed Codex file effect",
          description: "Create one reviewed named file",
          priority: 50,
          source_kind: "app_kit",
          payload: %{"effect_ref" => "effect://p04"},
          normalized_payload: %{"effect_ref" => "effect://p04"}
        },
        actor: actor,
        tenant: tenant_id
      )

    {:ok, control_session} =
      ControlSession.open(
        %{program_id: program.id, work_object_id: work_object.id},
        actor: actor,
        tenant: tenant_id
      )

    {:ok, run_series} =
      RunSeries.open_series(
        %{work_object_id: work_object.id, control_session_id: control_session.id},
        actor: actor,
        tenant: tenant_id
      )

    {:ok, run} =
      Run.schedule(
        %{
          run_series_id: run_series.id,
          attempt: 1,
          runtime_profile: %{"capability_id" => "codex.session.turn"},
          grant_profile: %{"effect_mode" => "managed_account_local_effect"}
        },
        actor: actor,
        tenant: tenant_id
      )

    {:ok, review} =
      ReviewUnit.create_review_unit(
        %{
          work_object_id: work_object.id,
          run_id: run.id,
          review_kind: :code_review,
          decision_profile: %{"required_decisions" => 1},
          reviewer_actor: %{"kind" => "human", "ref" => "operator://p04"}
        },
        actor: actor,
        tenant: tenant_id
      )

    %{
      tenant_id: tenant_id,
      program: program,
      work_object: work_object,
      run: run,
      review: review
    }
  end

  defp context!(fixture) do
    {:ok, context} =
      RequestContext.new(%{
        trace_id: "0123456789abcdef0123456789abcdef",
        actor_ref: %{id: "operator://p04", kind: "human"},
        tenant_ref: %{id: fixture.tenant_id},
        installation_ref: %{id: "installation://p04/local", pack_slug: "synapse"},
        request_id: "request://p04/#{fixture.review.id}",
        idempotency_key: "p04-effect-#{fixture.review.id}"
      })

    context
  end

  defp proposal_attrs(fixture) do
    suffix = fixture.review.id

    %{
      effect_ref: "effect://p04/#{suffix}",
      run_ref: "run://p04/#{fixture.run.id}",
      turn_ref: "turn://p04/#{suffix}",
      command_ref: "command://p04/#{suffix}",
      decision_ref: "decision://citadel/p04/#{suffix}",
      grant_ref: "grant://citadel/p04/#{suffix}",
      review_ref: "review://mezzanine/#{fixture.review.id}",
      subject_id: fixture.work_object.id,
      run_id: fixture.run.id,
      review_unit_id: fixture.review.id,
      target_ref: "target://codex/local/#{suffix}",
      attempt_ref: "attempt://p04/#{suffix}/1",
      capability_id: "codex.session.turn",
      effect_mode: "managed_account_local_effect",
      pinned_tool_manifest: %{
        manifest_ref: "manifest://codex/p04/#{suffix}",
        manifest_hash: "sha256:" <> String.duplicate("a", 64),
        action_ids: ["create_or_replace_one_named_text_file"]
      },
      reviewed_operation: %{
        operation: "create_or_replace",
        workspace_ref: "workspace://p04/#{suffix}",
        file_ref: "file://p04/RESULT.txt",
        relative_path: "RESULT.txt",
        content_digest: "sha256:" <> String.duplicate("b", 64)
      }
    }
  end

  defp contains_struct?(value) when is_map(value) do
    Map.has_key?(value, :__struct__) or Enum.any?(Map.values(value), &contains_struct?/1)
  end

  defp contains_struct?(value) when is_list(value), do: Enum.any?(value, &contains_struct?/1)
  defp contains_struct?(_value), do: false
end
