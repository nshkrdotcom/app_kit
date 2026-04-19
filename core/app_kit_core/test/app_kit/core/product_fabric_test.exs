defmodule AppKit.Core.ProductFabricTest do
  use ExUnit.Case, async: true

  alias AppKit.Core.{
    FullProductFabricSmoke,
    ProductBoundaryNoBypassScan,
    ProductCertification,
    ProductTenantContext
  }

  test "builds tenant context for atomic product tenant switches" do
    assert {:ok, context} =
             ProductTenantContext.new(%{
               tenant_ref: "tenant-a",
               installation_ref: "inst-a",
               workspace_ref: "workspace-main",
               project_ref: "project-core",
               environment_ref: "prod",
               principal_ref: "operator:ops-lead",
               resource_ref: "product/extravaganza",
               authority_packet_ref: "authz-packet-1",
               permission_decision_ref: "decision-1",
               idempotency_key: "tenant-switch:1",
               trace_id: "0123456789abcdef0123456789abcdef",
               correlation_id: "corr-tenant-switch",
               release_manifest_ref: "phase4-v6-milestone9",
               from_tenant_ref: "tenant-a",
               to_tenant_ref: "tenant-b",
               product_ref: "product:extravaganza",
               session_ref: "session-1",
               context_revision: 7,
               allowed_product_capabilities: ["work.submit", "operator.read"]
             })

    assert context.contract_name == "AppKit.ProductTenantContext.v1"
    assert context.to_tenant_ref == "tenant-b"
    assert context.context_revision == 7
  end

  test "rejects tenant switches with missing authority, trace, or capabilities" do
    assert {:error, {:missing_required_fields, fields}} =
             ProductTenantContext.new(%{
               tenant_ref: "tenant-a",
               installation_ref: "inst-a",
               resource_ref: "product/extravaganza",
               authority_packet_ref: "authz-packet-1",
               permission_decision_ref: "decision-1",
               idempotency_key: "tenant-switch:1",
               correlation_id: "corr-tenant-switch",
               release_manifest_ref: "phase4-v6-milestone9",
               from_tenant_ref: "tenant-a",
               to_tenant_ref: "tenant-b",
               product_ref: "product:extravaganza",
               session_ref: "session-1",
               context_revision: 7,
               allowed_product_capabilities: []
             })

    assert :trace_id in fields
    assert :allowed_product_capabilities in fields
    assert :principal_ref_or_system_actor_ref in fields
  end

  test "builds product certification reports from AppKit-only evidence" do
    assert {:ok, certification} =
             ProductCertification.new(%{
               tenant_ref: "tenant-a",
               installation_ref: "inst-a",
               workspace_ref: "workspace-main",
               project_ref: "project-core",
               environment_ref: "prod",
               system_actor_ref: "system:product-certifier",
               resource_ref: "product:third-product",
               authority_packet_ref: "authz-packet-2",
               permission_decision_ref: "decision-2",
               idempotency_key: "product-cert:third-product",
               trace_id: "1123456789abcdef0123456789abcdef",
               correlation_id: "corr-product-cert",
               release_manifest_ref: "phase4-v6-milestone9",
               product_ref: "product:third-product",
               certification_profile: "third-product-v1",
               sdk_version: "app-kit-sdk-1",
               schema_versions: ["AppKit.ProductTenantContext.v1"],
               scenario_set: ["056", "057", "073", "089"],
               no_bypass_scan_ref: "scan:third-product:1",
               proof_bundle_ref: "proof:third-product:1",
               appkit_surface_refs: ["AppKit.ProductTenantContext.v1"]
             })

    assert certification.contract_name == "AppKit.ProductCertification.v1"
    assert certification.no_bypass_scan_ref == "scan:third-product:1"
  end

  test "rejects certification reports with lower bypass evidence" do
    assert {:error, {:forbidden_bypass_refs, ["Mezzanine.Execution.RuntimeStack"]}} =
             ProductCertification.new(
               valid_certification(%{
                 bypass_import_refs: ["Mezzanine.Execution.RuntimeStack"]
               })
             )
  end

  test "builds no-bypass scan reports and rejects violations" do
    assert {:ok, scan} =
             ProductBoundaryNoBypassScan.new(%{
               tenant_ref: "tenant-a",
               installation_ref: "inst-a",
               workspace_ref: "workspace-main",
               project_ref: "project-core",
               environment_ref: "prod",
               system_actor_ref: "system:no-bypass-scan",
               resource_ref: "product:extravaganza",
               authority_packet_ref: "authz-packet-3",
               permission_decision_ref: "decision-3",
               idempotency_key: "no-bypass:extravaganza",
               trace_id: "2123456789abcdef0123456789abcdef",
               correlation_id: "corr-no-bypass",
               release_manifest_ref: "phase4-v6-milestone9",
               product_ref: "product:extravaganza",
               scan_ref: "scan:extravaganza:1",
               forbidden_imports: [],
               allowed_appkit_facades: ["AppKit.WorkSurface", "AppKit.OperatorSurface"],
               source_paths: ["apps/extravaganza_core/lib/**/*.ex"],
               violation_refs: []
             })

    assert scan.contract_name == "AppKit.ProductBoundaryNoBypassScan.v1"

    assert {:error, {:forbidden_imports_present, ["ExecutionPlane"]}} =
             ProductBoundaryNoBypassScan.new(%{
               scan
               | forbidden_imports: ["ExecutionPlane"],
                 violation_refs: ["apps/product/lib/runtime.ex:3"]
             })
  end

  test "builds full product fabric smoke reports" do
    assert {:ok, smoke} =
             FullProductFabricSmoke.new(%{
               tenant_ref: "tenant-a",
               installation_ref: "inst-a",
               workspace_ref: "workspace-main",
               project_ref: "project-core",
               environment_ref: "prod",
               system_actor_ref: "system:fabric-smoke",
               resource_ref: "fabric:phase4",
               authority_packet_ref: "authz-packet-4",
               permission_decision_ref: "decision-4",
               idempotency_key: "fabric-smoke:phase4",
               trace_id: "3123456789abcdef0123456789abcdef",
               correlation_id: "corr-fabric-smoke",
               release_manifest_ref: "phase4-v6-milestone9",
               product_refs: ["product:extravaganza", "product:third-product"],
               tenant_refs: ["tenant-a", "tenant-b"],
               scenario_set: ["056", "057", "073", "089"],
               sdk_versions: ["app-kit-sdk-1"],
               schema_versions: ["AppKit.ProductTenantContext.v1"],
               authority_refs: ["authz-packet-1", "authz-packet-2"],
               workflow_refs: ["workflow:product-smoke-1"],
               proof_bundle_ref: "proof:fabric-smoke:1",
               no_bypass_scan_ref: "scan:extravaganza:1"
             })

    assert smoke.contract_name == "AppKit.FullProductFabricSmoke.v1"
    assert "product:third-product" in smoke.product_refs
  end

  defp valid_certification(overrides) do
    Map.merge(
      %{
        tenant_ref: "tenant-a",
        installation_ref: "inst-a",
        workspace_ref: "workspace-main",
        project_ref: "project-core",
        environment_ref: "prod",
        system_actor_ref: "system:product-certifier",
        resource_ref: "product:third-product",
        authority_packet_ref: "authz-packet-2",
        permission_decision_ref: "decision-2",
        idempotency_key: "product-cert:third-product",
        trace_id: "1123456789abcdef0123456789abcdef",
        correlation_id: "corr-product-cert",
        release_manifest_ref: "phase4-v6-milestone9",
        product_ref: "product:third-product",
        certification_profile: "third-product-v1",
        sdk_version: "app-kit-sdk-1",
        schema_versions: ["AppKit.ProductTenantContext.v1"],
        scenario_set: ["056", "057", "073", "089"],
        no_bypass_scan_ref: "scan:third-product:1",
        proof_bundle_ref: "proof:third-product:1",
        appkit_surface_refs: ["AppKit.ProductTenantContext.v1"]
      },
      overrides
    )
  end
end
