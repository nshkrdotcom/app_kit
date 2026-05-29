defmodule AppKit.EvolutionSurface do
  @moduledoc "Product/operator-safe surface for Chassis Evolution readback and consent."

  def list_evolution_batches(ctx, params, opts \\ []),
    do: call_backend(opts, :list_evolution_batches, [ctx, params])

  def get_evolution_status(ctx, params, opts \\ []),
    do: call_backend(opts, :get_evolution_status, [ctx, params])

  def record_operator_consent(ctx, params, opts \\ []),
    do: call_backend(opts, :record_operator_consent, [ctx, params])

  def get_candidate_diff(ctx, params, opts \\ []),
    do: call_backend(opts, :get_candidate_diff, [ctx, params])

  defp call_backend(opts, function, args) do
    backend =
      AppKit.BackendConfig.resolve(
        opts,
        :evolution_surface_backend,
        :evolution_surface_backend,
        AppKit.EvolutionSurface.Backend.Standalone
      )

    dispatch_backend(backend, function, args, opts)
  end

  defp dispatch_backend(backend, :list_evolution_batches, [ctx, params], opts),
    do: backend.list_evolution_batches(ctx, params, opts)

  defp dispatch_backend(backend, :get_evolution_status, [ctx, params], opts),
    do: backend.get_evolution_status(ctx, params, opts)

  defp dispatch_backend(backend, :record_operator_consent, [ctx, params], opts),
    do: backend.record_operator_consent(ctx, params, opts)

  defp dispatch_backend(backend, :get_candidate_diff, [ctx, params], opts),
    do: backend.get_candidate_diff(ctx, params, opts)
end

defmodule AppKit.EvolutionSurface.Backend.Local do
  @moduledoc "Local Chassis Evolution backend."
  def list_evolution_batches(ctx, params, _opts),
    do: {:ok, %{tenant_ref: ctx[:tenant_ref], items: [], limit: params[:limit] || 10}}

  def get_evolution_status(_ctx, params, _opts),
    do: {:ok, %{evolution_ref: params[:evolution_ref] || "evo:dev:smoke", state: :queued}}

  def record_operator_consent(_ctx, params, _opts),
    do: {:ok, Map.put(params, :operator_consent_ref, "consent:cand:dev:smoke")}

  def get_candidate_diff(_ctx, params, _opts),
    do:
      if(Map.has_key?(params, :lower_read_lease_ref),
        do: {:ok, %{diff_ref: "art:diff:smoke"}},
        else: {:error, :raw_diff_lease_required}
      )
end

defmodule AppKit.EvolutionSurface.Backend.Boundary do
  @moduledoc "Boundary-backed Chassis Evolution surface."
  defdelegate list_evolution_batches(ctx, params, opts), to: AppKit.EvolutionSurface.Backend.Local
  defdelegate get_evolution_status(ctx, params, opts), to: AppKit.EvolutionSurface.Backend.Local

  defdelegate record_operator_consent(ctx, params, opts),
    to: AppKit.EvolutionSurface.Backend.Local

  defdelegate get_candidate_diff(ctx, params, opts), to: AppKit.EvolutionSurface.Backend.Local
end

defmodule AppKit.EvolutionSurface.Backend.Standalone do
  @moduledoc "Standalone Chassis Evolution surface fallback."
  defdelegate list_evolution_batches(ctx, params, opts), to: AppKit.EvolutionSurface.Backend.Local
  defdelegate get_evolution_status(ctx, params, opts), to: AppKit.EvolutionSurface.Backend.Local

  defdelegate record_operator_consent(ctx, params, opts),
    to: AppKit.EvolutionSurface.Backend.Local

  defdelegate get_candidate_diff(ctx, params, opts), to: AppKit.EvolutionSurface.Backend.Local
end

defmodule AppKit.Core.Evolution.DTO.BatchSummary do
  @moduledoc "Product-safe Chassis Evolution batch summary."
  defstruct [:failure_batch_ref, :tenant_ref, :summary, :redaction_posture]
end

defmodule AppKit.Core.Evolution.DTO.CandidateSummary do
  @moduledoc "Product-safe Chassis Evolution candidate summary."
  defstruct [:candidate_ref, :state, :score_matrix_ref, :diff_ref]
end

defmodule AppKit.EvolutionSurface.RedactedDiffRef do
  @moduledoc "Reference to lower-read diff material."
  defstruct [:diff_ref, :lower_read_lease_ref]
end
