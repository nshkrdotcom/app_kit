defmodule AppKit.Bridges.OuterBrainBridgeTest do
  use ExUnit.Case, async: true

  alias AppKit.Bridges.OuterBrainBridge
  alias AppKit.ScopeObjects
  alias Citadel.DomainSurface.Adapters.CitadelAdapter.Accepted

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

  test "submits a semantic turn through the outer_brain seam" do
    assert {:ok, scope} =
             ScopeObjects.host_scope(%{
               scope_id: "workspace/main",
               session_id: "sess-outer-brain-bridge",
               tenant_id: "tenant-1",
               actor_id: "user-1",
               environment: "dev",
               metadata: %{workspace_root: "/workspace/main"}
             })

    assert {:ok, turn} =
             OuterBrainBridge.submit_turn(
               scope,
               "compile the workspace",
               idempotency_key: "turn-outer-brain-1",
               domain_module: Citadel.DomainSurface.Examples.ProvingGround,
               route_sources: [
                 Citadel.DomainSurface.Examples.ProvingGround.Routes.CompileWorkspace
               ],
               kernel_runtime: {FakeKernelRuntime, []}
             )

    assert turn.action_request.route == "compile_workspace"
    assert turn.dispatch_result.request_id == "turn-outer-brain-1"
  end
end
