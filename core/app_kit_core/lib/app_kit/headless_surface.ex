defmodule AppKit.HeadlessSurface do
  @moduledoc """
  Product-facing M1 readback and control surface.

  Products call this module instead of lower Mezzanine internals. Standalone
  backend selection is passed through `AppKit.BackendStack` or explicit
  backend options; runtime application environment is not used as backend
  authority.
  """

  alias AppKit.BackendConfig
  alias AppKit.Core.RuntimeReadback.{ControlRequest, RefreshRequest}

  @backend_key :headless_backend
  @default_backend AppKit.Bridges.MezzanineBridge

  def state_snapshot(context, request \\ %{}, opts \\ []) when is_list(opts) do
    backend(opts).state_snapshot(context, request || %{}, opts)
  end

  def subject_detail(context, subject_ref, request \\ %{}, opts \\ []) when is_list(opts) do
    backend(opts).runtime_subject_detail(context, subject_ref, request || %{}, opts)
  end

  def run_detail(context, run_ref, request \\ %{}, opts \\ []) when is_list(opts) do
    backend(opts).runtime_run_detail(context, run_ref, request || %{}, opts)
  end

  def request_refresh(context, refresh_request, opts \\ []) when is_list(opts) do
    with {:ok, request} <- RefreshRequest.new(refresh_request) do
      backend(opts).request_runtime_refresh(context, request, opts)
    end
  end

  def request_control(context, control_request, opts \\ []) when is_list(opts) do
    with {:ok, request} <- ControlRequest.new(control_request) do
      backend(opts).request_runtime_control(context, request, opts)
    end
  end

  defp backend(opts) do
    BackendConfig.resolve(opts, :backend, @backend_key, @default_backend)
  end
end

defmodule AppKit.AgentIntake do
  @moduledoc """
  Product-facing M2 intake surface.

  The surface exists before the M2 workflow is installed. Backends must fail
  closed with `{:error, :agent_turn_runtime_not_available}` rather than routing
  around AppKit or calling providers directly.
  """

  alias AppKit.BackendConfig

  alias AppKit.Core.AgentIntake.{
    AgentRunCursor,
    AgentRunRequest,
    PendingInteractionQuery,
    TurnSubmission
  }

  @backend_key :agent_intake_backend
  @default_backend AppKit.Bridges.MezzanineBridge

  def start_agent_run(context, request, opts \\ []) when is_list(opts) do
    with {:ok, request} <- AgentRunRequest.new(request) do
      backend(opts).start_agent_run(context, request, opts)
    end
  end

  def submit_turn(context, turn_submission, opts \\ []) when is_list(opts) do
    with {:ok, submission} <- TurnSubmission.new(turn_submission) do
      backend(opts).submit_agent_turn(context, submission, opts)
    end
  end

  def cancel_agent_run(context, run_ref, opts \\ []) when is_list(opts) do
    backend(opts).cancel_agent_run(context, run_ref, opts)
  end

  def await_agent_outcome(context, run_ref, request \\ %{}, opts \\ []) when is_list(opts) do
    backend(opts).await_agent_outcome(context, run_ref, request || %{}, opts)
  end

  def catch_up_agent_events(context, cursor, opts \\ []) when is_list(opts) do
    with {:ok, cursor} <- AgentRunCursor.new(cursor) do
      backend(opts).catch_up_agent_events(context, cursor, opts)
    end
  end

  def list_pending_interactions(context, request, opts \\ []) when is_list(opts) do
    with {:ok, request} <- PendingInteractionQuery.new(request) do
      backend(opts).list_pending_interactions(context, request, opts)
    end
  end

  defp backend(opts) do
    BackendConfig.resolve(opts, :backend, @backend_key, @default_backend)
  end
end
