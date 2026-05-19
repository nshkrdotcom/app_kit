defmodule AppKit.Bridges.MezzanineBridge.AgentIntakeAdapter do
  @moduledoc false

  @behaviour AppKit.Core.Backends.AgentIntakeBackend

  alias AppKit.Bridges.MezzanineBridge.{
    Common,
    RuntimeAdapter,
    RuntimeMapping,
    RuntimeReadbackMapping
  }

  alias AppKit.Core.AgentIntake.RunOutcomeFuture
  alias AppKit.Core.RequestContext
  alias AppKit.Core.RuntimeReadback.CommandResult

  @impl true
  def start_agent_run(%RequestContext{} = context, request, opts) do
    RuntimeAdapter.invoke_runtime_operation(
      context,
      RuntimeMapping.runtime_role_ref(request, opts),
      RuntimeMapping.operation_role_ref(request, opts),
      request,
      opts
    )
  end

  @impl true
  def submit_agent_turn(%RequestContext{}, turn_submission, opts) do
    if RuntimeMapping.runtime_available?(RuntimeMapping.agent_runtime(opts)) do
      CommandResult.new(%{
        command_ref: "command://#{turn_submission.idempotency_key}",
        command_kind: :submit_turn,
        accepted?: true,
        coalesced?: false,
        status: :accepted,
        authority_state: :local_policy,
        authority_refs: [],
        workflow_effect_state: "pending_signal",
        projection_state: :pending,
        trace_id: nil,
        correlation_id: turn_submission.run_ref,
        idempotency_key: turn_submission.idempotency_key,
        message: "Agent turn submission accepted through AppKit"
      })
    else
      {:error, :agent_turn_runtime_not_available}
    end
  end

  @impl true
  def cancel_agent_run(%RequestContext{}, run_ref, opts) do
    if RuntimeMapping.runtime_available?(RuntimeMapping.agent_runtime(opts)) do
      run_id = RuntimeReadbackMapping.readback_ref_id(run_ref)

      CommandResult.new(%{
        command_ref: "command://cancel/#{run_id}",
        command_kind: :cancel,
        accepted?: true,
        coalesced?: false,
        status: :accepted,
        authority_state: :local_policy,
        authority_refs: [],
        workflow_effect_state: "pending_signal",
        projection_state: :pending,
        correlation_id: run_id,
        idempotency_key: "agent-run:cancel:#{run_id}",
        message: "Agent run cancellation accepted through AppKit"
      })
    else
      {:error, :agent_turn_runtime_not_available}
    end
  end

  @impl true
  def await_agent_outcome(%RequestContext{}, run_ref, request, opts) do
    if RuntimeMapping.runtime_available?(RuntimeMapping.agent_runtime(opts)) do
      run_id = RuntimeReadbackMapping.readback_ref_id(run_ref)

      RunOutcomeFuture.new(%{
        run_ref: run_id,
        workflow_ref: Common.fetch_value(request || %{}, :workflow_ref),
        accepted?: true,
        command_ref: "command://await/#{run_id}",
        correlation_id: Common.fetch_value(request || %{}, :correlation_id) || run_id,
        polling_hint: %{checking?: false, poll_interval_ms: 1_000, staleness_ms: 0}
      })
    else
      {:error, :agent_turn_runtime_not_available}
    end
  end
end
