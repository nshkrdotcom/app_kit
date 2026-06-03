defmodule AppKit.EvolutionSurface do
  @moduledoc "Product/operator-safe surface for Chassis Evolution readback and consent."

  alias AppKit.BackendConfig
  alias AppKit.Core.Evolution.DTO
  alias AppKit.Core.Evolution.SurfaceError
  alias AppKit.Core.RequestContext

  @default_backend AppKit.EvolutionSurface.Backend.Local

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

  @spec list_evolution_batches(RequestContext.t(), map(), keyword()) ::
          {:ok, DTO.EvolutionBatchPage.t()} | {:error, SurfaceError.t()}
  def list_evolution_batches(%RequestContext{} = context, request, opts \\ [])
      when is_map(request) do
    call_backend(opts, :list_evolution_batches, [context, request, opts])
  end

  @spec get_evolution_batch(RequestContext.t(), String.t(), keyword()) ::
          {:ok, DTO.EvolutionBatchSummary.t()} | {:error, SurfaceError.t()}
  def get_evolution_batch(%RequestContext{} = context, batch_ref, opts \\ [])
      when is_binary(batch_ref) do
    call_backend(opts, :get_evolution_batch, [context, batch_ref, opts])
  end

  @spec get_evolution_status(RequestContext.t(), String.t(), keyword()) ::
          {:ok, DTO.EvolutionStatus.t()} | {:error, SurfaceError.t()}
  def get_evolution_status(%RequestContext{} = context, evolution_ref, opts \\ [])
      when is_binary(evolution_ref) do
    call_backend(opts, :get_evolution_status, [context, evolution_ref, opts])
  end

  @spec get_candidate_summary(RequestContext.t(), String.t(), keyword()) ::
          {:ok, DTO.CandidateSummary.t()} | {:error, SurfaceError.t()}
  def get_candidate_summary(%RequestContext{} = context, candidate_ref, opts \\ [])
      when is_binary(candidate_ref) do
    call_backend(opts, :get_candidate_summary, [context, candidate_ref, opts])
  end

  @spec get_trial_summary(RequestContext.t(), String.t(), keyword()) ::
          {:ok, DTO.TrialSummary.t()} | {:error, SurfaceError.t()}
  def get_trial_summary(%RequestContext{} = context, trial_ref, opts \\ [])
      when is_binary(trial_ref) do
    call_backend(opts, :get_trial_summary, [context, trial_ref, opts])
  end

  @spec request_candidate_promotion(RequestContext.t(), String.t(), map(), keyword()) ::
          {:ok, DTO.PromotionRequestResult.t()} | {:error, SurfaceError.t()}
  def request_candidate_promotion(%RequestContext{} = context, candidate_ref, request, opts \\ [])
      when is_binary(candidate_ref) and is_map(request) do
    call_backend(opts, :request_candidate_promotion, [context, candidate_ref, request, opts])
  end

  @spec record_operator_consent(RequestContext.t(), String.t(), map(), keyword()) ::
          {:ok, DTO.OperatorConsentResult.t()} | {:error, SurfaceError.t()}
  def record_operator_consent(%RequestContext{} = context, candidate_ref, decision, opts \\ [])
      when is_binary(candidate_ref) and is_map(decision) do
    call_backend(opts, :record_operator_consent, [context, candidate_ref, decision, opts])
  end

  @spec get_swap_status(RequestContext.t(), String.t(), keyword()) ::
          {:ok, DTO.SwapStatus.t()} | {:error, SurfaceError.t()}
  def get_swap_status(%RequestContext{} = context, swap_ref, opts \\ [])
      when is_binary(swap_ref) do
    call_backend(opts, :get_swap_status, [context, swap_ref, opts])
  end

  @spec get_candidate_diff(RequestContext.t(), String.t(), keyword()) ::
          {:error, SurfaceError.t()}
  def get_candidate_diff(%RequestContext{} = _context, candidate_ref, _opts \\ [])
      when is_binary(candidate_ref) do
    {:error,
     SurfaceError.new!(%{
       code: :raw_diff_not_exposed,
       message: "Raw diffs are not exposed through AppKit EvolutionSurface",
       detail: %{candidate_ref: candidate_ref}
     })}
  end

  defp call_backend(opts, function_name, args) do
    opts
    |> resolve_backend()
    |> invoke(function_name, args)
  end

  defp resolve_backend(opts) do
    BackendConfig.resolve(
      opts,
      :evolution_surface_backend,
      :evolution_surface_backend,
      @default_backend
    )
  end

  defp invoke(backend, function_name, args) when is_atom(backend),
    do: apply(backend, function_name, args)

  defp invoke({backend, backend_opts}, function_name, [context | args]) do
    opts = List.last(args)
    args = List.replace_at([context | args], length(args), Keyword.merge(backend_opts, opts))
    apply(backend, function_name, args)
  end
end
