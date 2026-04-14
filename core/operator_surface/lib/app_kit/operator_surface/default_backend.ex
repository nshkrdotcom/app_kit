defmodule AppKit.OperatorSurface.DefaultBackend do
  @moduledoc """
  Default lower-stack-backed implementation for `AppKit.OperatorSurface`.
  """

  @behaviour AppKit.Core.Backends.OperatorBackend

  alias AppKit.Bridges.{IntegrationBridge, ProjectionBridge}
  alias AppKit.Core.RunRef
  alias AppKit.RunGovernance

  @impl true
  def run_status(%RunRef{} = run_ref, attrs, _opts) when is_map(attrs) do
    ProjectionBridge.operator_projection(run_ref, attrs)
  end

  @impl true
  def review_run(%RunRef{} = run_ref, evidence_attrs, opts) do
    with {:ok, evidence} <- RunGovernance.evidence(evidence_attrs),
         state <- RunGovernance.review_state(evidence, opts),
         {:ok, decision} <-
           RunGovernance.decision(%{
             run_id: run_ref.run_id,
             state: state,
             reason: Keyword.get(opts, :reason)
           }),
         {:ok, review_bundle} <-
           IntegrationBridge.review_bundle(run_ref, %{
             summary: evidence.summary,
             evidence_count: 1
           }) do
      {:ok, %{decision: decision, review_bundle: review_bundle}}
    end
  end
end
