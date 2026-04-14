defmodule AppKit.OperatorSurfaceTest do
  use ExUnit.Case, async: true

  defmodule FakeOperatorBackend do
    @behaviour AppKit.Core.Backends.OperatorBackend

    alias AppKit.Core.RunRef

    @impl true
    def run_status(%RunRef{} = run_ref, attrs, _opts) do
      {:ok, %{run_id: run_ref.run_id, backend: :fake, attrs: attrs}}
    end

    @impl true
    def review_run(%RunRef{} = run_ref, evidence_attrs, opts) do
      {:ok,
       %{
         backend: :fake,
         run_id: run_ref.run_id,
         evidence_attrs: evidence_attrs,
         reason: Keyword.get(opts, :reason)
       }}
    end
  end

  alias AppKit.Core.RunRef
  alias AppKit.OperatorSurface

  test "projects run status and review output" do
    assert {:ok, run_ref} = RunRef.new(%{run_id: "run-1", scope_id: "workspace/main"})

    assert {:ok, projection} =
             OperatorSurface.run_status(run_ref, %{
               route_name: :compile_workspace,
               state: :waiting_review
             })

    assert {:ok, review} =
             OperatorSurface.review_run(run_ref, %{kind: :operator_note, summary: "looks good"})

    assert projection.run_id == "run-1"
    assert review.decision.state == :approved
  end

  test "delegates projection and review through a configured backend" do
    assert {:ok, run_ref} = RunRef.new(%{run_id: "run-2", scope_id: "workspace/main"})

    assert {:ok, projection} =
             OperatorSurface.run_status(
               run_ref,
               %{route_name: :compile_workspace},
               operator_backend: FakeOperatorBackend
             )

    assert {:ok, review} =
             OperatorSurface.review_run(
               run_ref,
               %{kind: :operator_note, summary: "needs context"},
               operator_backend: FakeOperatorBackend,
               reason: "operator requested detail"
             )

    assert projection.backend == :fake
    assert review.backend == :fake
    assert review.reason == "operator requested detail"
  end
end
