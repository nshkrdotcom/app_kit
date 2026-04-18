defmodule Mezzanine.AppKitBridge.WorkQueryService do
  @moduledoc """
  Backend-oriented governed-work reads for the transitional AppKit bridge.
  """

  alias Mezzanine.Archival.Query, as: ArchivalQuery
  alias Mezzanine.WorkQueries

  defdelegate ingest_subject(attrs, opts \\ []), to: WorkQueries
  defdelegate list_subjects(tenant_id, program_id, filters \\ %{}), to: WorkQueries
  defdelegate queue_stats(tenant_id, program_id), to: WorkQueries

  @spec get_subject_detail(String.t(), Ecto.UUID.t()) ::
          {:ok, map()} | {:error, term()} | {:error, :archived, String.t()}
  def get_subject_detail(installation_id, subject_id)
      when is_binary(installation_id) and is_binary(subject_id) do
    case archived_subject_manifest(installation_id, subject_id) do
      {:ok, manifest_ref} ->
        {:error, :archived, manifest_ref}

      :not_archived ->
        WorkQueries.get_subject_detail(installation_id, subject_id)
    end
  end

  @spec get_subject_projection(String.t(), Ecto.UUID.t()) ::
          {:ok, map()} | {:error, term()} | {:error, :archived, String.t()}
  def get_subject_projection(installation_id, subject_id)
      when is_binary(installation_id) and is_binary(subject_id) do
    case archived_subject_manifest(installation_id, subject_id) do
      {:ok, manifest_ref} ->
        {:error, :archived, manifest_ref}

      :not_archived ->
        WorkQueries.get_subject_projection(installation_id, subject_id)
    end
  end

  defp archived_subject_manifest(installation_id, subject_id) do
    case ArchivalQuery.archived_subject_manifest(installation_id, subject_id) do
      {:ok, manifest} -> {:ok, manifest.manifest_ref}
      {:error, :not_found} -> :not_archived
      {:error, _reason} -> :not_archived
    end
  end
end
