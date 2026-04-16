defmodule AppKit.Bridges.MezzanineBridge do
  @moduledoc """
  Internal AppKit backend adapter over the `mezzanine_app_kit_bridge` seam.

  The bridge owns translation from lower service-shaped maps into the stable
  `AppKit.Core.*` contract so product-facing surfaces do not inherit lower
  structs or lower package topology.
  """

  @behaviour AppKit.Core.Backends.InstallationBackend
  @behaviour AppKit.Core.Backends.OperatorBackend
  @behaviour AppKit.Core.Backends.ReviewBackend
  @behaviour AppKit.Core.Backends.WorkBackend
  @behaviour AppKit.Core.Backends.WorkQueryBackend

  alias AppKit.Core.{
    ActionResult,
    DecisionRef,
    DecisionSummary,
    ExecutionRef,
    FilterSet,
    InstallationBinding,
    InstallationRef,
    InstallResult,
    InstallTemplate,
    OperatorActionRef,
    PageRequest,
    PageResult,
    ProjectionRef,
    RequestContext,
    SubjectDetail,
    SubjectRef,
    SubjectSummary,
    SurfaceError
  }

  @impl true
  def ingest_subject(%RequestContext{} = context, attrs, opts)
      when is_map(attrs) and is_list(opts) do
    with {:ok, tenant_id} <- tenant_id(context),
         {:ok, program_id} <- program_id(context, opts),
         {:ok, work_class_id} <- work_class_id(context, attrs, opts),
         merged_attrs <-
           attrs
           |> Map.new()
           |> Map.put_new(:tenant_id, tenant_id)
           |> Map.put_new(:program_id, program_id)
           |> Map.put_new(:work_class_id, work_class_id),
         {:ok, subject} <- work_query_service(opts).ingest_subject(merged_attrs, opts),
         {:ok, subject_ref} <- subject_ref_from_summary(subject, context) do
      {:ok, subject_ref}
    else
      {:error, reason} -> normalize_surface_error(reason)
    end
  end

  @impl true
  def list_subjects(%RequestContext{} = context, filters, %PageRequest{} = page_request, opts)
      when (is_nil(filters) or is_struct(filters, FilterSet)) and is_list(opts) do
    with {:ok, tenant_id} <- tenant_id(context),
         {:ok, program_id} <- program_id(context, opts),
         {:ok, rows} <-
           work_query_service(opts).list_subjects(
             tenant_id,
             program_id,
             work_filters(filters || page_request.filters)
           ),
         {:ok, entries} <- map_each(rows, &subject_summary_from_row(&1, context)),
         {:ok, page_result} <- page_result(entries, page_request) do
      {:ok, page_result}
    else
      {:error, reason} -> normalize_surface_error(reason)
    end
  end

  @impl true
  def get_subject(%RequestContext{} = context, %SubjectRef{} = subject_ref, opts)
      when is_list(opts) do
    with {:ok, tenant_id} <- tenant_id(context),
         {:ok, row} <- work_query_service(opts).get_subject_detail(tenant_id, subject_ref.id),
         {:ok, detail} <- subject_detail_from_row(row, context) do
      {:ok, detail}
    else
      {:error, reason} -> normalize_surface_error(reason)
    end
  end

  @impl true
  def get_projection(%RequestContext{} = context, %ProjectionRef{} = projection_ref, opts)
      when is_list(opts) do
    with {:ok, tenant_id} <- tenant_id(context),
         {:ok, subject_id} <- subject_id_from_projection(projection_ref),
         {:ok, projection} <-
           work_query_service(opts).get_subject_projection(tenant_id, subject_id) do
      {:ok, projection}
    else
      {:error, reason} -> normalize_surface_error(reason)
    end
  end

  @impl true
  def queue_stats(%RequestContext{} = context, filters, opts)
      when (is_nil(filters) or is_struct(filters, FilterSet)) and is_list(opts) do
    with {:ok, tenant_id} <- tenant_id(context),
         {:ok, program_id} <- program_id(context, opts),
         {:ok, stats} <- work_query_service(opts).queue_stats(tenant_id, program_id) do
      {:ok, Map.merge(stats, %{filters: work_filters(filters)})}
    else
      {:error, reason} -> normalize_surface_error(reason)
    end
  end

  @impl true
  def list_pending(%RequestContext{} = context, %PageRequest{} = page_request, opts)
      when is_list(opts) do
    with {:ok, tenant_id} <- tenant_id(context),
         {:ok, program_id} <- program_id(context, opts),
         {:ok, rows} <- review_query_service(opts).list_pending_reviews(tenant_id, program_id),
         {:ok, entries} <- map_each(rows, &decision_summary_from_row(&1, context)),
         {:ok, page_result} <- page_result(entries, page_request) do
      {:ok, page_result}
    else
      {:error, reason} -> normalize_surface_error(reason)
    end
  end

  @impl true
  def get_review(%RequestContext{} = context, %DecisionRef{} = decision_ref, opts)
      when is_list(opts) do
    with {:ok, tenant_id} <- tenant_id(context),
         {:ok, review_detail} <-
           review_query_service(opts).get_review_detail(tenant_id, decision_ref.id) do
      {:ok, review_detail}
    else
      {:error, reason} -> normalize_surface_error(reason)
    end
  end

  @impl true
  def record_decision(%RequestContext{} = context, %DecisionRef{} = decision_ref, attrs, opts)
      when is_map(attrs) and is_list(opts) do
    with {:ok, tenant_id} <- tenant_id(context),
         {:ok, program_id} <- program_id(context, opts),
         merged_attrs <-
           attrs
           |> Map.new()
           |> Map.put_new(:program_id, program_id)
           |> Map.put_new(:actor_ref, context.actor_ref.id),
         {:ok, bridge_result} <-
           review_action_service(opts).record_decision(
             tenant_id,
             decision_ref.id,
             merged_attrs,
             opts
           ),
         {:ok, action_result} <- action_result_from_bridge(bridge_result) do
      {:ok, action_result}
    else
      {:error, reason} -> normalize_surface_error(reason)
    end
  end

  @impl true
  def create_installation(%RequestContext{} = context, %InstallTemplate{} = template, opts)
      when is_list(opts) do
    with {:ok, tenant_id} <- tenant_id(context),
         attrs <-
           template
           |> Map.from_struct()
           |> Map.put(:tenant_id, tenant_id)
           |> Map.put_new(:metadata, %{}),
         {:ok, bridge_result} <- installation_service(opts).create_installation(attrs, opts),
         {:ok, install_result} <- install_result_from_bridge(bridge_result) do
      {:ok, install_result}
    else
      {:error, reason} -> normalize_surface_error(reason)
    end
  end

  @impl true
  def get_installation(%RequestContext{} = _context, %InstallationRef{} = installation_ref, opts)
      when is_list(opts) do
    with {:ok, detail} <- installation_service(opts).get_installation(installation_ref.id, opts),
         {:ok, normalized_ref} <- installation_ref_from_detail(detail) do
      {:ok, normalized_ref}
    else
      {:error, reason} -> normalize_surface_error(reason)
    end
  end

  @impl true
  def update_bindings(
        %RequestContext{} = _context,
        %InstallationRef{} = installation_ref,
        bindings,
        opts
      )
      when is_list(bindings) and is_list(opts) do
    with {:ok, bridge_result} <-
           installation_service(opts).update_bindings(
             installation_ref.id,
             binding_config(bindings),
             opts
           ),
         {:ok, action_result} <- action_result_from_bridge(bridge_result) do
      {:ok, action_result}
    else
      {:error, reason} -> normalize_surface_error(reason)
    end
  end

  @impl true
  def list_installations(%RequestContext{} = context, %PageRequest{} = page_request, opts)
      when is_list(opts) do
    with {:ok, tenant_id} <- tenant_id(context),
         {:ok, rows} <-
           installation_service(opts).list_installations(
             tenant_id,
             installation_filters(page_request.filters),
             opts
           ),
         {:ok, entries} <- map_each(rows, &installation_ref_from_detail/1),
         {:ok, page_result} <- page_result(entries, page_request) do
      {:ok, page_result}
    else
      {:error, reason} -> normalize_surface_error(reason)
    end
  end

  @impl true
  def suspend_installation(
        %RequestContext{} = _context,
        %InstallationRef{} = installation_ref,
        opts
      )
      when is_list(opts) do
    with {:ok, bridge_result} <-
           installation_service(opts).suspend_installation(installation_ref.id, opts),
         {:ok, action_result} <- action_result_from_bridge(bridge_result) do
      {:ok, action_result}
    else
      {:error, reason} -> normalize_surface_error(reason)
    end
  end

  @impl true
  def reactivate_installation(
        %RequestContext{} = _context,
        %InstallationRef{} = installation_ref,
        opts
      )
      when is_list(opts) do
    with {:ok, bridge_result} <-
           installation_service(opts).reactivate_installation(installation_ref.id, opts),
         {:ok, action_result} <- action_result_from_bridge(bridge_result) do
      {:ok, action_result}
    else
      {:error, reason} -> normalize_surface_error(reason)
    end
  end

  @impl true
  def start_run(domain_call, opts) when is_map(domain_call) and is_list(opts) do
    work_control_service(opts).start_run(domain_call, opts)
  end

  @impl true
  def run_status(run_ref, attrs, opts) when is_map(attrs) and is_list(opts) do
    operator_query_service(opts).run_status(run_ref, attrs, opts)
  end

  @impl true
  def review_run(run_ref, evidence_attrs, opts) when is_map(evidence_attrs) and is_list(opts) do
    operator_action_service(opts).review_run(run_ref, evidence_attrs, opts)
  end

  defp work_query_service(opts),
    do: Keyword.get(opts, :work_query_service, Mezzanine.AppKitBridge.WorkQueryService)

  defp review_query_service(opts),
    do: Keyword.get(opts, :review_query_service, Mezzanine.AppKitBridge.ReviewQueryService)

  defp review_action_service(opts),
    do: Keyword.get(opts, :review_action_service, Mezzanine.AppKitBridge.ReviewActionService)

  defp installation_service(opts),
    do: Keyword.get(opts, :installation_service, Mezzanine.AppKitBridge.InstallationService)

  defp work_control_service(opts),
    do: Keyword.get(opts, :work_control_service, Mezzanine.AppKitBridge.WorkControlService)

  defp operator_query_service(opts),
    do: Keyword.get(opts, :operator_query_service, Mezzanine.AppKitBridge.OperatorQueryService)

  defp operator_action_service(opts),
    do: Keyword.get(opts, :operator_action_service, Mezzanine.AppKitBridge.OperatorActionService)

  defp tenant_id(%RequestContext{tenant_ref: %{id: tenant_id}}) when is_binary(tenant_id),
    do: {:ok, tenant_id}

  defp tenant_id(_context), do: {:error, :missing_tenant_id}

  defp program_id(%RequestContext{} = context, opts) do
    case Keyword.get(opts, :program_id) || context_metadata(context, :program_id) do
      value when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, :missing_program_id}
    end
  end

  defp work_class_id(%RequestContext{} = context, attrs, opts) do
    case Keyword.get(opts, :work_class_id) || fetch_value(attrs, :work_class_id) ||
           context_metadata(context, :work_class_id) do
      value when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, :missing_work_class_id}
    end
  end

  defp context_metadata(%RequestContext{metadata: metadata}, key) do
    Map.get(metadata, key) || Map.get(metadata, Atom.to_string(key))
  end

  defp subject_id_from_projection(%ProjectionRef{subject_ref: %SubjectRef{id: subject_id}})
       when is_binary(subject_id),
       do: {:ok, subject_id}

  defp subject_id_from_projection(_projection_ref), do: {:error, :missing_subject_id}

  defp work_filters(nil), do: %{}

  defp work_filters(%FilterSet{clauses: clauses}) do
    Enum.reduce(clauses, %{}, fn clause, acc ->
      field = fetch_value(clause, :field)
      op = fetch_value(clause, :op)
      value = fetch_value(clause, :value)

      case {field, op, value} do
        {"status", "eq", filter_value} ->
          Map.put(acc, :statuses, [normalize_atomish(filter_value)])

        {"status", "in", filter_value} when is_list(filter_value) ->
          Map.put(acc, :statuses, Enum.map(filter_value, &normalize_atomish/1))

        {"lifecycle_state", "eq", filter_value} ->
          Map.put(acc, :statuses, [normalize_atomish(filter_value)])

        {"source_kind", "eq", filter_value} when is_binary(filter_value) ->
          Map.put(acc, :source_kind, filter_value)

        {"work_class_id", "eq", filter_value} when is_binary(filter_value) ->
          Map.put(acc, :work_class_id, filter_value)

        _ ->
          acc
      end
    end)
  end

  defp installation_filters(nil), do: %{}

  defp installation_filters(%FilterSet{clauses: clauses}) do
    Enum.reduce(clauses, %{}, fn clause, acc ->
      field = fetch_value(clause, :field)
      op = fetch_value(clause, :op)
      value = fetch_value(clause, :value)

      case {field, op, value} do
        {"status", "eq", filter_value} ->
          Map.put(acc, :status, normalize_atomish(filter_value))

        {"environment", "eq", filter_value} when is_binary(filter_value) ->
          Map.put(acc, :environment, filter_value)

        {"pack_slug", "eq", filter_value} when is_binary(filter_value) ->
          Map.put(acc, :pack_slug, filter_value)

        _ ->
          acc
      end
    end)
  end

  defp binding_config(bindings) do
    Enum.reduce(bindings, %{}, fn %InstallationBinding{} = binding, acc ->
      kind_key = "#{binding.binding_kind}_bindings"

      config =
        binding.config
        |> Map.new()
        |> maybe_put("credential_ref", binding.credential_ref)

      Map.update(acc, kind_key, %{binding.binding_key => config}, fn grouped ->
        Map.put(grouped, binding.binding_key, config)
      end)
    end)
  end

  defp page_result(entries, %PageRequest{} = page_request) do
    sorted_entries = sort_entries(entries, page_request.sort)
    offset = decode_cursor(page_request.cursor)
    page_entries = Enum.slice(sorted_entries, offset, page_request.limit)
    has_more = offset + length(page_entries) < length(sorted_entries)
    next_cursor = if has_more, do: Integer.to_string(offset + length(page_entries)), else: nil

    PageResult.new(%{
      entries: page_entries,
      next_cursor: next_cursor,
      total_count: length(sorted_entries),
      has_more: has_more
    })
  end

  defp sort_entries(entries, []), do: entries

  defp sort_entries(entries, [sort_spec | _rest]) do
    sorter = fn entry ->
      value = fetch_value(entry, sort_spec.field)

      case {value, sort_spec.nulls || :last} do
        {nil, :first} -> {0, nil}
        {nil, :last} -> {1, nil}
        {other, _nulls} -> {1, other}
      end
    end

    direction = if sort_spec.direction == :desc, do: :desc, else: :asc
    Enum.sort_by(entries, sorter, direction)
  end

  defp decode_cursor(nil), do: 0

  defp decode_cursor(cursor) when is_binary(cursor) do
    case Integer.parse(cursor) do
      {offset, ""} when offset >= 0 -> offset
      _ -> 0
    end
  end

  defp map_each(entries, mapper) do
    Enum.reduce_while(entries, {:ok, []}, fn entry, {:ok, acc} ->
      case mapper.(entry) do
        {:ok, mapped} -> {:cont, {:ok, [mapped | acc]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, mapped} -> {:ok, Enum.reverse(mapped)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp subject_ref_from_summary(summary, %RequestContext{} = context) do
    SubjectRef.new(%{
      id: fetch_value(summary, :subject_id),
      subject_kind: normalize_string(fetch_value(summary, :subject_kind) || "subject"),
      installation_ref: context.installation_ref
    })
  end

  defp subject_summary_from_row(row, %RequestContext{} = context) do
    with {:ok, subject_ref} <- subject_ref_from_summary(row, context) do
      SubjectSummary.new(%{
        subject_ref: subject_ref,
        lifecycle_state: normalize_string(fetch_value(row, :status) || "unknown"),
        title: fetch_value(row, :title),
        summary: fetch_value(row, :description),
        opened_at: fetch_value(row, :inserted_at),
        updated_at: fetch_value(row, :updated_at),
        schema_ref: "mezzanine/work_object",
        schema_version: 1,
        payload:
          compact_map(%{
            program_id: fetch_value(row, :program_id),
            work_class_id: fetch_value(row, :work_class_id),
            external_ref: fetch_value(row, :external_ref),
            priority: fetch_value(row, :priority),
            source_kind: fetch_value(row, :source_kind),
            current_plan_id: fetch_value(row, :current_plan_id)
          })
      })
    end
  end

  defp subject_detail_from_row(row, %RequestContext{} = context) do
    with {:ok, subject_ref} <- subject_ref_from_summary(row, context),
         {:ok, current_execution_ref} <- execution_ref_from_row(row, subject_ref),
         {:ok, pending_decision_refs} <- pending_decision_refs_from_row(row, subject_ref) do
      SubjectDetail.new(%{
        subject_ref: subject_ref,
        lifecycle_state: normalize_string(fetch_value(row, :status) || "unknown"),
        title: fetch_value(row, :title),
        description: fetch_value(row, :description),
        current_execution_ref: current_execution_ref,
        pending_decision_refs: pending_decision_refs,
        available_actions: [],
        schema_ref: "mezzanine/work_object",
        schema_version: 1,
        payload:
          compact_map(%{
            program_id: fetch_value(row, :program_id),
            work_class_id: fetch_value(row, :work_class_id),
            external_ref: fetch_value(row, :external_ref),
            priority: fetch_value(row, :priority),
            source_kind: fetch_value(row, :source_kind),
            current_plan_id: fetch_value(row, :current_plan_id),
            current_plan_status: normalize_string(fetch_value(row, :current_plan_status)),
            active_run_status: normalize_string(fetch_value(row, :active_run_status)),
            gate_status: fetch_value(row, :gate_status),
            timeline: fetch_value(row, :timeline),
            audit_events: fetch_value(row, :audit_events),
            run_series_ids: fetch_value(row, :run_series_ids),
            obligation_ids: fetch_value(row, :obligation_ids),
            evidence_bundle_id: fetch_value(row, :evidence_bundle_id),
            control_session_id: fetch_value(row, :control_session_id),
            control_mode: normalize_string(fetch_value(row, :control_mode)),
            last_event_at: fetch_value(row, :last_event_at)
          })
      })
    end
  end

  defp execution_ref_from_row(row, %SubjectRef{} = subject_ref) do
    case fetch_value(row, :active_run_id) do
      run_id when is_binary(run_id) ->
        ExecutionRef.new(%{
          id: run_id,
          subject_ref: subject_ref,
          dispatch_state: normalize_string(fetch_value(row, :active_run_status))
        })

      _ ->
        {:ok, nil}
    end
  end

  defp pending_decision_refs_from_row(row, %SubjectRef{} = subject_ref) do
    pending_review_ids = fetch_value(row, :pending_review_ids) || []

    pending_review_ids
    |> Enum.map(fn review_id ->
      DecisionRef.new(%{
        id: review_id,
        decision_kind: "review",
        subject_ref: subject_ref
      })
    end)
    |> collect()
  end

  defp decision_summary_from_row(row, %RequestContext{} = context) do
    with {:ok, decision_ref} <- decision_ref_from_row(row, context) do
      DecisionSummary.new(%{
        decision_ref: decision_ref,
        status: normalize_string(fetch_value(row, :status) || "pending"),
        required_by: fetch_value(row, :required_by),
        subject_ref: decision_ref.subject_ref,
        summary: fetch_value(row, :summary),
        schema_ref: "mezzanine/review_unit",
        schema_version: 1,
        payload: fetch_value(row, :payload) || %{}
      })
    end
  end

  defp decision_ref_from_row(row, %RequestContext{} = context) do
    raw_ref = fetch_value(row, :decision_ref) || %{}
    raw_subject_ref = fetch_value(raw_ref, :subject_ref) || fetch_value(row, :subject_ref)

    with {:ok, subject_ref} <- subject_ref_from_any(raw_subject_ref, context) do
      DecisionRef.new(%{
        id: fetch_value(raw_ref, :id) || fetch_value(row, :review_unit_id),
        decision_kind:
          normalize_string(
            fetch_value(raw_ref, :decision_kind) || fetch_value(row, :review_kind) || "review"
          ),
        subject_ref: subject_ref
      })
    end
  end

  defp subject_ref_from_any(nil, _context), do: {:ok, nil}

  defp subject_ref_from_any(raw_subject_ref, %RequestContext{} = context)
       when is_map(raw_subject_ref) do
    SubjectRef.new(%{
      id: fetch_value(raw_subject_ref, :id),
      subject_kind: normalize_string(fetch_value(raw_subject_ref, :subject_kind) || "subject"),
      installation_ref: context.installation_ref
    })
  end

  defp install_result_from_bridge(bridge_result) do
    with {:ok, installation_ref} <-
           installation_ref_from_map(fetch_value(bridge_result, :installation_ref)) do
      InstallResult.new(%{
        installation_ref: installation_ref,
        status: fetch_value(bridge_result, :status),
        message: fetch_value(bridge_result, :message),
        metadata: fetch_value(bridge_result, :metadata) || %{}
      })
    end
  end

  defp installation_ref_from_detail(detail) do
    installation_ref_from_map(fetch_value(detail, :installation_ref))
  end

  defp installation_ref_from_map(raw_installation_ref) when is_map(raw_installation_ref) do
    InstallationRef.new(%{
      id: fetch_value(raw_installation_ref, :id),
      pack_slug: fetch_value(raw_installation_ref, :pack_slug),
      pack_version: fetch_value(raw_installation_ref, :pack_version),
      compiled_pack_revision: fetch_value(raw_installation_ref, :compiled_pack_revision),
      status: normalize_atomish(fetch_value(raw_installation_ref, :status))
    })
  end

  defp installation_ref_from_map(_raw_installation_ref), do: {:error, :invalid_installation_ref}

  defp action_result_from_bridge(bridge_result) do
    with {:ok, action_ref} <-
           operator_action_ref_from_map(fetch_value(bridge_result, :action_ref)),
         {:ok, execution_ref} <-
           execution_ref_from_bridge(fetch_value(bridge_result, :execution_ref)) do
      ActionResult.new(%{
        status: fetch_value(bridge_result, :status),
        action_ref: action_ref,
        execution_ref: execution_ref,
        message: fetch_value(bridge_result, :message),
        metadata: fetch_value(bridge_result, :metadata) || %{}
      })
    end
  end

  defp operator_action_ref_from_map(nil), do: {:ok, nil}

  defp operator_action_ref_from_map(raw_action_ref) when is_map(raw_action_ref) do
    with {:ok, subject_ref} <- subject_ref_from_action_map(raw_action_ref) do
      OperatorActionRef.new(%{
        id: fetch_value(raw_action_ref, :id),
        action_kind: fetch_value(raw_action_ref, :action_kind),
        subject_ref: subject_ref
      })
    end
  end

  defp operator_action_ref_from_map(_raw_action_ref), do: {:error, :invalid_operator_action_ref}

  defp subject_ref_from_action_map(raw_action_ref) do
    case fetch_value(raw_action_ref, :subject_ref) do
      nil -> {:ok, nil}
      raw_subject_ref when is_map(raw_subject_ref) -> SubjectRef.new(raw_subject_ref)
      _ -> {:error, :invalid_subject_ref}
    end
  end

  defp execution_ref_from_bridge(nil), do: {:ok, nil}

  defp execution_ref_from_bridge(raw_execution_ref) when is_map(raw_execution_ref),
    do: ExecutionRef.new(raw_execution_ref)

  defp execution_ref_from_bridge(_raw_execution_ref), do: {:error, :invalid_execution_ref}

  defp collect(results) do
    Enum.reduce_while(results, {:ok, []}, fn
      {:ok, value}, {:ok, acc} -> {:cont, {:ok, [value | acc]}}
      {:error, reason}, _acc -> {:halt, {:error, reason}}
    end)
    |> case do
      {:ok, values} -> {:ok, Enum.reverse(values)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp fetch_value(map_or_struct, key) when is_map(map_or_struct) do
    map = if is_struct(map_or_struct), do: Map.from_struct(map_or_struct), else: map_or_struct
    Map.get(map, key) || Map.get(map, alternate_key(map, key))
  end

  defp fetch_value(_map_or_struct, _key), do: nil

  defp alternate_key(_map, key) when is_atom(key), do: Atom.to_string(key)

  defp alternate_key(map, key) when is_binary(key) do
    Enum.find(Map.keys(map), fn
      existing_key when is_atom(existing_key) -> Atom.to_string(existing_key) == key
      _existing_key -> false
    end)
  end

  defp alternate_key(_map, _key), do: nil

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp compact_map(map) do
    Map.reject(map, fn {_key, value} -> is_nil(value) end)
  end

  @normalized_atomish_values %{
    "active" => :active,
    "awaiting_review" => :awaiting_review,
    "blocked" => :blocked,
    "created" => :created,
    "degraded" => :degraded,
    "inactive" => :inactive,
    "pending" => :pending,
    "planned" => :planned,
    "planning" => :planning,
    "reused" => :reused,
    "running" => :running,
    "suspended" => :suspended,
    "updated" => :updated
  }

  @not_found_reasons [:bridge_not_found, :not_found, :pack_registration_not_found]
  @conflict_reasons [:installation_pack_conflict, :review_gate_not_satisfied]
  @transient_reasons [:timeout, :temporarily_unavailable]
  @validation_reason_prefixes ["missing_", "invalid_", "unsupported_"]

  defp normalize_atomish(value) when is_binary(value),
    do: Map.get(@normalized_atomish_values, value, value)

  defp normalize_atomish(value), do: value

  defp normalize_string(nil), do: nil
  defp normalize_string(value) when is_atom(value), do: Atom.to_string(value)
  defp normalize_string(value), do: value

  defp normalize_surface_error(%SurfaceError{} = error), do: {:error, error}

  defp normalize_surface_error(reason) do
    {:ok, error} =
      SurfaceError.new(%{
        code: surface_error_code(reason),
        message: surface_error_message(reason),
        kind: surface_error_kind(reason),
        retryable: surface_error_retryable?(reason),
        details: %{reason: inspect(reason)}
      })

    {:error, error}
  end

  defp surface_error_code(reason) when is_atom(reason), do: Atom.to_string(reason)
  defp surface_error_code(_reason), do: "bridge_error"

  defp surface_error_message(reason) do
    reason
    |> inspect()
    |> String.trim_leading(":")
    |> String.replace("_", " ")
    |> String.capitalize()
  end

  defp surface_error_kind(reason) when reason in @not_found_reasons, do: :not_found
  defp surface_error_kind(reason) when reason in @conflict_reasons, do: :conflict
  defp surface_error_kind(reason) when reason in @transient_reasons, do: :transient

  defp surface_error_kind(reason) when is_atom(reason) do
    if validation_reason?(reason), do: :validation, else: :boundary
  end

  defp surface_error_kind(_reason), do: :boundary

  defp surface_error_retryable?(reason), do: surface_error_kind(reason) == :transient

  defp validation_reason?(reason) when is_atom(reason) do
    reason
    |> Atom.to_string()
    |> then(fn string_reason ->
      Enum.any?(@validation_reason_prefixes, &String.starts_with?(string_reason, &1))
    end)
  end
end
