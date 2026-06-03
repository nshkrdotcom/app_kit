defmodule AppKit.EvolutionSurface.Backend do
  @moduledoc "Backend behaviour for AppKit.EvolutionSurface dispatch."

  alias AppKit.Core.Evolution.DTO
  alias AppKit.Core.Evolution.SurfaceError
  alias AppKit.Core.RequestContext

  @callback list_evolution_batches(RequestContext.t(), map(), keyword()) ::
              {:ok, DTO.EvolutionBatchPage.t()} | {:error, SurfaceError.t()}
  @callback get_evolution_batch(RequestContext.t(), String.t(), keyword()) ::
              {:ok, DTO.EvolutionBatchSummary.t()} | {:error, SurfaceError.t()}
  @callback get_evolution_status(RequestContext.t(), String.t(), keyword()) ::
              {:ok, DTO.EvolutionStatus.t()} | {:error, SurfaceError.t()}
  @callback get_candidate_summary(RequestContext.t(), String.t(), keyword()) ::
              {:ok, DTO.CandidateSummary.t()} | {:error, SurfaceError.t()}
  @callback get_trial_summary(RequestContext.t(), String.t(), keyword()) ::
              {:ok, DTO.TrialSummary.t()} | {:error, SurfaceError.t()}
  @callback request_candidate_promotion(RequestContext.t(), String.t(), map(), keyword()) ::
              {:ok, DTO.PromotionRequestResult.t()} | {:error, SurfaceError.t()}
  @callback record_operator_consent(RequestContext.t(), String.t(), map(), keyword()) ::
              {:ok, DTO.OperatorConsentResult.t()} | {:error, SurfaceError.t()}
  @callback get_swap_status(RequestContext.t(), String.t(), keyword()) ::
              {:ok, DTO.SwapStatus.t()} | {:error, SurfaceError.t()}
end
