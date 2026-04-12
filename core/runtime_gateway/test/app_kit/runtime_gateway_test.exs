defmodule AppKit.RuntimeGatewayTest do
  use ExUnit.Case, async: true

  alias AppKit.RuntimeGateway
  alias AppKit.ScopeObjects

  test "opens an app-facing runtime gateway" do
    assert {:ok, target} =
             ScopeObjects.managed_target(%{
               target_id: "runtime/compiler",
               target_kind: :workspace_runtime
             })

    assert {:ok, gateway} = RuntimeGateway.open(target, mode: :attached, transport: :session)
    assert gateway.mode == :attached
  end
end
