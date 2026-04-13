defmodule AppKit.ConversationBridgeTest do
  use ExUnit.Case, async: true

  alias AppKit.ConversationBridge
  alias AppKit.Core.RunRef
  alias AppKit.ScopeObjects
  alias Jido.Domain.Adapters.CitadelAdapter.Accepted

  defmodule FakeKernelRuntime do
    @moduledoc false

    def dispatch_command(command, _opts) do
      {:ok,
       Accepted.new!(%{
         request_id: command.idempotency_key,
         session_id: command.context[:session_id],
         trace_id: command.trace_id,
         ingress_path: :direct_intent_envelope,
         lifecycle_event: :live_owner,
         continuity_revision: 1
       })}
    end
  end

  test "composes a follow-up and a live update" do
    assert {:ok, scope} =
             ScopeObjects.host_scope(%{
               scope_id: "workspace/main",
               session_id: "sess-conversation",
               tenant_id: "tenant-conversation",
               actor_id: "user-1",
               environment: "dev",
               metadata: %{workspace_root: "/workspace/main"}
             })

    assert {:ok, result} =
             ConversationBridge.compose_follow_up(
               scope,
               "compile the workspace",
               idempotency_key: "conversation-turn-1",
               domain_module: Jido.Domain.Examples.ProvingGround,
               route_sources: [Jido.Domain.Examples.ProvingGround.Routes.CompileWorkspace],
               kernel_runtime: {FakeKernelRuntime, []}
             )

    assert {:ok, run_ref} = RunRef.new(%{run_id: "run-1", scope_id: "workspace/main"})

    assert {:ok, update} =
             ConversationBridge.live_update(run_ref, %{
               route_name: :compile_workspace,
               state: :scheduled
             })

    assert result.surface == :conversation
    assert result.payload.action_request.route == "compile_workspace"
    assert result.payload.accepted.request_id == "conversation-turn-1"
    assert update.run_id == "run-1"
  end
end
