defmodule AppKit.Bridges.MezzanineBridgeEffectAdapterTest do
  use ExUnit.Case, async: true

  alias AppKit.Bridges.MezzanineBridge.EffectAdapter

  alias AppKit.Core.{
    EffectAcceptanceDTO,
    EffectDispatchCommandDTO,
    EffectReceiptCommandDTO,
    GovernedEffectDTO,
    GovernedEffectProposalDTO,
    RequestContext
  }

  defmodule GovernedEffectService do
    def open(attrs) do
      send(self(), {:open, attrs})
      {:ok, result("authorized", 1)}
    end

    def begin_dispatch(owner_ref, attrs) do
      send(self(), {:begin_dispatch, owner_ref, attrs})
      {:ok, result("dispatching", 2)}
    end

    def record_accepted(owner_ref, attrs) do
      send(self(), {:record_accepted, owner_ref, attrs})
      {:ok, result("running", 3)}
    end

    def record_receipt(owner_ref, attrs) do
      send(self(), {:record_receipt, owner_ref, attrs})
      {:ok, result("ambiguous", 4, attrs)}
    end

    def fetch("effect-execution://smuggled") do
      smuggled =
        result("authorized", 1)
        |> put_in(
          [:execution, :dispatch_envelope, "reviewed_operation", "content"],
          "smuggled file body"
        )

      {:ok, smuggled}
    end

    def fetch(_owner_ref), do: {:ok, result("authorized", 1)}
    def fetch_by_idempotency(_installation_id, _key), do: {:ok, result("authorized", 1)}

    defp result(status, row_version, attrs \\ %{}) do
      receipt_ref = if status == "ambiguous", do: attrs.receipt_ref
      ambiguity_state = if status == "ambiguous", do: attrs.ambiguity_state

      %{
        effect_record: %{
          contract_version: 1,
          effect_ref: "effect://p04/1",
          run_ref: "run://p04/1",
          turn_ref: "turn://p04/1",
          command_ref: "command://p04/1",
          decision_ref: "decision://citadel/p04/1",
          grant_ref: "grant://citadel/p04/1",
          review_ref: "review://mezzanine/p04/1",
          target_ref: "target://codex/local/1",
          status: status,
          row_version: row_version,
          attempt_ref: if(status == "authorized", do: nil, else: "attempt://p04/1"),
          receipt_ref: receipt_ref,
          ambiguity_state: ambiguity_state
        },
        execution: %{
          id: "00000000-0000-0000-0000-000000000004",
          tenant_id: "tenant-p04",
          intent_snapshot: %{
            "review_unit_id" => "00000000-0000-0000-0000-000000000003"
          },
          dispatch_envelope: %{
            "pinned_tool_manifest" => %{
              "manifest_ref" => "manifest://codex/p04/1",
              "manifest_hash" => "sha256:" <> String.duplicate("a", 64),
              "action_ids" => ["create_or_replace_one_named_text_file"]
            },
            "reviewed_operation" => %{
              "operation" => "create_or_replace",
              "workspace_ref" => "workspace://p04/1",
              "file_ref" => "file://p04/RESULT.txt",
              "relative_path" => "RESULT.txt",
              "content_digest" => "sha256:" <> String.duplicate("b", 64)
            }
          },
          lower_receipt:
            if(status == "ambiguous",
              do: %{"continuation_ref" => "continuation://p04/1"},
              else: %{}
            )
        },
        continuation: if(status == "ambiguous", do: :stub_continuation)
      }
    end
  end

  defmodule ReviewQueryService do
    def get_effect_review("tenant-p04", "00000000-0000-0000-0000-000000000003") do
      {:ok,
       %{
         status: "accepted",
         row_version: 2,
         accepted_actor_ref: "operator://p04"
       }}
    end
  end

  defmodule EffectReadbackService do
    def get_effect(owner_ref, opts), do: opts[:governed_effect_service].fetch(owner_ref)

    def get_effect_by_idempotency(installation_id, key, opts),
      do: opts[:governed_effect_service].fetch_by_idempotency(installation_id, key)

    def get_continuation(_continuation, _opts) do
      {:ok,
       %{
         continuation_ref: "continuation://p04/1",
         status: "pending",
         target_kind: "owner_command",
         target_owner: "jido_integration",
         target_operation: "reconcile_effect_outcome",
         idempotency_key: "p04-reconcile-1",
         attempt_count: 0
       }}
    end
  end

  test "maps the exact product proposal to the durable owner command" do
    assert {:ok, proposal} = GovernedEffectProposalDTO.new(proposal_attrs())

    assert {:ok, %GovernedEffectDTO{status: "authorized"} = dto} =
             EffectAdapter.propose_effect(context!(), proposal, opts())

    assert dto.owner_execution_ref ==
             "effect-execution://00000000-0000-0000-0000-000000000004"

    assert dto.review.status == "accepted"

    assert dto.pinned_tool_manifest["action_ids"] == [
             "create_or_replace_one_named_text_file"
           ]

    assert dto.reviewed_operation["relative_path"] == "RESULT.txt"

    assert_receive {:open, command}
    assert command.tenant_id == "tenant-p04"
    assert command.installation_id == "installation://p04/local"
    assert command.idempotency_key == "p04-idempotency"
    assert command.reviewed_operation["relative_path"] == "RESULT.txt"
    refute Map.has_key?(command, :workspace_root)
  end

  test "maps dispatch, acceptance, ambiguity, and continuation without owner structs" do
    owner_ref = "effect-execution://00000000-0000-0000-0000-000000000004"
    context = context!()

    assert {:ok, dispatch} = EffectDispatchCommandDTO.new(%{expected_row_version: 1})

    assert {:ok, %GovernedEffectDTO{status: "dispatching"}} =
             EffectAdapter.begin_dispatch(context, owner_ref, dispatch, opts())

    assert_receive {:begin_dispatch, ^owner_ref,
                    %{
                      "expected_row_version" => 1,
                      actor_ref: %{"ref" => "operator://p04"}
                    }}

    assert {:ok, acceptance} =
             EffectAcceptanceDTO.new(%{
               expected_row_version: 2,
               attempt_ref: "attempt://p04/1",
               external_ref: "codex-thread://p04/1"
             })

    assert {:ok, %GovernedEffectDTO{status: "running"}} =
             EffectAdapter.record_accepted(context, owner_ref, acceptance, opts())

    assert_receive {:record_accepted, ^owner_ref,
                    %{submission_ref: %{"attempt_ref" => "attempt://p04/1"}}}

    assert {:ok, receipt} =
             EffectReceiptCommandDTO.new(%{
               expected_row_version: 3,
               receipt_ref: "receipt://p04/ambiguous",
               receipt_state: "ambiguous",
               ambiguity_state: "outcome_unknown",
               continuation_target: %{
                 kind: "owner_command",
                 owner: "jido_integration",
                 command: "reconcile_effect_outcome",
                 idempotency_key: "p04-reconcile-1"
               }
             })

    assert {:ok,
            %GovernedEffectDTO{
              status: "ambiguous",
              ambiguity: %{effect_retry_allowed: false},
              continuation: %{target_operation: "reconcile_effect_outcome"}
            } = dto} =
             EffectAdapter.record_receipt(context, owner_ref, receipt, opts())

    assert is_map(dto.review)
    refute Map.has_key?(Map.from_struct(dto), :workspace_root)
  end

  test "rejects material smuggled into a persisted dispatch envelope" do
    assert {:error, :invalid_governed_effect_dto} =
             EffectAdapter.get_effect(context!(), "effect-execution://smuggled", opts())
  end

  defp opts do
    [
      governed_effect_service: GovernedEffectService,
      effect_readback_service: EffectReadbackService,
      review_query_service: ReviewQueryService
    ]
  end

  defp context! do
    {:ok, context} =
      RequestContext.new(%{
        trace_id: "0123456789abcdef0123456789abcdef",
        actor_ref: %{id: "operator://p04", kind: "human"},
        tenant_ref: %{id: "tenant-p04"},
        installation_ref: %{id: "installation://p04/local", pack_slug: "synapse"},
        request_id: "request://p04/1",
        idempotency_key: "p04-idempotency"
      })

    context
  end

  defp proposal_attrs do
    %{
      effect_ref: "effect://p04/1",
      run_ref: "run://p04/1",
      turn_ref: "turn://p04/1",
      command_ref: "command://p04/1",
      decision_ref: "decision://citadel/p04/1",
      grant_ref: "grant://citadel/p04/1",
      review_ref: "review://mezzanine/p04/1",
      subject_id: "00000000-0000-0000-0000-000000000001",
      run_id: "00000000-0000-0000-0000-000000000002",
      review_unit_id: "00000000-0000-0000-0000-000000000003",
      target_ref: "target://codex/local/1",
      attempt_ref: "attempt://p04/1",
      capability_id: "codex.session.turn",
      effect_mode: "managed_account_local_effect",
      pinned_tool_manifest: %{
        manifest_ref: "manifest://codex/p04/1",
        manifest_hash: "sha256:" <> String.duplicate("a", 64),
        action_ids: ["create_or_replace_one_named_text_file"]
      },
      reviewed_operation: %{
        operation: "create_or_replace",
        workspace_ref: "workspace://p04/1",
        file_ref: "file://p04/RESULT.txt",
        relative_path: "RESULT.txt",
        content_digest: "sha256:" <> String.duplicate("b", 64)
      }
    }
  end
end
