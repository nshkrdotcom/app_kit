defmodule AppKit.WorkControl.DefaultBackend do
  @moduledoc """
  Default lower-stack-backed implementation for `AppKit.WorkControl`.
  """

  @behaviour AppKit.Core.Backends.WorkBackend

  alias AppKit.Bridges.IntegrationBridge
  alias AppKit.Core.{ActionResult, RequestContext, Result, RunRef, RunRequest, SurfaceError}

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

  @impl true
  @spec start_run(RequestContext.t(), RunRequest.t(), keyword()) ::
          {:ok, Result.t()} | {:error, SurfaceError.t()}
  def start_run(%RequestContext{} = context, %RunRequest{} = run_request, opts)
      when is_list(opts) do
    case typed_run_ref(context, run_request, opts) do
      {:ok, run_ref} ->
        Result.new(%{
          surface: :work_control,
          state: typed_run_state(run_request, opts),
          payload: %{
            run_ref: run_ref,
            work_object_id: run_request.subject_ref.id,
            subject_ref: run_request.subject_ref,
            trace_id: context.trace_id,
            recipe_ref: run_request.recipe_ref,
            params: run_request.params
          }
        })

      {:error, _reason} ->
        {:ok, error} =
          SurfaceError.new(%{
            code: "invalid_run_request",
            message: "Invalid run request",
            kind: :validation,
            retryable: false
          })

        {:error, error}
    end
  end

  @impl true
  @spec retry_run(RequestContext.t(), RunRef.t(), keyword()) ::
          {:ok, ActionResult.t()} | {:error, SurfaceError.t()}
  def retry_run(%RequestContext{} = context, %RunRef{} = run_ref, opts) when is_list(opts) do
    ActionResult.new(%{
      status: :accepted,
      action_ref: %{id: "#{run_ref.run_id}:retry", action_kind: "retry"},
      message: retry_message(context, opts),
      metadata: %{opts: Enum.into(opts, %{})}
    })
  end

  @impl true
  @spec cancel_run(RequestContext.t(), RunRef.t(), keyword()) ::
          {:ok, ActionResult.t()} | {:error, SurfaceError.t()}
  def cancel_run(%RequestContext{} = context, %RunRef{} = run_ref, opts) when is_list(opts) do
    ActionResult.new(%{
      status: :completed,
      action_ref: %{id: "#{run_ref.run_id}:cancel", action_kind: "cancel"},
      message: cancel_message(context, opts),
      metadata: %{opts: Enum.into(opts, %{})}
    })
  end

  defp typed_run_ref(%RequestContext{} = context, %RunRequest{} = run_request, opts) do
    RunRef.new(%{
      run_id: Keyword.get(opts, :run_id, "run/#{run_request.subject_ref.id}"),
      scope_id: Keyword.get(opts, :scope_id, "tenant/#{context.tenant_ref.id}"),
      metadata: %{
        tenant_id: context.tenant_ref.id,
        work_object_id: run_request.subject_ref.id,
        recipe_ref: run_request.recipe_ref,
        trace_id: context.trace_id
      }
    })
  end

  defp typed_run_state(%RunRequest{} = run_request, opts) do
    if Keyword.get(opts, :review_required, false) or
         Map.get(run_request.metadata, :review_required) do
      :waiting_review
    else
      :scheduled
    end
  end

  defp retry_message(%RequestContext{} = context, opts) do
    Keyword.get(opts, :message) || "Retry queued for #{context.trace_id}"
  end

  defp cancel_message(%RequestContext{} = _context, opts) do
    Keyword.get(opts, :message) || "Cancelled"
  end
end
