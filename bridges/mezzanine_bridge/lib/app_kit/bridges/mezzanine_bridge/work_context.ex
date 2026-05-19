defmodule AppKit.Bridges.MezzanineBridge.WorkContext do
  @moduledoc false

  alias AppKit.Bridges.MezzanineBridge.{Common, Services}

  alias AppKit.Core.{
    FilterSet,
    InstallationRef,
    ProjectionRef,
    RequestContext,
    RunRef,
    RunRequest,
    SubjectRef
  }

  alias Mezzanine.Archival.Query, as: ArchivalQuery

  def tenant_id(%RequestContext{tenant_ref: %{id: tenant_id}}) when is_binary(tenant_id),
    do: {:ok, tenant_id}

  def tenant_id(_context), do: {:error, :missing_tenant_id}

  def ensure_subject_not_archived(%RequestContext{} = context, %SubjectRef{} = subject_ref) do
    case archival_installation_id(context, subject_ref) do
      {:ok, installation_id} ->
        case ArchivalQuery.archived_subject_manifest(installation_id, subject_ref.id) do
          {:ok, manifest} -> {:error, :archived, manifest.manifest_ref}
          {:error, :not_found} -> :ok
          {:error, _reason} -> :ok
        end

      :error ->
        :ok
    end
  end

  def program_id(%RequestContext{} = context, opts) do
    case explicit_program_id(context, opts) do
      {:ok, program_id} ->
        {:ok, program_id}

      :missing ->
        with {:ok, tenant_id} <- tenant_id(context),
             {:ok, program_slug} <- program_slug(context, opts),
             {:ok, resolution} <-
               Services.program_context(opts).resolve(
                 tenant_id,
                 %{program_slug: program_slug},
                 opts
               ),
             {:ok, program_id} <- resolved_id(resolution, :program_id, :missing_program_id) do
          {:ok, program_id}
        else
          {:error, :missing_program_slug} -> {:error, :missing_program_id}
          {:error, reason} -> {:error, reason}
        end
    end
  end

  def work_class_id(%RequestContext{} = context, attrs, opts) do
    case explicit_work_class_id(context, attrs, opts) do
      {:ok, work_class_id} ->
        {:ok, work_class_id}

      :missing ->
        with {:ok, tenant_id} <- tenant_id(context),
             {:ok, program_slug} <- program_slug(context, opts),
             {:ok, work_class_name} <- work_class_name(context, attrs, opts),
             {:ok, resolution} <-
               Services.program_context(opts).resolve(
                 tenant_id,
                 %{program_slug: program_slug, work_class_name: work_class_name},
                 opts
               ),
             {:ok, work_class_id} <-
               resolved_id(resolution, :work_class_id, :missing_work_class_id) do
          {:ok, work_class_id}
        else
          {:error, :missing_program_slug} -> {:error, :missing_work_class_id}
          {:error, :missing_work_class_name} -> {:error, :missing_work_class_id}
          {:error, reason} -> {:error, reason}
        end
    end
  end

  def subject_id_from_projection(%ProjectionRef{subject_ref: %SubjectRef{id: subject_id}})
      when is_binary(subject_id),
      do: {:ok, subject_id}

  def subject_id_from_projection(_projection_ref), do: {:error, :missing_subject_id}

  def work_filters(nil), do: %{}

  def work_filters(%FilterSet{clauses: clauses}) do
    Enum.reduce(clauses, %{}, fn clause, acc ->
      field = Common.fetch_value(clause, :field)
      op = Common.fetch_value(clause, :op)
      value = Common.fetch_value(clause, :value)

      case {field, op, value} do
        {"status", "eq", filter_value} ->
          Map.put(acc, :statuses, [Common.normalize_atomish(filter_value)])

        {"status", "in", filter_value} when is_list(filter_value) ->
          Map.put(acc, :statuses, Enum.map(filter_value, &Common.normalize_atomish/1))

        {"lifecycle_state", "eq", filter_value} ->
          Map.put(acc, :statuses, [Common.normalize_atomish(filter_value)])

        {"source_kind", "eq", filter_value} when is_binary(filter_value) ->
          Map.put(acc, :source_kind, filter_value)

        {"work_class_id", "eq", filter_value} when is_binary(filter_value) ->
          Map.put(acc, :work_class_id, filter_value)

        _ ->
          acc
      end
    end)
  end

  def scope_id(%RequestContext{} = context, opts, subject_id) do
    case Keyword.get(opts, :scope_id) || context_metadata(context, :scope_id) do
      value when is_binary(value) and value != "" ->
        value

      _ ->
        case program_id(context, opts) do
          {:ok, value} -> "program/#{value}"
          {:error, _reason} -> "subject/#{subject_id}"
        end
    end
  end

  def subject_ref_from_run_ref(%RunRef{metadata: metadata}) when is_map(metadata) do
    case Map.get(metadata, :work_object_id) || Map.get(metadata, "work_object_id") ||
           Map.get(metadata, :subject_id) || Map.get(metadata, "subject_id") do
      value when is_binary(value) ->
        SubjectRef.new(%{id: value, subject_kind: "work_object"})

      _ ->
        {:error, :missing_subject_id}
    end
  end

  def subject_ref_from_run_ref(_run_ref), do: {:error, :missing_subject_id}

  def actor_payload(%RequestContext{actor_ref: %{id: actor_id}}) when is_binary(actor_id),
    do: %{actor_ref: actor_id}

  def actor_payload(_context), do: %{actor_ref: "app_kit"}

  def run_request_action_params(%RunRequest{} = run_request) do
    run_request.params
    |> Map.new()
    |> Common.maybe_put("recipe_ref", run_request.recipe_ref)
    |> Common.maybe_put("reason", run_request.reason)
  end

  def context_metadata(%RequestContext{metadata: metadata}, key) do
    Map.get(metadata, key) || Map.get(metadata, Atom.to_string(key))
  end

  defp archival_installation_id(
         _context,
         %SubjectRef{installation_ref: %InstallationRef{id: installation_id}}
       )
       when is_binary(installation_id),
       do: {:ok, installation_id}

  defp archival_installation_id(
         %RequestContext{installation_ref: %InstallationRef{id: installation_id}},
         _subject_ref
       )
       when is_binary(installation_id),
       do: {:ok, installation_id}

  defp archival_installation_id(_context, _subject_ref), do: :error

  defp explicit_program_id(%RequestContext{} = context, opts) do
    case Keyword.get(opts, :program_id) || context_metadata(context, :program_id) do
      value when is_binary(value) and value != "" -> {:ok, value}
      _ -> :missing
    end
  end

  defp explicit_work_class_id(%RequestContext{} = context, attrs, opts) do
    case Keyword.get(opts, :work_class_id) || Common.fetch_value(attrs, :work_class_id) ||
           context_metadata(context, :work_class_id) do
      value when is_binary(value) and value != "" -> {:ok, value}
      _ -> :missing
    end
  end

  defp program_slug(%RequestContext{} = context, opts) do
    case Keyword.get(opts, :program_slug) || context_metadata(context, :program_slug) do
      value when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, :missing_program_slug}
    end
  end

  defp work_class_name(%RequestContext{} = context, attrs, opts) do
    case Keyword.get(opts, :work_class_name) || Common.fetch_value(attrs, :work_class_name) ||
           context_metadata(context, :work_class_name) do
      value when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, :missing_work_class_name}
    end
  end

  defp resolved_id(resolution, key, error) when is_map(resolution) do
    case Common.fetch_value(resolution, key) do
      value when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, error}
    end
  end
end
