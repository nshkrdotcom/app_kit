defmodule AppKit.CostSurfaceTest do
  use ExUnit.Case, async: true

  alias AppKit.CostSurface

  test "builds DTO-only cost breakdown requests and projections" do
    assert {:ok, request} =
             CostSurface.breakdown_request(%{
               request_ref: "request://cost",
               tenant_ref: "tenant://a",
               authority_ref: "authority://a",
               installation_ref: "installation://a",
               group_by: :cost_class
             })

    assert request.group_by == :cost_class

    assert {:ok, projection} =
             CostSurface.breakdown_projection(%{
               projection_ref: "projection://cost",
               tenant_ref: "tenant://a",
               group_by: :cost_class,
               facts: [fact_attrs()]
             })

    assert projection.redaction_posture == "bounded_amount_classes_only"
    assert [%CostSurface.CostFactProjection{}] = projection.facts
  end

  test "rejects raw provider amounts and unknown cost classes" do
    assert {:error, {:raw_cost_surface_payload_forbidden, :cost_amount}} =
             CostSurface.fact_projection(Map.put(fact_attrs(), :cost_amount, 10))

    assert {:error, {:unknown_cost_surface_enum, :cost_class}} =
             CostSurface.fact_projection(Map.put(fact_attrs(), :cost_class, :unknown))
  end

  defp fact_attrs do
    %{
      fact_ref: "cost-fact://one",
      run_ref: "run://a",
      capability_id: "codex.session.turn",
      cost_class: :production,
      amount_class: :redacted_below_floor,
      token_meter_ref: "meter://phase-d",
      trace_id: "trace://phase-d"
    }
  end
end
