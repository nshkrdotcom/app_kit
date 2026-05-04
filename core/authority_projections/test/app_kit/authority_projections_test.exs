defmodule AppKit.AuthorityProjectionsTest do
  use ExUnit.Case, async: true

  alias AppKit.AuthorityProjections

  test "builds ref-only authority projection DTOs" do
    assert {:ok, projection} = AuthorityProjections.project(valid_attrs())

    assert projection.authority_packet_ref == "authority-packet://tenant-1/packet-1"
    assert projection.provider_account_ref == "provider-account://tenant-1/claude/main"
    assert projection.credential_lease_ref == "credential-lease://tenant-1/claude/lease-1"
    assert projection.native_auth_assertion_ref == "native-auth-assertion://tenant-1/claude/1"
    assert projection.raw_material_present? == false

    assert AuthorityProjections.dump(projection)["provider_family"] == "claude"
  end

  test "rejects missing ref families and reports exact missing fields" do
    assert {:error, {:missing_required_refs, missing}} =
             valid_attrs()
             |> Map.delete(:credential_lease_ref)
             |> Map.delete(:target_ref)
             |> AuthorityProjections.project()

    assert missing == [:credential_lease_ref, :target_ref]
  end

  test "rejects raw secrets, native auth material, target credentials, and provider payloads" do
    assert {:error, {:forbidden_projection_material, forbidden}} =
             valid_attrs()
             |> Map.put(:raw_token, "secret")
             |> Map.put(:native_auth_file, "secret")
             |> Map.put(:target_credentials, %{"token" => "secret"})
             |> Map.put(:provider_payload, %{"token" => "secret"})
             |> AuthorityProjections.project()

    assert forbidden == [:native_auth_file, :provider_payload, :raw_token, :target_credentials]
  end

  test "redacts operator DTO dumps to refs and summaries only" do
    assert {:ok, projection} = AuthorityProjections.project(valid_attrs())

    dto = AuthorityProjections.operator_dto(projection)

    assert dto["authority_packet_ref"] == "authority-packet://tenant-1/packet-1"
    assert dto["raw_material_present?"] == false
    assert dto["redaction_ref"] == "redaction://tenant-1/authority-projection/1"
    refute inspect(dto) =~ "secret"
    refute Map.has_key?(dto, "provider_payload")
  end

  defp valid_attrs do
    %{
      authority_packet_ref: "authority-packet://tenant-1/packet-1",
      system_authorization_ref: "system-authority://tenant-1/decision-1",
      provider_family: "claude",
      provider_account_ref: "provider-account://tenant-1/claude/main",
      connector_instance_ref: "connector-instance://tenant-1/claude/default",
      connector_binding_ref: "connector-binding://tenant-1/claude/default",
      credential_handle_ref: "credential-handle://tenant-1/claude/handle-1",
      credential_lease_ref: "credential-lease://tenant-1/claude/lease-1",
      native_auth_assertion_ref: "native-auth-assertion://tenant-1/claude/1",
      target_ref: "target://tenant-1/local-process/1",
      attach_grant_ref: "attach-grant://tenant-1/local-process/1",
      operation_policy_ref: "operation-policy://tenant-1/claude/chat",
      evidence_ref: "evidence://tenant-1/authority/1",
      redaction_ref: "redaction://tenant-1/authority-projection/1",
      trace_ref: "trace://tenant-1/authority/1"
    }
  end
end
