defmodule AppKit.EffectSurfaceTest do
  use ExUnit.Case, async: true

  alias AppKit.BackendStack

  alias AppKit.Core.{
    EffectAcceptanceDTO,
    EffectDispatchCommandDTO,
    EffectReceiptCommandDTO,
    GovernedEffectDTO,
    GovernedEffectProposalDTO,
    RequestContext
  }

  defmodule Backend do
    @behaviour AppKit.EffectSurface

    @impl true
    def propose_effect(_context, %GovernedEffectProposalDTO{}, _opts), do: projection()

    @impl true
    def begin_dispatch(_context, "effect-execution://" <> _, %EffectDispatchCommandDTO{}, _opts),
      do: projection("dispatching", 2)

    @impl true
    def record_accepted(_context, "effect-execution://" <> _, %EffectAcceptanceDTO{}, _opts),
      do: projection("running", 3)

    @impl true
    def record_receipt(_context, "effect-execution://" <> _, %EffectReceiptCommandDTO{}, _opts),
      do: projection("completed", 4)

    @impl true
    def get_effect(_context, "effect-execution://" <> _, _opts), do: projection()

    @impl true
    def get_effect_by_idempotency(_context, "p04-idempotency", _opts), do: projection()

    defp projection(status \\ "authorized", row_version \\ 1) do
      GovernedEffectDTO.new(%{
        contract_version: 1,
        effect_ref: "effect://p04/1",
        run_ref: "run://p04/1",
        turn_ref: "turn://p04/1",
        command_ref: "command://p04/1",
        decision_ref: "decision://citadel/p04/1",
        grant_ref: "grant://citadel/p04/1",
        target_ref: "target://codex/local/1",
        owner_execution_ref: "effect-execution://00000000-0000-0000-0000-000000000004",
        status: status,
        row_version: row_version,
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
        },
        review: %{
          review_ref: "review://mezzanine/p04/1",
          review_unit_id: "00000000-0000-0000-0000-000000000003",
          status: "accepted",
          row_version: 2
        }
      })
    end
  end

  test "surface constructs canonical command DTOs and delegates every durable lifecycle step" do
    opts = [effect_surface_adapter: Backend]
    context = context!()

    assert {:ok, %GovernedEffectDTO{status: "authorized"} = opened} =
             AppKit.EffectSurface.propose_effect(context, proposal_attrs(), opts)

    assert {:ok, %GovernedEffectDTO{status: "dispatching", row_version: 2}} =
             AppKit.EffectSurface.begin_dispatch(
               context,
               opened.owner_execution_ref,
               %{expected_row_version: 1},
               opts
             )

    assert {:ok, %GovernedEffectDTO{status: "running", row_version: 3}} =
             AppKit.EffectSurface.record_accepted(
               context,
               opened.owner_execution_ref,
               %{expected_row_version: 2, attempt_ref: "attempt://p04/1"},
               opts
             )

    assert {:ok, %GovernedEffectDTO{status: "completed", row_version: 4}} =
             AppKit.EffectSurface.record_receipt(
               context,
               opened.owner_execution_ref,
               receipt_attrs(),
               opts
             )

    assert {:ok, %GovernedEffectDTO{}} =
             AppKit.EffectSurface.get_effect(context, opened.owner_execution_ref, opts)

    assert {:ok, %GovernedEffectDTO{}} =
             AppKit.EffectSurface.get_effect_by_idempotency(context, "p04-idempotency", opts)
  end

  test "surface delegates through the frozen backend stack role" do
    stack = BackendStack.new!(effect_surface_backend: Backend)

    assert {:ok, %GovernedEffectDTO{}} =
             AppKit.EffectSurface.propose_effect(context!(), proposal_attrs(),
               backend_stack: stack
             )
  end

  test "surface rejects an untyped execution ref before backend dispatch" do
    assert {:error, :invalid_effect_execution_ref} =
             AppKit.EffectSurface.get_effect(context!(), "effect://p04/1",
               effect_surface_adapter: Backend
             )
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

  defp receipt_attrs do
    %{
      expected_row_version: 3,
      receipt_ref: "receipt://p04/1",
      receipt_state: "completed",
      result_artifact_ref: "artifact://p04/1",
      continuation_target: %{
        kind: "owner_command",
        owner: "outer_brain",
        command: "publish_tool_result",
        idempotency_key: "p04-publish-1"
      }
    }
  end
end
