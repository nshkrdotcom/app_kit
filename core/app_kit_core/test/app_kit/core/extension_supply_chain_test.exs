defmodule AppKit.Core.ExtensionSupplyChainTest do
  use ExUnit.Case, async: true

  alias AppKit.Core.{
    ConnectorAdmissionProjection,
    ExtensionPackBundleProjection,
    ExtensionPackSignatureProjection
  }

  @hash "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"

  test "projects extension pack signature evidence" do
    assert {:ok, projection} =
             base_attrs()
             |> Map.merge(%{
               pack_ref: "pack:expense-approval@1.0.0",
               signature_ref: "sig:phase4-expense-approval",
               signing_key_ref: "signing-key:tenant-a:2026-04",
               signature_algorithm: "hmac-sha256",
               verification_hash: @hash,
               rejection_ref: "rejection:none",
               source_contract_name: "Platform.ExtensionPackSignature.v1"
             })
             |> ExtensionPackSignatureProjection.new()

    assert projection.contract_name == "AppKit.ExtensionPackSignatureProjection.v1"
  end

  test "rejects extension pack signature projection with wrong source contract" do
    assert {:error, :invalid_extension_pack_signature_projection} =
             base_attrs()
             |> Map.merge(%{
               pack_ref: "pack:expense-approval@1.0.0",
               signature_ref: "sig:phase4-expense-approval",
               signing_key_ref: "signing-key:tenant-a:2026-04",
               signature_algorithm: "hmac-sha256",
               verification_hash: @hash,
               rejection_ref: "rejection:none",
               source_contract_name: "Legacy.ExtensionPackSignature.v0"
             })
             |> ExtensionPackSignatureProjection.new()
  end

  test "projects extension pack bundle evidence" do
    assert {:ok, projection} =
             base_attrs()
             |> Map.merge(%{
               pack_ref: "pack:expense-approval@1.0.0",
               bundle_schema_version: "phase4.extension_bundle.v1",
               declared_resources: ["connector:github.issue", "schema:expense_request"],
               schema_hash: @hash,
               validation_error_ref: "validation:none",
               source_contract_name: "Platform.ExtensionPackBundle.v1"
             })
             |> ExtensionPackBundleProjection.new()

    assert projection.contract_name == "AppKit.ExtensionPackBundleProjection.v1"
  end

  test "rejects extension pack bundle projection without declared resources" do
    assert {:error, {:missing_required_fields, fields}} =
             base_attrs()
             |> Map.merge(%{
               pack_ref: "pack:expense-approval@1.0.0",
               bundle_schema_version: "phase4.extension_bundle.v1",
               declared_resources: [],
               schema_hash: @hash,
               validation_error_ref: "validation:none",
               source_contract_name: "Platform.ExtensionPackBundle.v1"
             })
             |> ExtensionPackBundleProjection.new()

    assert :declared_resources in fields
  end

  test "projects connector admission evidence" do
    assert {:ok, projection} =
             connector_admission_attrs("admitted")
             |> ConnectorAdmissionProjection.new()

    assert projection.contract_name == "AppKit.ConnectorAdmissionProjection.v1"
    assert projection.status == "admitted"
  end

  test "rejects duplicate connector admission evidence without duplicate ref" do
    assert {:error, :invalid_connector_admission_projection} =
             connector_admission_attrs("rejected_duplicate")
             |> ConnectorAdmissionProjection.new()
  end

  defp connector_admission_attrs(status) do
    base_attrs()
    |> Map.merge(%{
      connector_ref: "connector:github:v2",
      pack_ref: "pack:expense-approval@1.0.0",
      signature_ref: "sig:phase4-expense-approval",
      schema_ref: "schema:extension-pack:v1",
      admission_idempotency_key: "admission:tenant-alpha:github",
      status: status,
      source_contract_name: "Platform.ConnectorAdmission.v1"
    })
  end

  defp base_attrs do
    %{
      tenant_ref: "tenant:alpha",
      installation_ref: "installation:alpha-prod",
      workspace_ref: "workspace:alpha",
      project_ref: "project:phase4",
      environment_ref: "env:prod",
      system_actor_ref: "system:app-kit-projection",
      resource_ref: "pack:expense-approval",
      authority_packet_ref: "authority:pack-import",
      permission_decision_ref: "decision:allow-import",
      idempotency_key: "idem:pack-import:1",
      trace_id: "trace:pack-import:1",
      correlation_id: "corr:pack-import:1",
      release_manifest_ref: "phase4-v6-milestone14-extension-authoring-supply-chain"
    }
  end
end
