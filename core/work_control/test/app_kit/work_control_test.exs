defmodule AppKit.WorkControlTest do
  use ExUnit.Case, async: true

  defmodule FakeWorkBackend do
    @behaviour AppKit.Core.Backends.WorkBackend

    alias AppKit.Core.Result

    @impl true
    def start_run(domain_call, opts) do
      Result.new(%{
        surface: :work_control,
        state: :scheduled,
        payload: %{backend: :fake, domain_call: domain_call, opts: Enum.into(opts, %{})}
      })
    end
  end

  alias AppKit.WorkControl

  test "starts a governed run from a domain call" do
    assert {:ok, result} =
             WorkControl.start_run(
               %{route_name: :compile_workspace, scope_id: "workspace/main"},
               review_required: true
             )

    assert result.state == :waiting_review
  end

  test "delegates to a configured backend" do
    assert {:ok, result} =
             WorkControl.start_run(
               %{route_name: :compile_workspace, scope_id: "workspace/main"},
               work_backend: FakeWorkBackend,
               target: :custom
             )

    assert result.payload.backend == :fake
    assert result.payload.domain_call.route_name == :compile_workspace
    assert result.payload.opts.target == :custom
  end
end
