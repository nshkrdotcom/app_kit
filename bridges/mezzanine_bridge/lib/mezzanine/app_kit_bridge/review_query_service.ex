defmodule Mezzanine.AppKitBridge.ReviewQueryService do
  @moduledoc """
  Backend-oriented review listings and detail projections for AppKit consumers.
  """

  alias Mezzanine.AppKitBridge.AdapterSupport
  alias Mezzanine.Reviews

  @spec list_pending_reviews(String.t(), Ecto.UUID.t()) :: {:ok, [map()]} | {:error, term()}
  def list_pending_reviews(tenant_id, program_id)
      when is_binary(tenant_id) and is_binary(program_id) do
    case Reviews.pending_review_summaries(tenant_id, program_id) do
      {:ok, summaries} -> {:ok, summaries}
      {:error, reason} -> {:error, AdapterSupport.normalize_error(reason)}
    end
  end

  @spec get_review_detail(String.t(), Ecto.UUID.t()) :: {:ok, map()} | {:error, term()}
  def get_review_detail(tenant_id, review_unit_id)
      when is_binary(tenant_id) and is_binary(review_unit_id) do
    case Reviews.review_detail_projection(tenant_id, review_unit_id) do
      {:ok, detail} -> {:ok, detail}
      {:error, reason} -> {:error, AdapterSupport.normalize_error(reason)}
    end
  end
end
