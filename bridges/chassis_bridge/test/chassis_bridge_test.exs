ExUnit.start()

defmodule AppKit.ChassisBridgeTest do
  use ExUnit.Case, async: true

  test "spatial gateway standalone backend resolves" do
    assert {:ok, %{profile_ref: "profile:monolith"}} = AppKit.SpatialGateway.get_active_profile()
  end

  test "evolution surface blocks raw diffs without a lease" do
    assert {:error, :raw_diff_lease_required} =
             AppKit.EvolutionSurface.get_candidate_diff(%{tenant_ref: "tenant:dev"}, %{
               candidate_ref: "cand:dev:smoke"
             })
  end
end
