defmodule AppKit.ChatSurfaceTest do
  use ExUnit.Case, async: true

  alias AppKit.ChatSurface
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

  test "submits a chat turn through the northbound surface" do
    assert {:ok, scope} =
             ScopeObjects.host_scope(%{
               scope_id: "workspace/main",
               session_id: "sess-chat-surface",
               tenant_id: "tenant-chat",
               actor_id: "user-1",
               environment: "dev",
               metadata: %{workspace_root: "/workspace/main"}
             })

    assert {:ok, result} =
             ChatSurface.submit_turn(
               scope,
               "compile the workspace",
               idempotency_key: "chat-turn-1",
               domain_module: Jido.Domain.Examples.ProvingGround,
               route_sources: [Jido.Domain.Examples.ProvingGround.Routes.CompileWorkspace],
               kernel_runtime: {FakeKernelRuntime, []}
             )

    assert result.surface == :conversation
    assert result.payload.accepted.request_id == "chat-turn-1"
  end
end
