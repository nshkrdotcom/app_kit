defmodule AppKit.ModelSurfaceTest do
  use ExUnit.Case, async: true

  alias AppKit.ModelSurface
  alias AppKit.ModelSurface.CatalogProjection

  test "projects model and endpoint inventory with governed refs" do
    assert {:ok, %CatalogProjection{} = catalog} =
             ModelSurface.catalog_projection(%{
               tenant_ref: "tenant://phase-8",
               authority_ref: "authority://model/catalog",
               trace_refs: ["trace://model/catalog"],
               model_profiles: [
                 %{
                   model_profile_ref: "model-profile://mock/proposer",
                   provider_ref: "provider://mock",
                   capability_refs: ["capability://chat", "capability://json"],
                   readiness_ref: "readiness://mock/ready",
                   operation_classes: [:propose, :evaluate],
                   cost_posture_ref: "cost://mock/free",
                   source_status: :mock,
                   operation_policy_ref: "policy://operation/propose"
                 }
               ],
               endpoint_profiles: [
                 %{
                   endpoint_profile_ref: "endpoint-profile://local/proposer",
                   endpoint_ref: "endpoint://local/mock-proposer",
                   endpoint_identity_ref: "endpoint-identity://local/mock-proposer",
                   provider_credential_ref: "provider-credential://mock/profile",
                   readiness_ref: "readiness://endpoint/ready",
                   source_status: :self_hosted,
                   model_profile_refs: ["model-profile://mock/proposer"]
                 }
               ]
             })

    assert catalog.model_profiles |> hd() |> Map.fetch!(:operation_classes) == [
             :propose,
             :evaluate
           ]

    assert catalog.endpoint_profiles |> hd() |> Map.fetch!(:source_status) == :self_hosted
    refute catalog |> Map.from_struct() |> Map.has_key?(:provider_payload)
  end

  test "rejects raw model payload and merged endpoint/provider identity" do
    assert {:error, {:raw_model_surface_payload_forbidden, :provider_payload}} =
             ModelSurface.model_profile(%{
               model_profile_ref: "model-profile://bad",
               provider_ref: "provider://bad",
               capability_refs: ["capability://chat"],
               readiness_ref: "readiness://bad",
               operation_classes: [:propose],
               cost_posture_ref: "cost://bad",
               source_status: :live,
               operation_policy_ref: "policy://operation/propose",
               provider_payload: %{body: "hidden"}
             })

    assert {:error, :endpoint_identity_must_not_equal_provider_credential} =
             ModelSurface.endpoint_profile(%{
               endpoint_profile_ref: "endpoint-profile://bad",
               endpoint_ref: "endpoint://bad",
               endpoint_identity_ref: "identity://merged",
               provider_credential_ref: "identity://merged",
               readiness_ref: "readiness://bad",
               source_status: :live,
               model_profile_refs: ["model-profile://bad"]
             })
  end
end
