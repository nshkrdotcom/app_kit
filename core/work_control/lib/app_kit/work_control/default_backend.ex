defmodule AppKit.WorkControl.DefaultBackend do
  @moduledoc """
  Default lower-stack-backed implementation for `AppKit.WorkControl`.
  """

  @behaviour AppKit.Core.Backends.WorkBackend

  alias AppKit.Bridges.IntegrationBridge
  alias AppKit.Core.{Result, RunRef}

  @impl true
  def start_run(domain_call, opts) when is_map(domain_call) do
    with {:ok, run_ref} <-
           RunRef.new(%{
             run_id:
               Keyword.get(opts, :run_id, "run/#{Map.get(domain_call, :route_name, :unknown)}"),
             scope_id: Map.get(domain_call, :scope_id, "scope/unknown")
           }),
         {:ok, submission} <-
           IntegrationBridge.compile_run_submission(run_ref, %{
             review_required: Keyword.get(opts, :review_required, false),
             target: Keyword.get(opts, :target, :default)
           }) do
      state = if(submission.review_required, do: :waiting_review, else: :scheduled)
      Result.new(%{surface: :work_control, state: state, payload: %{submission: submission}})
    end
  end
end
