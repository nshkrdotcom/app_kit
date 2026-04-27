defmodule Mezzanine.AppKitBridge.WorkQueryService do
  @moduledoc """
  Backend-oriented governed-work reads for the transitional AppKit bridge.
  """

  alias Mezzanine.Archival.Query, as: ArchivalQuery
  alias Mezzanine.WorkQueries

  @runtime_projection_name "operator_subject_runtime"

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

  @spec get_subject_projection(String.t(), Ecto.UUID.t(), keyword()) ::
          {:ok, map()} | {:error, term()} | {:error, :archived, String.t()}
  def get_subject_projection(installation_id, subject_id, opts \\ [])
      when is_binary(installation_id) and is_binary(subject_id) and is_list(opts) do
    case archived_subject_manifest(installation_id, subject_id) do
      {:ok, manifest_ref} ->
        {:error, :archived, manifest_ref}

      :not_archived ->
        case runtime_subject_projection(installation_id, subject_id, opts) do
          {:ok, projection} ->
            {:ok, projection}

          :not_found ->
            runtime_projection_not_found_or_fallback(installation_id, subject_id, opts)

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  defp runtime_projection_not_found_or_fallback(installation_id, subject_id, opts) do
    if Keyword.get(opts, :runtime_projection?) do
      {:error, :runtime_projection_not_found}
    else
      WorkQueries.get_subject_projection(installation_id, subject_id)
    end
  end

  defp runtime_subject_projection(installation_id, subject_id, opts) do
    fetcher = Keyword.get(opts, :projection_row_fetcher, &default_runtime_projection_fetch/3)
    fetch_opts = Keyword.put_new(opts, :projection_name, @runtime_projection_name)

    case fetcher.(installation_id, subject_id, fetch_opts) do
      {:ok, nil} -> :not_found
      {:ok, row} -> runtime_projection_from_row(row, subject_id)
      :not_found -> :not_found
      {:error, reason} -> if not_found?(reason), do: :not_found, else: {:error, reason}
    end
  rescue
    UndefinedFunctionError -> :not_found
  end

  defp default_runtime_projection_fetch(installation_id, subject_id, _opts) do
    projection_row = Module.concat([Mezzanine, Projections, ProjectionRow])

    if Code.ensure_loaded?(projection_row) and
         function_exported?(projection_row, :row_by_key, 3) do
      projection_row.row_by_key(
        installation_id,
        @runtime_projection_name,
        subject_id
      )
    else
      :not_found
    end
  end

  defp runtime_projection_from_row(row, subject_id) do
    payload = fetch_value(row, :payload) || %{}
    subject_payload = map_value(payload, :subject) || %{}
    lifecycle_state = map_value(subject_payload, :lifecycle_state)

    with :ok <- require_runtime_row(row, payload) do
      projection =
        row
        |> base_runtime_projection(payload, subject_payload, subject_id, lifecycle_state)
        |> Map.merge(runtime_payload_projection(payload))

      {:ok, projection}
    end
  end

  defp base_runtime_projection(row, payload, subject_payload, subject_id, lifecycle_state) do
    %{
      subject_id: runtime_subject_id(row, subject_payload, subject_id),
      subject_kind: map_value(subject_payload, :subject_kind) || "subject",
      lifecycle_state: lifecycle_state,
      work_status: lifecycle_status(lifecycle_state),
      review_status: review_status(payload),
      projection_name: fetch_value(row, :projection_name) || @runtime_projection_name,
      projection_version: fetch_value(row, :projection_version) || 1,
      projection_kind: fetch_value(row, :projection_kind),
      computed_at: fetch_value(row, :computed_at)
    }
  end

  defp runtime_payload_projection(payload) do
    %{
      execution: map_value(payload, :execution) || %{},
      lower_receipt: map_value(payload, :lower_receipt) || %{},
      runtime: map_value(payload, :runtime) || %{},
      evidence: map_value(payload, :evidence) || %{},
      review: map_value(payload, :review) || %{},
      source_binding: map_value(payload, :source_binding) || map_value(payload, :source),
      source_bindings: map_value(payload, :source_bindings) || []
    }
  end

  defp require_runtime_row(row, payload) do
    cond do
      fetch_value(row, :projection_name) != @runtime_projection_name ->
        {:error, :runtime_projection_not_found}

      is_nil(fetch_value(row, :computed_at)) and is_nil(fetch_value(row, :updated_at)) ->
        {:error, :runtime_projection_missing_provenance}

      not is_map(map_value(payload, :execution)) ->
        {:error, :runtime_projection_missing_execution}

      not is_map(map_value(payload, :lower_receipt)) ->
        {:error, :runtime_projection_missing_lower_receipt}

      not source_binding_present?(payload) ->
        {:error, :runtime_projection_missing_source_binding}

      true ->
        :ok
    end
  end

  defp source_binding_present?(payload) do
    is_map(map_value(payload, :source_binding)) or
      match?([_ | _], map_value(payload, :source_bindings))
  end

  defp runtime_subject_id(row, subject_payload, subject_id) do
    map_value(subject_payload, :subject_id) || fetch_value(row, :subject_id) || subject_id
  end

  defp lifecycle_status(nil), do: :unknown
  defp lifecycle_status(value) when is_atom(value), do: value

  defp lifecycle_status(value) when is_binary(value) do
    value
    |> String.downcase()
    |> String.replace("-", "_")
    |> String.to_existing_atom()
  rescue
    ArgumentError -> :unknown
  end

  defp review_status(payload) do
    payload
    |> map_value(:review)
    |> case do
      %{} = review ->
        case map_value(review, :pending_decision_ids) do
          ids when is_list(ids) and ids != [] -> :pending
          _other -> :none
        end

      _other ->
        :none
    end
  end

  defp archived_subject_manifest(installation_id, subject_id) do
    case ArchivalQuery.archived_subject_manifest(installation_id, subject_id) do
      {:ok, manifest} -> {:ok, manifest.manifest_ref}
      {:error, :not_found} -> :not_archived
      {:error, _reason} -> :not_archived
    end
  end

  defp not_found?(reason) do
    reason
    |> inspect()
    |> String.contains?("NotFound")
  end

  defp fetch_value(row, key) when is_map(row) do
    case Map.fetch(row, key) do
      {:ok, value} -> value
      :error -> Map.get(row, Atom.to_string(key))
    end
  end

  defp map_value(nil, _key), do: nil

  defp map_value(%{} = map, key) do
    case Map.fetch(map, key) do
      {:ok, value} -> value
      :error -> Map.get(map, Atom.to_string(key))
    end
  end

  defp map_value(_value, _key), do: nil
end
