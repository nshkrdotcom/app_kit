defmodule AppKit.Bridges.MezzanineBridge.RuntimeProjectionStoreTest do
  use ExUnit.Case, async: false

  alias AppKit.Bridges.MezzanineBridge.RuntimeProjectionStore
  alias AppKit.Core.RequestContext

  setup do
    {:ok, _apps} = Application.ensure_all_started(:app_kit_mezzanine_bridge)
    :ok = RuntimeProjectionStore.reset()
    :ok
  end

  test "stores projections by tenant and run ref" do
    tenant_a = request_context("tenant-a")
    tenant_b = request_context("tenant-b")

    assert :ok = RuntimeProjectionStore.put(tenant_a, "run://shared", projection("tenant-a"))
    assert :ok = RuntimeProjectionStore.put(tenant_b, "run://shared", projection("tenant-b"))

    assert %{tenant_ref: "tenant-a"} = RuntimeProjectionStore.get(tenant_a, "run://shared")
    assert %{tenant_ref: "tenant-b"} = RuntimeProjectionStore.get(tenant_b, "run://shared")
  end

  test "reset can clear one tenant without affecting another tenant" do
    tenant_a = request_context("tenant-a")
    tenant_b = request_context("tenant-b")

    assert :ok = RuntimeProjectionStore.put(tenant_a, "run://one", projection("tenant-a"))
    assert :ok = RuntimeProjectionStore.put(tenant_b, "run://one", projection("tenant-b"))

    assert :ok = RuntimeProjectionStore.reset(tenant_ref: "tenant-a")

    assert RuntimeProjectionStore.get(tenant_a, "run://one") == nil
    assert %{tenant_ref: "tenant-b"} = RuntimeProjectionStore.get(tenant_b, "run://one")
  end

  test "expired projections are not returned" do
    context = request_context("tenant-a")

    assert :ok =
             RuntimeProjectionStore.put(context, "run://expired", projection("tenant-a"),
               ttl_ms: 0
             )

    assert RuntimeProjectionStore.get(context, "run://expired") == nil
  end

  test "accepts concurrent writes through the supervised owner" do
    context = request_context("tenant-a")
    supervisor = start_supervised!({Task.Supervisor, name: __MODULE__.TaskSupervisor})

    Task.Supervisor.async_stream_nolink(
      supervisor,
      1..20,
      fn index ->
        run_ref = "run://#{index}"
        RuntimeProjectionStore.put(context, run_ref, projection("tenant-a", run_ref))
      end,
      ordered: false
    )
    |> Enum.each(fn result -> assert result == {:ok, :ok} end)

    for index <- 1..20 do
      run_ref = "run://#{index}"
      assert %{run_ref: ^run_ref} = RuntimeProjectionStore.get(context, run_ref)
    end
  end

  test "can clear all projections" do
    context = request_context("tenant-a")

    assert :ok = RuntimeProjectionStore.put(context, "run://one", projection("tenant-a"))
    assert :ok = RuntimeProjectionStore.reset()

    assert RuntimeProjectionStore.get(context, "run://one") == nil
  end

  defp request_context(tenant_id) do
    {:ok, context} =
      RequestContext.new(%{
        trace_id: "11111111111111111111111111111111",
        actor_ref: %{id: "operator", kind: :human},
        tenant_ref: %{id: tenant_id},
        installation_ref: %{id: "installation-1", pack_slug: "sample-host"}
      })

    context
  end

  defp projection(tenant_ref, run_ref \\ "run://shared") do
    %{
      tenant_ref: tenant_ref,
      subject_ref: "subject://one",
      run_ref: run_ref,
      workflow_ref: "workflow://one",
      status: "running",
      updated_at: DateTime.utc_now()
    }
  end
end
