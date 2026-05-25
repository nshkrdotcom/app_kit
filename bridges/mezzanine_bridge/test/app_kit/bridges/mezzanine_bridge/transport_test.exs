defmodule AppKit.Bridges.MezzanineBridge.TransportTest do
  use ExUnit.Case, async: true

  alias AppKit.Bridges.MezzanineBridge.Transport

  defmodule DirectTarget do
    def submit_work(request, opts) do
      {:ok, %{"mode" => "direct", "request" => request, "timeout" => opts[:timeout]}}
    end

    def readback(ref), do: {:ok, %{"mode" => "direct", "ref" => ref}}
  end

  test "direct transport calls an explicitly supplied in-process target" do
    assert {:ok, result} =
             Transport.Direct.submit_work(%{"work" => "one"}, target: DirectTarget, timeout: 25)

    assert result["mode"] == "direct"
    assert result["timeout"] == 25

    assert {:ok, %{"ref" => "work://1"}} =
             Transport.Direct.readback("work://1", target: DirectTarget)
  end

  test "distributed transport calls an explicitly supplied owner facade" do
    assert {:ok, result} =
             Transport.Distributed.submit_work(%{"work" => "one"},
               node: Node.self(),
               facade_module: DirectTarget,
               timeout: 1_000
             )

    assert result["mode"] == "direct"
  end

  test "fixture transport is deterministic and overridable" do
    assert {:ok, %{"accepted_ref" => "idem-1"}} =
             Transport.Fixture.submit_work(%{"idempotency_key" => "idem-1"}, [])

    assert {:ok, %{"status" => "custom"}} =
             Transport.Fixture.readback("work://1",
               responses: %{readback: fn ref -> {:ok, %{"status" => "custom", "ref" => ref}} end}
             )
  end

  test "runtime deps select a transport explicitly" do
    assert {:ok, deps} =
             Transport.RuntimeDeps.new(
               transport: Transport.Fixture,
               transport_opts: [submit_work: {:ok, %{"accepted_ref" => "fixture://work"}}]
             )

    assert {:ok, %{"accepted_ref" => "fixture://work"}} =
             Transport.RuntimeDeps.submit_work(deps, %{})
  end
end
