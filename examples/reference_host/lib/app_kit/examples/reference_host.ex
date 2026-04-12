defmodule AppKit.Examples.ReferenceHost do
  @moduledoc """
  Reference host proving the AppKit northbound composition path.
  """

  alias AppKit.{ChatSurface, DomainSurface, OperatorSurface, RuntimeGateway, ScopeObjects}
  alias AppKit.Core.RunRef

  @spec run_demo() :: map()
  def run_demo do
    {:ok, scope} = ScopeObjects.host_scope(%{scope_id: "workspace/main", actor_id: "user-1"})

    {:ok, target} =
      ScopeObjects.managed_target(%{
        target_id: "runtime/compiler",
        target_kind: :workspace_runtime
      })

    {:ok, gateway} = RuntimeGateway.open(target, mode: :attached, transport: :session)
    {:ok, chat} = ChatSurface.submit_turn(scope, "compile the workspace")

    {:ok, command} =
      DomainSurface.submit_command(scope, :compile_workspace, %{workspace_id: "workspace/main"},
        review_required: true
      )

    {:ok, run_ref} = RunRef.new(%{run_id: "run-1", scope_id: scope.scope_id})

    {:ok, status} =
      OperatorSurface.run_status(run_ref, %{
        route_name: :compile_workspace,
        state: :waiting_review
      })

    %{
      gateway: gateway,
      chat: chat,
      command: command,
      status: status
    }
  end
end
