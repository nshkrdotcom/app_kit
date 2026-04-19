defmodule AppKit.Core.ErrorTaxonomyProjectionTest do
  use ExUnit.Case, async: true

  alias AppKit.Core.ErrorTaxonomyProjection

  test "builds platform error taxonomy projections for operator surfaces" do
    assert {:ok, projection} =
             ErrorTaxonomyProjection.new(%{
               tenant_ref: "tenant-1",
               installation_ref: "inst-1",
               workspace_ref: "workspace-main",
               project_ref: "project-core",
               environment_ref: "prod",
               system_actor_ref: "system:error-taxonomy",
               resource_ref: "public-seam:lower-read",
               authority_packet_ref: "authz-error-taxonomy",
               permission_decision_ref: "decision-error-taxonomy",
               idempotency_key: "error-taxonomy:tenant-scope-denied:1",
               trace_id: "trace:m16:084",
               correlation_id: "corr:m16:084",
               release_manifest_ref: "phase4-v6-milestone16",
               error_taxonomy_id: "error-taxonomy:tenant-scope-denied",
               owner_repo: "citadel",
               producer_ref: "Citadel.AuthorityContract.ErrorTaxonomy.V1",
               consumer_ref: "AppKit.Core.ErrorTaxonomyProjection",
               error_code: "tenant_scope_denied",
               error_class: :tenant_scope_error,
               retry_posture: :never,
               operator_safe_action: "stop_and_reauthorize",
               safe_action_code: "stop_and_reauthorize",
               redaction_class: :operator_summary,
               runbook_path: "runbooks/formal_error_taxonomy_coverage.md",
               operator_message_ref: "operator-message:error-taxonomy:tenant-scope-denied"
             })

    assert projection.contract_name == "Platform.ErrorTaxonomy.v1"
    assert projection.error_class == "tenant_scope_error"
    assert projection.retry_posture == "never"
    assert projection.redaction_class == "operator_summary"
  end

  test "rejects taxonomy projections without actor or formal safe action" do
    assert {:error, {:missing_required_fields, fields}} =
             ErrorTaxonomyProjection.new(
               valid_projection()
               |> Map.delete(:system_actor_ref)
               |> Map.delete(:operator_safe_action)
             )

    assert :principal_ref_or_system_actor_ref in fields
    assert :operator_safe_action in fields

    assert {:error, :invalid_error_taxonomy_projection} =
             ErrorTaxonomyProjection.new(%{valid_projection() | retry_posture: :retry_forever})
  end

  defp valid_projection do
    %{
      tenant_ref: "tenant-1",
      installation_ref: "inst-1",
      workspace_ref: "workspace-main",
      project_ref: "project-core",
      environment_ref: "prod",
      system_actor_ref: "system:error-taxonomy",
      resource_ref: "public-seam:lower-read",
      authority_packet_ref: "authz-error-taxonomy",
      permission_decision_ref: "decision-error-taxonomy",
      idempotency_key: "error-taxonomy:tenant-scope-denied:1",
      trace_id: "trace:m16:084",
      correlation_id: "corr:m16:084",
      release_manifest_ref: "phase4-v6-milestone16",
      error_taxonomy_id: "error-taxonomy:tenant-scope-denied",
      owner_repo: "citadel",
      producer_ref: "Citadel.AuthorityContract.ErrorTaxonomy.V1",
      consumer_ref: "AppKit.Core.ErrorTaxonomyProjection",
      error_code: "tenant_scope_denied",
      error_class: :tenant_scope_error,
      retry_posture: :never,
      operator_safe_action: "stop_and_reauthorize",
      safe_action_code: "stop_and_reauthorize",
      redaction_class: :operator_summary,
      runbook_path: "runbooks/formal_error_taxonomy_coverage.md",
      operator_message_ref: "operator-message:error-taxonomy:tenant-scope-denied"
    }
  end
end
