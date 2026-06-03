defmodule AppKit.EvolutionSurface.Backend.Local do
  @moduledoc "Local Chassis Evolution backend backed by co-located safe stores."

  @behaviour AppKit.EvolutionSurface.Backend

  alias AppKit.EvolutionSurface.Backend.Standalone

  @impl true
  def list_evolution_batches(context, request, opts),
    do: Standalone.list_evolution_batches(context, request, opts)

  @impl true
  def get_evolution_batch(context, batch_ref, opts),
    do: Standalone.get_evolution_batch(context, batch_ref, opts)

  @impl true
  def get_evolution_status(context, evolution_ref, opts),
    do: Standalone.get_evolution_status(context, evolution_ref, opts)

  @impl true
  def get_candidate_summary(context, candidate_ref, opts),
    do: Standalone.get_candidate_summary(context, candidate_ref, opts)

  @impl true
  def get_trial_summary(context, trial_ref, opts),
    do: Standalone.get_trial_summary(context, trial_ref, opts)

  @impl true
  def request_candidate_promotion(context, candidate_ref, request, opts),
    do: Standalone.request_candidate_promotion(context, candidate_ref, request, opts)

  @impl true
  def record_operator_consent(context, candidate_ref, decision, opts),
    do: Standalone.record_operator_consent(context, candidate_ref, decision, opts)

  @impl true
  def get_swap_status(context, swap_ref, opts),
    do: Standalone.get_swap_status(context, swap_ref, opts)
end
