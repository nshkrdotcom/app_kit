defmodule AppKit.Examples.ReferenceHost do
  @moduledoc """
  Reference host proving the AppKit northbound composition path.
  """

  alias AppKit.{ChatSurface, DomainSurface, OperatorSurface, RuntimeGateway, ScopeObjects}
  alias AppKit.Core.RunRef

  defmodule DemoKernelRuntime do
    @moduledoc false

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

  @spec run_demo(keyword()) :: map()
  def run_demo(opts \\ []) do
    {:ok, scope} =
      ScopeObjects.host_scope(%{
        scope_id: "workspace/main",
        session_id: "sess-reference-host",
        tenant_id: "tenant-reference",
        actor_id: "user-1",
        environment: "dev"
      })

    {:ok, target} =
      ScopeObjects.managed_target(%{
        target_id: "runtime/compiler",
        target_kind: :workspace_runtime
      })

    domain_module = Keyword.get(opts, :domain_module, Jido.Domain.Examples.ProvingGround)
    kernel_runtime = Keyword.get(opts, :kernel_runtime, {DemoKernelRuntime, []})

    {:ok, gateway} = RuntimeGateway.open(target, mode: :attached, transport: :session)

    {:ok, chat} =
      ChatSurface.submit_turn(
        scope,
        "compile the workspace",
        idempotency_key: "chat-reference-host",
        domain_module: domain_module,
        route_sources: [Jido.Domain.Examples.ProvingGround.Routes.CompileWorkspace],
        kernel_runtime: kernel_runtime,
        workspace_root: "/workspace/main"
      )

    {:ok, command} =
      DomainSurface.submit_command(
        scope,
        :compile_workspace,
        %{workspace_id: "workspace/main"},
        domain_module: domain_module,
        kernel_runtime: kernel_runtime,
        idempotency_key: "cmd-reference-host",
        context: %{trace_id: "trace/reference-host"}
      )

    {:ok, run_ref} = RunRef.new(%{run_id: "run-1", scope_id: scope.scope_id})

    {:ok, status} =
      OperatorSurface.run_status(run_ref, %{
        route_name: :compile_workspace,
        state: command.state,
        details: %{request_id: command.payload.accepted.request_id}
      })

    %{
      gateway: gateway,
      chat: chat,
      command: command,
      status: status
    }
  end
end
