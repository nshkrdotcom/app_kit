defmodule Mezzanine.AppKitBridge.RecoveryControlTest do
  use ExUnit.Case, async: true

  alias AppKit.Bridges.MezzanineBridge.HeadlessAdapter
  alias AppKit.Core.RequestContext
  alias AppKit.Core.RuntimeReadback.{CommandResult, ControlRequest}
  alias Mezzanine.AppKitBridge.WorkControlService

  @run_ref "run://mezzanine/tenant-1/agent-1"

  defmodule FakeRecoveryControl do
    def control(context, run_ref, action, expected_version, attrs, opts) do
      send(
        Keyword.fetch!(opts, :test_pid),
        {:durable_control, context, run_ref, action, expected_version, attrs}
      )

      Keyword.fetch!(opts, :result)
    end
  end

  test "submits an optimistic owner command and returns only durable acknowledgement" do
    result =
      {:ok,
       %{
         command_ref: "command://mezzanine/control/1",
         event_ref: "event://mezzanine/control/1",
         outbox_ref: "outbox://mezzanine/control/1",
         control_state: "pause_requested",
         idempotent_replay?: false
       }}

    assert {:ok, %CommandResult{} = command} =
             WorkControlService.control_run(
               context(),
               request(:pause),
               recovery_control_service: FakeRecoveryControl,
               recovery_control_opts: [test_pid: self(), result: result]
             )

    assert_receive {:durable_control, lower_context, @run_ref, :pause, 7, attrs}
    assert lower_context.tenant_ref == "tenant-1"
    assert lower_context.actor_ref == "actor://synapse/operator"
    assert lower_context.authority_ref == "authority://synapse/control"
    assert lower_context.permission_decision_ref == "decision://synapse/control/1"
    assert attrs.idempotency_key == "synapse-control-1"
    assert String.starts_with?(attrs.command_ref, "command://app-kit/control/")

    assert command.accepted?
    refute command.coalesced?
    assert command.workflow_effect_state == "queued_signal"
    assert command.projection_state == "pause_requested"
    assert command.receipt_ref == "event://mezzanine/control/1"
    assert command.persistence_posture.durable?
  end

  test "headless control maps stale owner version to a reload conflict" do
    result = {:error, {:stale_control_version, 9}}

    assert {:error, error} =
             HeadlessAdapter.request_runtime_control(
               context(),
               request(:resume),
               work_control_service: WorkControlService,
               recovery_control_service: FakeRecoveryControl,
               recovery_control_opts: [test_pid: self(), result: result]
             )

    assert error.code == "stale_control_version"
    assert error.kind == :conflict
    refute error.retryable
    assert error.details.current_control_row_version == 9
  end

  test "unsupported controls and actor mismatches fail before owner dispatch" do
    assert {:error, :unsupported_durable_control_action} =
             WorkControlService.control_run(context(), request(:rework), [])

    mismatched = %{request(:cancel) | actor_ref: "actor://other/operator"}

    assert {:error, :operator_actor_context_mismatch} =
             WorkControlService.control_run(context(), mismatched, [])

    refute_received {:durable_control, _, _, _, _, _}
  end

  test "authority evidence and optimistic row version are mandatory" do
    context_without_authority = %{context() | metadata: %{}}

    assert {:error, :missing_control_authority_ref} =
             WorkControlService.control_run(context_without_authority, request(:cancel), [])

    invalid_version = %{request(:cancel) | params: %{expected_control_row_version: 0}}

    assert {:error, :invalid_expected_control_row_version} =
             WorkControlService.control_run(context(), invalid_version, [])
  end

  defp context do
    {:ok, context} =
      RequestContext.new(%{
        trace_id: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        actor_ref: %{id: "actor://synapse/operator", kind: :human},
        tenant_ref: %{id: "tenant-1"},
        request_id: "request://synapse/control/1",
        metadata: %{
          control_authority_ref: "authority://synapse/control",
          control_permission_decision_ref: "decision://synapse/control/1"
        }
      })

    context
  end

  defp request(action) do
    ControlRequest.new!(%{
      idempotency_key: "synapse-control-1",
      actor_ref: "actor://synapse/operator",
      run_ref: @run_ref,
      action: action,
      params: %{expected_control_row_version: 7}
    })
  end
end
