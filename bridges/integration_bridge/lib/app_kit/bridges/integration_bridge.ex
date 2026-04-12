defmodule AppKit.Bridges.IntegrationBridge do
  @moduledoc """
  App-facing bridge for durable run submissions and review bundles.
  """

  alias AppKit.Core.RunRef

  @spec compile_run_submission(RunRef.t(), map()) :: {:ok, map()} | {:error, atom()}
  def compile_run_submission(%RunRef{} = run_ref, attrs) when is_map(attrs) do
    {:ok,
     %{
       run_id: run_ref.run_id,
       scope_id: run_ref.scope_id,
       review_required: Map.get(attrs, :review_required, false),
       target: Map.get(attrs, :target, :default)
     }}
  end

  @spec review_bundle(RunRef.t(), map()) :: {:ok, map()} | {:error, atom()}
  def review_bundle(%RunRef{} = run_ref, attrs) when is_map(attrs) do
    {:ok,
     %{
       run_id: run_ref.run_id,
       summary: Map.get(attrs, :summary, "pending"),
       evidence_count: Map.get(attrs, :evidence_count, 0)
     }}
  end
end
