defmodule AppKit.EvolutionSurface.Backend.Boundary do
  @moduledoc "Boundary-backed Chassis Evolution surface."

  @behaviour AppKit.EvolutionSurface.Backend

  alias AppKit.Core.Evolution.DTO.{
    CandidateSummary,
    EvolutionBatchPage,
    EvolutionBatchSummary,
    EvolutionStatus,
    OperatorConsentResult,
    PromotionRequestResult,
    SwapStatus,
    TrialSummary
  }

  alias AppKit.Core.Evolution.SurfaceError
  alias AppKit.Core.RequestContext
  alias Chassis.Boundary

  @protocol_ref "boundary:appkit.chassis.evolution_surface:v1"

  @impl true
  def list_evolution_batches(context, request, opts) do
    dispatch(context, :list_evolution_batches, request, opts, &EvolutionBatchPage.new/1)
  end

  @impl true
  def get_evolution_batch(context, batch_ref, opts) do
    dispatch(
      context,
      :get_evolution_batch,
      %{batch_ref: batch_ref},
      opts,
      &EvolutionBatchSummary.new/1
    )
  end

  @impl true
  def get_evolution_status(context, evolution_ref, opts) do
    dispatch(
      context,
      :get_evolution_status,
      %{evolution_ref: evolution_ref},
      opts,
      &EvolutionStatus.new/1
    )
  end

  @impl true
  def get_candidate_summary(context, candidate_ref, opts) do
    dispatch(
      context,
      :get_candidate_summary,
      %{candidate_ref: candidate_ref},
      opts,
      &CandidateSummary.new/1
    )
  end

  @impl true
  def get_trial_summary(context, trial_ref, opts) do
    dispatch(context, :get_trial_summary, %{trial_ref: trial_ref}, opts, &TrialSummary.new/1)
  end

  @impl true
  def request_candidate_promotion(context, candidate_ref, request, opts) do
    payload = Map.put(request, :candidate_ref, candidate_ref)
    dispatch(context, :request_candidate_promotion, payload, opts, &PromotionRequestResult.new/1)
  end

  @impl true
  def record_operator_consent(context, candidate_ref, decision, opts) do
    payload = Map.put(decision, :candidate_ref, candidate_ref)
    dispatch(context, :record_operator_consent, payload, opts, &OperatorConsentResult.new/1)
  end

  @impl true
  def get_swap_status(context, swap_ref, opts) do
    dispatch(context, :get_swap_status, %{swap_ref: swap_ref}, opts, &SwapStatus.new/1)
  end

  defp dispatch(%RequestContext{} = context, operation, request, opts, decoder) do
    dispatcher = Keyword.get(opts, :boundary_dispatcher)

    if is_nil(dispatcher) do
      boundary_error(:boundary_unavailable, "Boundary dispatcher is required", %{
        operation: operation
      })
    else
      envelope = envelope(context, operation, request, opts)

      case dispatcher.dispatch(envelope, dispatch_opts(opts)) do
        {:ok, %Boundary.Envelope{status: status, payload: payload}}
        when status in [:ok, :accepted] ->
          payload
          |> result_payload()
          |> decoder.()

        {:ok, %Boundary.Envelope{status: status, payload: payload}} ->
          boundary_error(:boundary_rejected, "Boundary evolution request was not accepted", %{
            status: status,
            payload: payload
          })

        {:error, %Boundary.Error{} = error} ->
          boundary_error(error.code, error.safe_message, %{
            error_ref: error.error_ref,
            retry_posture: error.retry_posture
          })

        {:error, reason} ->
          boundary_error(:boundary_failed, "Boundary evolution request failed", %{reason: reason})
      end
    end
  end

  defp envelope(%RequestContext{} = context, operation, request, opts) do
    Boundary.Envelope.new!(%{
      protocol_ref: @protocol_ref,
      envelope_ref:
        Keyword.get(opts, :envelope_ref, "env:appkit.evolution:#{operation}:#{unique()}"),
      tenant_ref: context.tenant_ref.id,
      installation_ref: installation_id(context),
      actor_ref: context.actor_ref.id,
      idempotency_key: Keyword.get(opts, :idempotency_key),
      trace_id: context.trace_id,
      payload: %{
        operation: Atom.to_string(operation),
        request: request,
        lower_read_lease_ref: Keyword.get(opts, :lower_read_lease_ref)
      }
    })
  end

  defp dispatch_opts(opts) do
    opts
    |> Keyword.take([:target_node, :test_pid])
    |> Keyword.put_new(:target_node, Keyword.get(opts, :chassis_node, :local))
  end

  defp result_payload(%{result: result}), do: result
  defp result_payload(%{"result" => result}), do: result
  defp result_payload(result), do: result

  defp installation_id(%RequestContext{installation_ref: nil}), do: nil

  defp installation_id(%RequestContext{installation_ref: installation_ref}),
    do: installation_ref.id

  defp boundary_error(code, message, detail) do
    {:error,
     SurfaceError.new!(%{
       code: code,
       message: message,
       detail: detail
     })}
  end

  defp unique, do: System.unique_integer([:positive]) |> Integer.to_string()
end
