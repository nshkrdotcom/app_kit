defmodule AppKit.Core.Backends.RuntimeBackend do
  @moduledoc """
  Backend contract for product-safe runtime profile, status, logs, and live-effect proof reads.
  """

  alias AppKit.Core.{RequestContext, SurfaceError}

  alias AppKit.Core.RuntimeSurface.{
    GitHubPrBranchCleanupReceipt,
    GitHubPrEvidenceReceipt,
    LiveEffectReceipt,
    RuntimeLogPage,
    RuntimeProfileApplyResult,
    RuntimeStatusSnapshot
  }

  @callback apply_runtime_profile(RequestContext.t(), map(), keyword()) ::
              {:ok, RuntimeProfileApplyResult.t()} | {:error, SurfaceError.t()}

  @callback runtime_status(RequestContext.t(), map(), keyword()) ::
              {:ok, RuntimeStatusSnapshot.t()} | {:error, SurfaceError.t()}

  @callback runtime_logs(RequestContext.t(), map(), keyword()) ::
              {:ok, RuntimeLogPage.t()} | {:error, SurfaceError.t()}

  @callback record_live_effect(RequestContext.t(), map(), keyword()) ::
              {:ok, LiveEffectReceipt.t()} | {:error, SurfaceError.t()}

  @callback fetch_github_pr_evidence(RequestContext.t(), map(), keyword()) ::
              {:ok, GitHubPrEvidenceReceipt.t()} | {:error, SurfaceError.t()}

  @callback cleanup_github_pr_branch(RequestContext.t(), map(), keyword()) ::
              {:ok, GitHubPrBranchCleanupReceipt.t()} | {:error, SurfaceError.t()}
end
