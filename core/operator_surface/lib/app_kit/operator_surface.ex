defmodule AppKit.OperatorSurface do
  @moduledoc """
  Operator-facing composition around lower review and projection reads.
  """

  alias AppKit.AppConfig
  alias AppKit.Bridges.{IntegrationBridge, ProjectionBridge}
  alias AppKit.Core.RunRef
  alias AppKit.RunGovernance

  @spec run_status(RunRef.t(), map(), keyword()) :: {:ok, map()} | {:error, atom()}
  def run_status(%RunRef{} = run_ref, attrs, opts \\ []) do
    with {:ok, config} <- AppConfig.normalize(Keyword.get(opts, :config)),
         true <- config.operator_surface? do
      ProjectionBridge.operator_projection(run_ref, attrs)
    else
      false -> {:error, :operator_surface_disabled}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec review_run(RunRef.t(), map(), keyword()) :: {:ok, map()} | {:error, atom()}
  def review_run(%RunRef{} = run_ref, evidence_attrs, opts \\ []) do
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
