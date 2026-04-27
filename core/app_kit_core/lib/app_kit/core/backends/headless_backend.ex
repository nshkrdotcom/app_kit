defmodule AppKit.Core.Backends.HeadlessBackend do
  @moduledoc "Backend contract for M1 runtime readback and control."

  @callback state_snapshot(context :: term(), request :: term(), opts :: keyword()) ::
              {:ok, struct()} | {:error, term()}

  @callback runtime_subject_detail(
              context :: term(),
              subject_ref :: term(),
              request :: term(),
              opts :: keyword()
            ) ::
              {:ok, struct()} | {:error, term()}

  @callback runtime_run_detail(
              context :: term(),
              run_ref :: term(),
              request :: term(),
              opts :: keyword()
            ) ::
              {:ok, struct()} | {:error, term()}

  @callback request_runtime_refresh(
              context :: term(),
              refresh_request :: struct(),
              opts :: keyword()
            ) ::
              {:ok, struct()} | {:error, term()}

  @callback request_runtime_control(
              context :: term(),
              control_request :: struct(),
              opts :: keyword()
            ) ::
              {:ok, struct()} | {:error, term()}
end

defmodule AppKit.Core.Backends.AgentIntakeBackend do
  @moduledoc "Backend contract for M2 agent intake. Implementations may fail closed before M2 exists."

  @callback start_agent_run(context :: term(), request :: struct(), opts :: keyword()) ::
              {:ok, struct()} | {:error, term()}

  @callback submit_agent_turn(context :: term(), turn_submission :: struct(), opts :: keyword()) ::
              {:ok, struct()} | {:error, term()}

  @callback cancel_agent_run(context :: term(), run_ref :: term(), opts :: keyword()) ::
              {:ok, struct()} | {:error, term()}

  @callback await_agent_outcome(
              context :: term(),
              run_ref :: term(),
              request :: term(),
              opts :: keyword()
            ) ::
              {:ok, struct()} | {:error, term()}
end
