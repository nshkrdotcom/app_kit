defmodule AppKit.RuntimeGatewayTest do
  use ExUnit.Case, async: true

  alias AppKit.Core.{Context, RequestContext}
  alias AppKit.Core.Backends.GenericBackend
  alias AppKit.RuntimeGateway
  alias AppKit.ScopeObjects

  defmodule FakeGenericBackend do
    @behaviour GenericBackend

    def invoke_runtime_operation(context, runtime_role_ref, operation_role_ref, request, _opts) do
      {:ok,
       {:runtime_operation, trace_ref(context), runtime_role_ref, operation_role_ref, request}}
    end

    def invoke_runtime_tool(context, tool_role_ref, operation_role_ref, request, _opts) do
      {:ok, {:runtime_tool, trace_ref(context), tool_role_ref, operation_role_ref, request}}
    end

    def collect_evidence(context, evidence_role_ref, request, _opts) do
      {:ok, {:evidence, trace_ref(context), evidence_role_ref, request}}
    end

    def invoke_resource_effect(context, role_ref, request, _opts) do
      {:ok, {:resource_effect, trace_ref(context), role_ref, request}}
    end

    defp trace_ref(context), do: Map.get(context, :trace_ref) || Map.fetch!(context, :trace_id)
  end

  test "opens an app-facing runtime gateway" do
    assert {:ok, target} =
             ScopeObjects.managed_target(%{
               target_id: "runtime/compiler",
               target_kind: :workspace_runtime
             })

    assert {:ok, gateway} = RuntimeGateway.open(target, mode: :attached, transport: :session)
    assert gateway.mode == :attached
  end

  test "invokes generic runtime, tool, evidence, and resource-effect operations by role" do
    context = context!()
    opts = [generic_backend: FakeGenericBackend]

    assert {:ok, {:runtime_operation, _, :agent_runtime, :continue, %{input_ref: "payload://a"}}} =
             RuntimeGateway.invoke_runtime_operation(
               context,
               :agent_runtime,
               :continue,
               %{input_ref: "payload://a"},
               opts
             )

    assert {:ok, {:runtime_tool, _, :issue_query_tool, :execute, %{input_ref: "payload://b"}}} =
             RuntimeGateway.invoke_runtime_tool(
               context,
               :issue_query_tool,
               :execute,
               %{input_ref: "payload://b"},
               opts
             )

    assert {:ok, {:evidence, _, :change_evidence, %{subject_ref: "subject://a"}}} =
             RuntimeGateway.collect_evidence(
               context,
               :change_evidence,
               %{subject_ref: "subject://a"},
               opts
             )

    assert {:ok, {:resource_effect, _, :cleanup, %{subject_ref: "subject://a"}}} =
             RuntimeGateway.invoke_resource_effect(
               context,
               :cleanup,
               %{subject_ref: "subject://a"},
               opts
             )
  end

  test "generic runtime gateway fails closed without a backend" do
    assert {:error, error} =
             RuntimeGateway.invoke_runtime_operation(context!(), :agent_runtime, :continue, %{})

    assert error.code == "generic_app_kit_surface_not_ready"
  end

  test "invokes runtime tools from the existing request context envelope" do
    assert {:ok,
            {:runtime_tool, "cccccccccccccccccccccccccccccccc", :issue_query_tool, :execute, %{}}} =
             RuntimeGateway.invoke_runtime_tool(
               request_context!(),
               :issue_query_tool,
               :execute,
               %{},
               generic_backend: FakeGenericBackend
             )
  end

  defp context! do
    {:ok, context} =
      Context.new(%{
        actor_ref: %{id: "actor-a", kind: :user},
        tenant_ref: %{id: "tenant-a"},
        installation_ref: %{id: "install-a", pack_slug: "product-a"},
        trace_ref: "trace://tenant-a/request-a",
        request_ref: "request://tenant-a/request-a",
        idempotency_key: "idempotency://tenant-a/request-a"
      })

    context
  end

  defp request_context! do
    {:ok, context} =
      RequestContext.new(%{
        trace_id: "cccccccccccccccccccccccccccccccc",
        actor_ref: %{id: "actor-a", kind: :user},
        tenant_ref: %{id: "tenant-a"},
        installation_ref: %{id: "install-a", pack_slug: "product-a"},
        request_id: "request://tenant-a/request-a",
        idempotency_key: "idempotency://tenant-a/request-a"
      })

    context
  end
end
