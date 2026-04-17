defmodule Mezzanine.AppKitBridge.WorkQueryService do
  @moduledoc """
  Backend-oriented governed-work reads for the transitional AppKit bridge.
  """

  alias Mezzanine.WorkQueries

  defdelegate ingest_subject(attrs, opts \\ []), to: WorkQueries
  defdelegate list_subjects(tenant_id, program_id, filters \\ %{}), to: WorkQueries
  defdelegate get_subject_detail(tenant_id, subject_id), to: WorkQueries
  defdelegate get_subject_projection(tenant_id, subject_id), to: WorkQueries
  defdelegate queue_stats(tenant_id, program_id), to: WorkQueries
end
