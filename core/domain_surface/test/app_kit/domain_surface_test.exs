defmodule AppKit.DomainSurfaceTest do
  use ExUnit.Case, async: true

  alias AppKit.DomainSurface
  alias AppKit.ScopeObjects

  defmodule FakeKernelRuntime do
    def dispatch_command(command, _opts) do
      {:ok,
       %{
         request_id: command.idempotency_key,
         session_id: command.context[:session_id],
         trace_id: command.trace_id,
         ingress_path: :direct_intent_envelope,
         lifecycle_event: :live_owner,
         continuity_revision: 1
       }}
    end

    def run_query(query, _opts) do
      {:ok, %{query_name: query.name, target_id: query.params[:workspace_id], status: "ready"}}
    end
  end

  test "submits real typed domain commands and queries through the app surface" do
    trace_id = "0123456789abcdef0123456789abcdef"

    assert {:ok, scope} =
             ScopeObjects.host_scope(%{
               scope_id: "workspace/main",
               session_id: "sess-1",
               tenant_id: "tenant-1",
               actor_id: "user-1",
               environment: "dev"
             })

    opts = [
      domain_module: Citadel.DomainSurface.Examples.ProvingGround,
      kernel_runtime: {FakeKernelRuntime, []},
      idempotency_key: "cmd-1",
      trace_trust: :trusted,
      context: %{trace_id: trace_id}
    ]

    assert {:ok, command_result} =
             DomainSurface.submit_command(
               scope,
               :compile_workspace,
               %{workspace_id: "workspace/main"},
               opts
             )

    assert {:ok, query_result} =
             DomainSurface.ask_query(
               scope,
               :workspace_status,
               %{workspace_id: "workspace/main"},
               Keyword.drop(opts, [:idempotency_key])
             )

    assert command_result.surface == :domain
    assert command_result.state == :accepted
    assert command_result.payload.accepted.request_id == "cmd-1"

    assert query_result.surface == :domain
    assert query_result.state == :accepted
    assert query_result.payload.response.target_id == "workspace/main"
  end
end
