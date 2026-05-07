defmodule AppKit.HeadlessSurface.ContractTest do
  use ExUnit.Case, async: true

  alias AppKit.HeadlessSurface.Contract

  test "submits AgentIntake through governed ref-only DTOs" do
    assert {:ok, accepted} = Contract.submit(valid_submit())

    assert accepted.accepted? == true
    assert accepted.command_ref == "headless-command://tenant-1/idempotency-1"
    assert accepted.authority_projection_ref == "authority-projection://tenant-1/headless/1"
    assert accepted.runtime_invocation_ref == "runtime-invocation://tenant-1/headless/1"
    assert accepted.credential_handle_ref == "credential-handle://tenant-1/claude/main"
    assert accepted.native_auth_assertion_ref == "native-auth://tenant-1/claude/main"
    assert accepted.attach_grant_ref == "attach-grant://tenant-1/local-process/1"
    assert accepted.trace_ref == "trace://tenant-1/headless/1"

    assert accepted.persistence_posture.persistence_profile_ref ==
             "persistence-profile://mickey-mouse"

    assert accepted.persistence_posture.raw_payload_persistence? == false
    refute String.contains?(inspect(accepted), "secret")
  end

  test "headless optional retention off preserves accepted command semantics" do
    assert {:ok, accepted} =
             valid_submit()
             |> Map.put(:persistence_profile, :off)
             |> Contract.submit()

    assert accepted.accepted? == true
    assert accepted.command_ref == "headless-command://tenant-1/idempotency-1"
    assert accepted.persistence_posture.retained? == false
    assert accepted.persistence_posture.store_set_ref == "store-set://off"
  end

  test "rejects raw product bypass material before Mezzanine dispatch" do
    assert {:error, {:forbidden_headless_surface_material, forbidden}} =
             valid_submit()
             |> Map.put(:api_key, "secret")
             |> Map.put(:provider_payload, %{"token" => "secret"})
             |> Contract.submit()

    assert forbidden == [:api_key, :provider_payload]
  end

  test "operator commands are bounded to product-safe controls" do
    required_authority_actions = [
      :revoke_authority,
      :rotate_authority,
      :renew_authority,
      :rebind_authority,
      :detach_authority,
      :transfer_authority,
      :inspect_authority,
      :invalidate_authority
    ]

    assert Enum.all?(required_authority_actions, &(&1 in Contract.actions()))

    Enum.each(required_authority_actions, fn action ->
      assert {:ok, %Contract.OperatorCommand{action: ^action}} =
               Contract.operator_command(%{
                 action: Atom.to_string(action),
                 actor_ref: "actor://tenant-1/operator/1",
                 command_ref: "headless-command://tenant-1/#{action}",
                 authority_refs: ["authority://tenant-1/#{action}/1"]
               })
    end)

    assert {:ok, command} =
             Contract.operator_command(%{
               action: "detach_target",
               actor_ref: "actor://tenant-1/operator/1",
               command_ref: "headless-command://tenant-1/detach-1",
               authority_refs: ["attach-grant://tenant-1/local-process/1"]
             })

    assert command.action == :detach_target

    assert {:error, {:invalid_headless_surface_action, :dump_credentials}} =
             Contract.operator_command(%{
               action: :dump_credentials,
               actor_ref: "actor://tenant-1/operator/1",
               command_ref: "headless-command://tenant-1/dump-1"
             })
  end

  defp valid_submit do
    %{
      tenant_ref: "tenant://tenant-1",
      subject_ref: "subject://tenant-1/task/1",
      actor_ref: "actor://tenant-1/operator/1",
      authority_projection_ref: "authority-projection://tenant-1/headless/1",
      provider_account_ref: "provider-account://tenant-1/claude/main",
      connector_binding_ref: "connector-binding://tenant-1/claude/default",
      credential_handle_ref: "credential-handle://tenant-1/claude/main",
      credential_lease_ref: "credential-lease://tenant-1/claude/lease-1",
      native_auth_assertion_ref: "native-auth://tenant-1/claude/main",
      target_ref: "target://tenant-1/local-process/1",
      attach_grant_ref: "attach-grant://tenant-1/local-process/1",
      operation_policy_ref: "operation-policy://tenant-1/claude/coding",
      runtime_invocation_ref: "runtime-invocation://tenant-1/headless/1",
      trace_ref: "trace://tenant-1/headless/1",
      idempotency_key: "idempotency-1",
      correlation_id: "correlation://tenant-1/headless/1"
    }
  end
end
