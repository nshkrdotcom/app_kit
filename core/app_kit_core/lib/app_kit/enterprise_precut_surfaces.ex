defmodule AppKit.CommandSurface do
  @moduledoc """
  Behaviour for AppKit command admission backends.
  """

  alias AppKit.Core.{CommandEnvelope, CommandResult, RequestContext, SurfaceError}

  @callback submit_command(RequestContext.t(), CommandEnvelope.t()) ::
              {:ok, CommandResult.t()} | {:error, SurfaceError.t()}
  @callback fetch_command(RequestContext.t(), String.t()) ::
              {:ok, CommandEnvelope.t()} | {:error, SurfaceError.t()}
  @callback fetch_command_result(RequestContext.t(), String.t()) ::
              {:ok, CommandResult.t()} | {:error, SurfaceError.t()}
end

defmodule AppKit.WorkflowControlSurface do
  @moduledoc """
  Behaviour for workflow start, signal, cancel, retry, and replan controls.
  """

  alias AppKit.Core.{
    CommandResult,
    RequestContext,
    SurfaceError,
    WorkflowSignalRequest,
    WorkflowStartRequest
  }

  @callback start_workflow(RequestContext.t(), WorkflowStartRequest.t()) ::
              {:ok, CommandResult.t()} | {:error, SurfaceError.t()}
  @callback signal_workflow(RequestContext.t(), WorkflowSignalRequest.t()) ::
              {:ok, CommandResult.t()} | {:error, SurfaceError.t()}
  @callback cancel_workflow(RequestContext.t(), WorkflowSignalRequest.t()) ::
              {:ok, CommandResult.t()} | {:error, SurfaceError.t()}
  @callback retry_workflow_step(RequestContext.t(), WorkflowSignalRequest.t()) ::
              {:ok, CommandResult.t()} | {:error, SurfaceError.t()}
  @callback replan_workflow(RequestContext.t(), WorkflowSignalRequest.t()) ::
              {:ok, CommandResult.t()} | {:error, SurfaceError.t()}
end

defmodule AppKit.WorkflowReadSurface do
  @moduledoc """
  Behaviour for workflow reads exposed through public-safe DTOs.
  """

  alias AppKit.Core.{RequestContext, SurfaceError, WorkflowQueryRequest, WorkflowRef}

  @callback describe_workflow(RequestContext.t(), WorkflowRef.t()) ::
              {:ok, map()} | {:error, SurfaceError.t()}
  @callback query_workflow(RequestContext.t(), WorkflowQueryRequest.t()) ::
              {:ok, map()} | {:error, SurfaceError.t()}
end

defmodule AppKit.OperatorActionSurface do
  @moduledoc """
  Behaviour for operator mutations that must route through authority.
  """

  alias AppKit.Core.{CommandEnvelope, CommandResult, RequestContext, SurfaceError}

  @callback submit_operator_action(RequestContext.t(), CommandEnvelope.t()) ::
              {:ok, CommandResult.t()} | {:error, SurfaceError.t()}
end

defmodule AppKit.LowerReadSurface do
  @moduledoc """
  Behaviour for tenant/authority-scoped lower reads and attach requests.
  """

  alias AppKit.Core.{LowerScopeRef, RequestContext, SurfaceError}

  @callback read_lower_run(RequestContext.t(), LowerScopeRef.t()) ::
              {:ok, map()} | {:error, SurfaceError.t()}
  @callback read_artifact(RequestContext.t(), LowerScopeRef.t()) ::
              {:ok, map()} | {:error, SurfaceError.t()}
  @callback request_attach(RequestContext.t(), LowerScopeRef.t()) ::
              {:ok, map()} | {:error, SurfaceError.t()}
end

defmodule AppKit.AttachSurface do
  @moduledoc """
  Behaviour for public-safe attach grant surfaces.
  """

  alias AppKit.Core.{AttachGrantRef, LowerScopeRef, RequestContext, SurfaceError}

  @callback request_attach(RequestContext.t(), LowerScopeRef.t()) ::
              {:ok, AttachGrantRef.t()} | {:error, SurfaceError.t()}
end

defmodule AppKit.ProjectionSurface do
  @moduledoc """
  Behaviour for public-safe projection reads.
  """

  alias AppKit.Core.{ProjectionRef, RequestContext, SurfaceError}

  @callback fetch_projection(RequestContext.t(), ProjectionRef.t()) ::
              {:ok, map()} | {:error, SurfaceError.t()}
end
