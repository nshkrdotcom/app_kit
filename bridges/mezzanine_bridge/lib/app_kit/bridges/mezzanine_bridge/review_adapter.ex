defmodule AppKit.Bridges.MezzanineBridge.ReviewAdapter do
  @moduledoc """
  Review backend adapter for the Mezzanine bridge.
  """

  @behaviour AppKit.Core.Backends.ReviewBackend

  alias AppKit.Bridges.MezzanineBridge.{
    ActionMapping,
    Common,
    Errors,
    ReviewMapping,
    Services,
    WorkContext
  }

  alias AppKit.Core.{DecisionRef, PageRequest, RequestContext}

  @impl true
  def list_pending(%RequestContext{} = context, %PageRequest{} = page_request, opts)
      when is_list(opts) do
    with {:ok, tenant_id} <- WorkContext.tenant_id(context),
         {:ok, program_id} <- WorkContext.program_id(context, opts),
         {:ok, rows} <- Services.review_query(opts).list_pending_reviews(tenant_id, program_id),
         {:ok, entries} <-
           Common.map_each(rows, &ReviewMapping.decision_summary_from_row(&1, context)),
         {:ok, page_result} <- Common.page_result(entries, page_request) do
      {:ok, page_result}
    else
      {:error, reason} -> Errors.normalize(reason)
    end
  end

  @impl true
  def get_review(%RequestContext{} = context, %DecisionRef{} = decision_ref, opts)
      when is_list(opts) do
    with {:ok, tenant_id} <- WorkContext.tenant_id(context),
         {:ok, review_detail} <-
           Services.review_query(opts).get_review_detail(tenant_id, decision_ref.id) do
      {:ok, review_detail}
    else
      {:error, reason} -> Errors.normalize(reason)
    end
  end

  @impl true
  def record_decision(%RequestContext{} = context, %DecisionRef{} = decision_ref, attrs, opts)
      when is_map(attrs) and is_list(opts) do
    record_decision_by_id(context, decision_ref.id, attrs, opts)
  end

  @impl true
  def record_decision_by_id(%RequestContext{} = context, decision_id, attrs, opts)
      when is_binary(decision_id) and is_map(attrs) and is_list(opts) do
    with {:ok, tenant_id} <- WorkContext.tenant_id(context),
         {:ok, program_id} <- WorkContext.program_id(context, opts),
         {:ok, bridge_result} <-
           Services.review_action(opts).record_decision(
             tenant_id,
             decision_id,
             decision_attrs(attrs, context, program_id),
             opts
           ),
         {:ok, action_result} <- ActionMapping.action_result_from_bridge(bridge_result) do
      {:ok, action_result}
    else
      {:error, reason} -> Errors.normalize(reason)
    end
  end

  defp decision_attrs(attrs, %RequestContext{} = context, program_id) do
    attrs
    |> Map.new()
    |> Map.put_new(:program_id, program_id)
    |> Map.put_new(:actor_ref, context.actor_ref.id)
  end
end
