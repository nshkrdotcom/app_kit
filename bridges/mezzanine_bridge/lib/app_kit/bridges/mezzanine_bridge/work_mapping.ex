defmodule AppKit.Bridges.MezzanineBridge.WorkMapping do
  @moduledoc false

  alias AppKit.Bridges.MezzanineBridge.{Common, WorkContext}

  alias AppKit.Core.{
    ActionResult,
    BlockingCondition,
    DecisionRef,
    EvidenceProjection,
    ExecutionRef,
    ExecutionStateProjection,
    LowerReceiptSummary,
    NextStepPreview,
    OperatorAction,
    OperatorActionRef,
    OperatorCommandProjection,
    OperatorProjection,
    PendingObligation,
    RequestContext,
    Result,
    ReviewProjection,
    RunRef,
    RunRequest,
    RuntimeEventSummary,
    RuntimeFactsProjection,
    SourceBindingProjection,
    SubjectDetail,
    SubjectRef,
    SubjectRuntimeProjection,
    SubjectSummary,
    TimelineEvent,
    WorkspaceRef
  }

  def get_subject_projection(service, tenant_id, subject_id, opts) do
    if function_exported?(service, :get_subject_projection, 3) do
      service.get_subject_projection(tenant_id, subject_id, opts)
    else
      service.get_subject_projection(tenant_id, subject_id)
    end
  end

  def ensure_runtime_projection_row(projection) when is_map(projection) do
    if runtime_projection_row?(projection) do
      :ok
    else
      {:error, :runtime_projection_not_found}
    end
  end

  def ensure_runtime_projection_row(_projection), do: {:error, :invalid_runtime_projection}

  def subject_ref_from_summary(summary, %RequestContext{} = context) do
    SubjectRef.new(%{
      id: Common.fetch_value(summary, :subject_id),
      subject_kind:
        Common.normalize_string(Common.fetch_value(summary, :subject_kind) || "subject"),
      installation_ref: context.installation_ref
    })
  end

  def subject_summary_from_row(row, %RequestContext{} = context) do
    with {:ok, subject_ref} <- subject_ref_from_summary(row, context) do
      SubjectSummary.new(%{
        subject_ref: subject_ref,
        lifecycle_state: Common.normalize_string(Common.fetch_value(row, :status) || "unknown"),
        title: Common.fetch_value(row, :title),
        summary: Common.fetch_value(row, :description),
        opened_at: Common.fetch_value(row, :inserted_at),
        updated_at: Common.fetch_value(row, :updated_at),
        schema_ref: "mezzanine/work_object",
        schema_version: 1,
        payload:
          subject_payload(row, %{
            program_id: Common.fetch_value(row, :program_id),
            work_class_id: Common.fetch_value(row, :work_class_id),
            external_ref: Common.fetch_value(row, :external_ref),
            priority: Common.fetch_value(row, :priority),
            source_kind: Common.fetch_value(row, :source_kind),
            current_plan_id: Common.fetch_value(row, :current_plan_id)
          })
      })
    end
  end

  def subject_detail_from_row(row, %RequestContext{} = context) do
    with {:ok, subject_ref} <- subject_ref_from_summary(row, context),
         {:ok, current_execution_ref} <- execution_ref_from_row(row, subject_ref),
         {:ok, pending_decision_refs} <- pending_decision_refs_from_row(row, subject_ref),
         {:ok, pending_obligations} <-
           pending_obligations_from_maps(Common.fetch_value(row, :pending_obligations) || []),
         {:ok, blocking_conditions} <-
           blocking_conditions_from_maps(Common.fetch_value(row, :blocking_conditions) || []),
         {:ok, next_step_preview} <-
           next_step_preview_from_map(Common.fetch_value(row, :next_step_preview)) do
      SubjectDetail.new(%{
        subject_ref: subject_ref,
        lifecycle_state: Common.normalize_string(Common.fetch_value(row, :status) || "unknown"),
        title: Common.fetch_value(row, :title),
        description: Common.fetch_value(row, :description),
        current_execution_ref: current_execution_ref,
        pending_decision_refs: pending_decision_refs,
        available_actions: [],
        pending_obligations: pending_obligations,
        blocking_conditions: blocking_conditions,
        next_step_preview: next_step_preview,
        schema_ref: "mezzanine/work_object",
        schema_version: 1,
        payload:
          subject_payload(row, %{
            program_id: Common.fetch_value(row, :program_id),
            work_class_id: Common.fetch_value(row, :work_class_id),
            external_ref: Common.fetch_value(row, :external_ref),
            priority: Common.fetch_value(row, :priority),
            source_kind: Common.fetch_value(row, :source_kind),
            current_plan_id: Common.fetch_value(row, :current_plan_id),
            current_plan_status:
              Common.normalize_string(Common.fetch_value(row, :current_plan_status)),
            active_run_id: Common.fetch_value(row, :active_run_id),
            active_run_status:
              Common.normalize_string(Common.fetch_value(row, :active_run_status)),
            active_execution_trace_id:
              Common.normalize_string(Common.fetch_value(row, :active_execution_trace_id)),
            latest_execution_id: Common.fetch_value(row, :latest_execution_id),
            latest_execution_dispatch_state:
              Common.normalize_string(Common.fetch_value(row, :latest_execution_dispatch_state)),
            latest_execution_trace_id:
              Common.normalize_string(Common.fetch_value(row, :latest_execution_trace_id)),
            gate_status: Common.fetch_value(row, :gate_status),
            timeline: Common.fetch_value(row, :timeline),
            audit_events: Common.fetch_value(row, :audit_events),
            run_series_ids: Common.fetch_value(row, :run_series_ids),
            obligation_ids: Common.fetch_value(row, :obligation_ids),
            pending_obligations: Common.fetch_value(row, :pending_obligations),
            blocking_conditions: Common.fetch_value(row, :blocking_conditions),
            next_step_preview: Common.fetch_value(row, :next_step_preview),
            evidence_bundle_id: Common.fetch_value(row, :evidence_bundle_id),
            control_session_id: Common.fetch_value(row, :control_session_id),
            control_mode: Common.normalize_string(Common.fetch_value(row, :control_mode)),
            last_event_at: Common.fetch_value(row, :last_event_at)
          })
      })
    end
  end

  def subject_runtime_projection_from_map(
        projection,
        %RequestContext{} = context,
        %SubjectRef{} = requested_subject_ref
      )
      when is_map(projection) do
    subject = Common.fetch_value(projection, :subject) || %{}
    lifecycle_state = runtime_lifecycle_state(projection, subject)

    with {:ok, subject_ref} <-
           runtime_subject_ref(projection, subject, requested_subject_ref, context),
         {:ok, source_bindings} <- source_binding_projections(projection),
         {:ok, workspace_ref} <- runtime_workspace_ref(projection, context),
         {:ok, execution_state} <-
           execution_state_projection(projection, subject_ref, lifecycle_state),
         {:ok, lower_receipts} <- lower_receipt_summaries(projection, execution_state),
         {:ok, runtime} <- runtime_facts_projection(projection),
         {:ok, evidence} <- evidence_projections(projection),
         {:ok, review} <- review_projection(projection, subject_ref),
         {:ok, operator_commands} <- operator_command_projections(projection) do
      SubjectRuntimeProjection.new(%{
        subject_ref: subject_ref,
        lifecycle_state: lifecycle_state,
        source_bindings: source_bindings,
        workspace_ref: workspace_ref,
        execution_state: execution_state,
        lower_receipts: lower_receipts,
        runtime: runtime,
        evidence: evidence,
        review: review,
        operator_commands: operator_commands,
        updated_at:
          Common.coerce_datetime(
            Common.fetch_value(projection, :computed_at) ||
              Common.fetch_value(projection, :updated_at)
          ),
        schema_ref: "app_kit/subject_runtime_projection",
        schema_version: 1,
        payload: runtime_projection_payload(projection)
      })
    end
  end

  def subject_runtime_projection_from_map(_projection, _context, _subject_ref),
    do: {:error, :invalid_runtime_projection}

  def action_result_from_bridge(bridge_result) do
    with {:ok, action_ref} <-
           operator_action_ref_from_map(Common.fetch_value(bridge_result, :action_ref)),
         {:ok, execution_ref} <-
           execution_ref_from_bridge(Common.fetch_value(bridge_result, :execution_ref)) do
      ActionResult.new(%{
        status: Common.fetch_value(bridge_result, :status),
        action_ref: action_ref,
        execution_ref: execution_ref,
        message: Common.fetch_value(bridge_result, :message),
        metadata: Common.fetch_value(bridge_result, :metadata) || %{}
      })
    end
  end

  def operator_projection_from_row(row, %RequestContext{} = context) do
    payload = Common.fetch_value(row, :payload) || %{}

    with {:ok, refs} <- operator_projection_refs(row, context),
         {:ok, lists} <- operator_projection_lists(row, payload),
         {:ok, timeline} <- operator_projection_timeline(row, payload) do
      OperatorProjection.new(operator_projection_attrs(row, payload, refs, lists, timeline))
    end
  end

  defp operator_projection_refs(row, context) do
    with {:ok, subject_ref} <- operator_projection_subject_ref(row, context),
         {:ok, current_execution_ref} <-
           execution_ref_from_bridge(Common.fetch_value(row, :current_execution_ref)) do
      {:ok, %{subject_ref: subject_ref, current_execution_ref: current_execution_ref}}
    end
  end

  defp operator_projection_lists(row, payload) do
    with {:ok, pending_decision_refs} <-
           pending_decision_refs_from_maps(Common.fetch_value(row, :pending_decision_refs) || []),
         {:ok, available_actions} <-
           operator_actions_from_maps(Common.fetch_value(row, :available_actions) || []),
         {:ok, pending_obligations} <-
           pending_obligations_from_maps(
             operator_payload_list(row, payload, :pending_obligations)
           ),
         {:ok, blocking_conditions} <-
           blocking_conditions_from_maps(
             operator_payload_list(row, payload, :blocking_conditions)
           ),
         {:ok, next_step_preview} <-
           next_step_preview_from_map(operator_payload_value(row, payload, :next_step_preview)) do
      {:ok,
       %{
         pending_decision_refs: pending_decision_refs,
         available_actions: available_actions,
         pending_obligations: pending_obligations,
         blocking_conditions: blocking_conditions,
         next_step_preview: next_step_preview
       }}
    end
  end

  defp operator_projection_timeline(row, payload) do
    Common.map_each(operator_payload_list(row, payload, :timeline), &timeline_event_from_map/1)
  end

  defp operator_projection_attrs(row, payload, refs, lists, timeline) do
    Map.merge(refs, %{
      lifecycle_state: operator_lifecycle_state(row),
      pending_decision_refs: lists.pending_decision_refs,
      available_actions: lists.available_actions,
      pending_obligations: lists.pending_obligations,
      blocking_conditions: lists.blocking_conditions,
      next_step_preview: lists.next_step_preview,
      timeline: timeline,
      updated_at: operator_projection_updated_at(row, payload),
      payload: payload
    })
  end

  defp operator_payload_list(row, payload, key) do
    operator_payload_value(row, payload, key) || []
  end

  defp operator_payload_value(row, payload, key) do
    Common.fetch_value(row, key) || Common.fetch_value(payload, key)
  end

  defp operator_lifecycle_state(row) do
    Common.normalize_string(
      Common.fetch_value(row, :lifecycle_state) || Common.fetch_value(row, :status) || "unknown"
    )
  end

  defp operator_projection_updated_at(row, payload) do
    Common.coerce_datetime(
      Common.fetch_value(row, :updated_at) || Common.fetch_value(payload, :last_event_at)
    )
  end

  def run_ref_from_projection(
        %OperatorProjection{} = projection,
        %RequestContext{} = context,
        %RunRequest{} = run_request,
        opts
      ) do
    scope_id = WorkContext.scope_id(context, opts, projection.subject_ref.id)
    execution_id = projection.current_execution_ref && projection.current_execution_ref.id

    RunRef.new(%{
      run_id: execution_id || "subject/#{projection.subject_ref.id}",
      scope_id: scope_id,
      metadata: %{
        tenant_id: context.tenant_ref.id,
        work_object_id: projection.subject_ref.id,
        recipe_ref: run_request.recipe_ref,
        trace_id: context.trace_id
      }
    })
  end

  def run_result_from_projection(
        %OperatorProjection{} = projection,
        %RunRef{} = run_ref,
        action_result
      ) do
    Result.new(%{
      surface: :work_control,
      state: run_state(projection),
      payload: %{
        run_ref: run_ref,
        work_object_id: projection.subject_ref.id,
        subject_ref: projection.subject_ref,
        action_result: action_result
      }
    })
  end

  def normalize_public_action_result(%ActionResult{} = action_result, public_kind) do
    action_kind = Common.normalize_string(public_kind)

    with {:ok, normalized_action_ref} <- public_action_ref(action_result.action_ref, action_kind) do
      ActionResult.new(%{
        status: action_result.status,
        action_ref: normalized_action_ref,
        execution_ref: action_result.execution_ref,
        message: public_action_message(action_result.message, action_kind),
        metadata: action_result.metadata
      })
    end
  end

  defp runtime_projection_row?(projection) do
    Common.fetch_value(projection, :projection_name) == "operator_subject_runtime" and
      not is_nil(
        Common.fetch_value(projection, :computed_at) ||
          Common.fetch_value(projection, :updated_at)
      ) and is_map(Common.fetch_value(projection, :execution)) and
      is_map(Common.fetch_value(projection, :lower_receipt)) and
      runtime_source_binding_rows(projection) != []
  end

  defp runtime_lifecycle_state(projection, subject) do
    Common.normalize_string(
      Common.fetch_value(projection, :lifecycle_state) ||
        Common.fetch_value(projection, :work_status) ||
        Common.fetch_value(subject, :lifecycle_state) ||
        Common.fetch_value(subject, :status) ||
        "unknown"
    )
  end

  defp runtime_subject_ref(
         projection,
         subject,
         requested_subject_ref,
         %RequestContext{} = context
       ) do
    subject_id =
      Common.fetch_value(projection, :subject_id) ||
        Common.fetch_value(subject, :subject_id) ||
        Common.fetch_value(subject, :id) ||
        requested_subject_ref.id

    subject_kind =
      Common.normalize_string(
        Common.fetch_value(projection, :subject_kind) ||
          Common.fetch_value(subject, :subject_kind) ||
          requested_subject_ref.subject_kind ||
          "subject"
      )

    SubjectRef.new(%{
      id: subject_id,
      subject_kind: subject_kind,
      installation_ref: requested_subject_ref.installation_ref || context.installation_ref
    })
  end

  defp source_binding_projections(projection) do
    projection
    |> runtime_source_binding_rows()
    |> Common.map_each(&source_binding_projection/1)
  end

  defp runtime_source_binding_rows(projection) do
    cond do
      is_list(Common.fetch_value(projection, :source_bindings)) ->
        Common.fetch_value(projection, :source_bindings)

      is_map(Common.fetch_value(projection, :source_binding)) ->
        [Common.fetch_value(projection, :source_binding)]

      true ->
        []
    end
  end

  defp source_binding_projection(row) when is_map(row) do
    SourceBindingProjection.new(%{
      binding_ref:
        Common.fetch_value(row, :binding_ref) || Common.fetch_value(row, :source_binding_ref),
      source_ref: Common.fetch_value(row, :source_ref),
      source_kind:
        Common.normalize_string(
          Common.fetch_value(row, :source_kind) || Common.fetch_value(row, :kind) || "source"
        ),
      external_system: Common.fetch_value(row, :external_system),
      source_state:
        Common.normalize_string(
          Common.fetch_value(row, :source_state) || Common.fetch_value(row, :state)
        ),
      source_url: Common.fetch_value(row, :source_url) || Common.fetch_value(row, :url),
      workpad_refs: Common.fetch_value(row, :workpad_refs) || [],
      metadata: Common.fetch_value(row, :metadata) || %{}
    })
  end

  defp source_binding_projection(_row), do: {:error, :invalid_source_binding_projection}

  defp runtime_workspace_ref(projection, %RequestContext{} = context) do
    case Common.fetch_value(projection, :workspace_ref) ||
           Common.fetch_value(projection, :workspace) do
      nil ->
        {:ok, nil}

      row when is_map(row) ->
        WorkspaceRef.new(%{
          id: Common.fetch_value(row, :id) || Common.fetch_value(row, :workspace_id),
          tenant_id: Common.fetch_value(row, :tenant_id) || context.tenant_ref.id,
          revision: Common.fetch_value(row, :revision),
          display_label:
            Common.fetch_value(row, :display_label) || Common.fetch_value(row, :label)
        })

      _row ->
        {:error, :invalid_workspace_ref}
    end
  end

  defp execution_state_projection(projection, %SubjectRef{} = subject_ref, lifecycle_state) do
    case Common.fetch_value(projection, :execution) do
      row when is_map(row) ->
        runtime_execution_state(row, subject_ref, lifecycle_state)

      _row ->
        {:ok, nil}
    end
  end

  defp runtime_execution_state(row, %SubjectRef{} = subject_ref, lifecycle_state) do
    execution_id = Common.fetch_value(row, :execution_id) || Common.fetch_value(row, :id)

    dispatch_state =
      Common.normalize_string(Common.fetch_value(row, :dispatch_state) || "unknown")

    with {:ok, execution_ref} <-
           ExecutionRef.new(%{
             id: execution_id,
             subject_ref: subject_ref,
             dispatch_state: dispatch_state
           }) do
      ExecutionStateProjection.new(%{
        execution_ref: execution_ref,
        lifecycle_state: lifecycle_state,
        dispatch_state: dispatch_state,
        failure_kind: Common.normalize_string(Common.fetch_value(row, :failure_kind)),
        updated_at: Common.coerce_datetime(Common.fetch_value(row, :updated_at)),
        metadata: Common.fetch_value(row, :metadata) || %{}
      })
    end
  end

  defp lower_receipt_summaries(projection, execution_state) do
    projection
    |> lower_receipt_rows()
    |> Common.map_each(&lower_receipt_summary(&1, execution_state))
  end

  defp lower_receipt_rows(projection) do
    cond do
      is_list(Common.fetch_value(projection, :lower_receipts)) ->
        Common.fetch_value(projection, :lower_receipts)

      is_map(Common.fetch_value(projection, :lower_receipt)) ->
        [Common.fetch_value(projection, :lower_receipt)]

      true ->
        []
    end
  end

  defp lower_receipt_summary(row, execution_state) when is_map(row) do
    LowerReceiptSummary.new(%{
      receipt_ref: Common.fetch_value(row, :receipt_ref) || Common.fetch_value(row, :receipt_id),
      receipt_state:
        Common.normalize_string(
          Common.fetch_value(row, :receipt_state) || Common.fetch_value(row, :state)
        ),
      lower_receipt_ref: Common.fetch_value(row, :lower_receipt_ref),
      run_ref:
        runtime_lower_ref(
          "lower-run",
          Common.fetch_value(row, :run_ref) || Common.fetch_value(row, :run_id)
        ),
      attempt_ref:
        runtime_lower_ref(
          "lower-attempt",
          Common.fetch_value(row, :attempt_ref) || Common.fetch_value(row, :attempt_id)
        ),
      execution_ref: execution_state && execution_state.execution_ref,
      metadata: Common.fetch_value(row, :metadata) || %{}
    })
  end

  defp lower_receipt_summary(_row, _execution_state), do: {:error, :invalid_lower_receipt_summary}

  defp runtime_lower_ref(_prefix, nil), do: nil

  defp runtime_lower_ref(prefix, value) when is_binary(value) do
    if String.contains?(value, "://"), do: value, else: "#{prefix}://#{value}"
  end

  defp runtime_lower_ref(_prefix, _value), do: nil

  defp runtime_facts_projection(projection) do
    runtime = Common.fetch_value(projection, :runtime) || %{}

    with {:ok, events} <-
           runtime_event_summaries(Common.fetch_value(runtime, :event_counts) || %{}) do
      RuntimeFactsProjection.new(runtime_facts_attrs(projection, runtime, events))
    end
  end

  defp runtime_facts_attrs(projection, runtime, events) do
    %{
      token_totals: Common.fetch_value(runtime, :token_totals) || %{},
      token_dedupe: Common.fetch_value(runtime, :token_dedupe) || %{},
      rate_limit: Common.fetch_value(runtime, :rate_limit) || %{},
      retry_queue: Common.fetch_value(runtime, :retry_queue) || [],
      aitrace: runtime_aitrace(projection, runtime),
      prompt: runtime_section(projection, runtime, :prompt),
      semantic: runtime_section(projection, runtime, :semantic),
      authority: runtime_section(projection, runtime, :authority),
      events: events,
      metadata: runtime_facts_metadata(projection, runtime)
    }
  end

  defp runtime_aitrace(projection, runtime) do
    evidence = Common.fetch_value(projection, :evidence) || %{}

    Common.fetch_value(evidence, :aitrace) || Common.fetch_value(runtime, :aitrace) || %{}
  end

  defp runtime_section(projection, runtime, key) do
    Common.fetch_value(projection, key) || Common.fetch_value(runtime, key) || %{}
  end

  defp runtime_facts_metadata(projection, runtime) do
    runtime_metadata = Common.fetch_value(runtime, :metadata) || %{}

    projection_metadata =
      %{
        "run" => Common.fetch_value(projection, :run),
        "lower_envelope" => Common.fetch_value(projection, :lower_envelope),
        "governance" => Common.fetch_value(projection, :governance),
        "memory_context" => Common.fetch_value(projection, :memory_context),
        "incident_bundles" => Common.fetch_value(projection, :incident_bundles),
        "retry_receipts" => Common.fetch_value(projection, :retry_receipts),
        "acceptance" => Common.fetch_value(projection, :acceptance),
        "provider_evidence" => Common.fetch_value(projection, :provider_evidence),
        "source_publication" => Common.fetch_value(projection, :source_publication),
        "diagnostics" => Common.fetch_value(projection, :diagnostics)
      }
      |> Map.reject(fn {_key, value} -> value in [nil, %{}, []] end)

    Map.merge(runtime_metadata, projection_metadata)
  end

  defp runtime_event_summaries(event_counts) when is_map(event_counts) do
    event_counts
    |> Enum.sort_by(fn {event_kind, _count} -> Common.normalize_string(event_kind) end)
    |> Enum.map(fn {event_kind, count} ->
      RuntimeEventSummary.new(%{
        event_kind: Common.normalize_string(event_kind),
        count: count
      })
    end)
    |> Common.collect()
  end

  defp runtime_event_summaries(_event_counts), do: {:error, :invalid_runtime_event_summary}

  defp evidence_projections(projection) do
    projection
    |> evidence_projection_rows()
    |> Common.map_each(&evidence_projection/1)
  end

  defp evidence_projection_rows(projection) do
    evidence = Common.fetch_value(projection, :evidence)

    cond do
      is_list(Common.fetch_value(evidence, :evidence_refs)) ->
        Common.fetch_value(evidence, :evidence_refs)

      is_list(evidence) ->
        evidence

      true ->
        []
    end
  end

  defp evidence_projection(row) when is_map(row) do
    EvidenceProjection.new(%{
      evidence_ref:
        Common.fetch_value(row, :evidence_ref) || Common.fetch_value(row, :evidence_id),
      evidence_kind:
        Common.normalize_string(
          Common.fetch_value(row, :evidence_kind) || Common.fetch_value(row, :kind)
        ),
      content_ref: Common.fetch_value(row, :content_ref),
      status: Common.normalize_string(Common.fetch_value(row, :status) || "present"),
      metadata: Common.fetch_value(row, :metadata) || %{}
    })
  end

  defp evidence_projection(_row), do: {:error, :invalid_evidence_projection}

  defp review_projection(projection, %SubjectRef{} = subject_ref) do
    review = Common.fetch_value(projection, :review) || %{}
    pending_decision_ids = Common.fetch_value(review, :pending_decision_ids) || []

    status =
      Common.normalize_string(
        Common.fetch_value(review, :status) || review_status(pending_decision_ids)
      )

    pending_decision_ids
    |> Enum.map(fn decision_id ->
      DecisionRef.new(%{
        id: decision_id,
        decision_kind: "operator_review",
        subject_ref: subject_ref
      })
    end)
    |> Common.collect()
    |> case do
      {:ok, pending_decision_refs} ->
        ReviewProjection.new(%{
          status: status,
          pending_decision_refs: pending_decision_refs,
          metadata: Common.fetch_value(review, :metadata) || %{}
        })

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp review_status([_ | _]), do: "pending"
  defp review_status(_pending_decision_ids), do: "none"

  defp operator_command_projections(projection) do
    projection
    |> operator_command_rows()
    |> Common.map_each(&operator_command_projection/1)
  end

  defp operator_command_rows(projection),
    do: Common.fetch_value(projection, :available_actions) || []

  defp operator_command_projection(row) when is_map(row) do
    raw_action_ref = Common.fetch_value(row, :action_ref) || row

    with {:ok, action_ref} <- operator_action_ref_from_map(raw_action_ref) do
      OperatorCommandProjection.new(%{
        command_ref: action_ref,
        status: Common.normalize_string(Common.fetch_value(row, :status) || "available"),
        enabled?: Common.fetch_value(row, :enabled?) != false,
        reason: Common.fetch_value(row, :reason),
        metadata: Common.fetch_value(row, :metadata) || %{}
      })
    end
  end

  defp operator_command_projection(_row), do: {:error, :invalid_operator_command_projection}

  defp runtime_projection_payload(projection) do
    projection
    |> Map.new()
    |> Map.drop([
      :source_bindings,
      "source_bindings",
      :source_binding,
      "source_binding",
      :workspace,
      "workspace",
      :workspace_ref,
      "workspace_ref",
      :execution,
      "execution",
      :lower_receipt,
      "lower_receipt",
      :lower_receipts,
      "lower_receipts",
      :runtime,
      "runtime",
      :evidence,
      "evidence",
      :review,
      "review",
      :available_actions,
      "available_actions"
    ])
  end

  defp subject_payload(row, base_payload) do
    source_payload = Common.fetch_value(row, :source_payload) || %{}

    issue_payload =
      Common.fetch_value(source_payload, :issue) || Common.fetch_value(source_payload, :payload) ||
        %{}

    base_payload
    |> Map.merge(source_payload_projection(source_payload, row, issue_payload))
    |> Common.compact_map()
  end

  defp source_payload_projection(source_payload, row, issue_payload) do
    if source_payload_projection?(source_payload, issue_payload) do
      %{
        identifier: source_identifier(source_payload, issue_payload),
        source_id: source_id(source_payload, issue_payload),
        description: source_description(row, source_payload, issue_payload),
        provider: Common.fetch_value(source_payload, :provider),
        provider_external_ref: Common.fetch_value(source_payload, :provider_external_ref),
        provider_revision: Common.fetch_value(source_payload, :provider_revision),
        source_binding_id: Common.fetch_value(source_payload, :source_binding_id),
        source_ref: Common.fetch_value(source_payload, :source_ref),
        source_state: Common.fetch_value(source_payload, :source_state),
        state_mapping: Common.fetch_value(source_payload, :state_mapping),
        priority:
          Common.fetch_value(row, :priority) || Common.fetch_value(source_payload, :priority),
        branch_ref: Common.fetch_value(source_payload, :branch_ref),
        source_url: Common.fetch_value(source_payload, :source_url),
        labels: Common.fetch_value(source_payload, :labels),
        blocker_refs: Common.fetch_value(source_payload, :blocker_refs),
        pre_dispatch_revalidation: Common.fetch_value(source_payload, :pre_dispatch_revalidation),
        source_routing: Common.fetch_value(source_payload, :source_routing),
        opened_at: Common.fetch_value(source_payload, :opened_at),
        updated_at:
          Common.fetch_value(source_payload, :updated_at) ||
            Common.fetch_value(source_payload, :provider_revision)
      }
      |> Common.compact_map()
      |> Common.maybe_put(:issue, non_empty_map(issue_payload))
    else
      %{}
    end
  end

  defp source_payload_projection?(source_payload, issue_payload) do
    Enum.any?(
      [
        :provider,
        :provider_external_ref,
        :source_binding_id,
        :source_ref,
        :source_state,
        :pre_dispatch_revalidation,
        :branch_ref,
        :source_url,
        :source_routing
      ],
      &(not is_nil(Common.fetch_value(source_payload, &1)))
    ) || not is_nil(Common.fetch_value(issue_payload, :identifier))
  end

  defp source_identifier(source_payload, issue_payload) do
    Common.fetch_value(source_payload, :identifier) ||
      Common.fetch_value(issue_payload, :identifier) ||
      Common.fetch_value(issue_payload, :source_id)
  end

  defp source_id(source_payload, issue_payload) do
    Common.fetch_value(source_payload, :source_id) ||
      Common.fetch_value(issue_payload, :identifier) ||
      Common.fetch_value(issue_payload, :source_id)
  end

  defp source_description(row, source_payload, issue_payload) do
    Common.fetch_value(row, :description) ||
      Common.fetch_value(source_payload, :description) ||
      Common.fetch_value(issue_payload, :description)
  end

  defp non_empty_map(value) when is_map(value) and map_size(value) > 0, do: value
  defp non_empty_map(_value), do: nil

  defp execution_ref_from_row(row, %SubjectRef{} = subject_ref) do
    case Common.fetch_value(row, :active_execution_id) do
      execution_id when is_binary(execution_id) ->
        ExecutionRef.new(%{
          id: execution_id,
          subject_ref: subject_ref,
          dispatch_state:
            Common.normalize_string(Common.fetch_value(row, :active_execution_dispatch_state))
        })

      _ ->
        {:ok, nil}
    end
  end

  defp pending_decision_refs_from_row(row, %SubjectRef{} = subject_ref) do
    pending_review_ids = Common.fetch_value(row, :pending_review_ids) || []

    pending_review_ids
    |> Enum.map(fn review_id ->
      DecisionRef.new(%{
        id: review_id,
        decision_kind: "review",
        subject_ref: subject_ref
      })
    end)
    |> Common.collect()
  end

  defp execution_ref_from_bridge(nil), do: {:ok, nil}

  defp execution_ref_from_bridge(raw_execution_ref) when is_map(raw_execution_ref),
    do: ExecutionRef.new(raw_execution_ref)

  defp execution_ref_from_bridge(_raw_execution_ref), do: {:error, :invalid_execution_ref}

  defp operator_projection_subject_ref(row, %RequestContext{} = context) do
    case subject_ref_from_any(Common.fetch_value(row, :subject_ref), context) do
      {:ok, nil} -> {:error, :invalid_subject_ref}
      other -> other
    end
  end

  defp pending_decision_refs_from_maps(rows) when is_list(rows) do
    rows
    |> Enum.map(&DecisionRef.new/1)
    |> Common.collect()
  end

  defp operator_actions_from_maps(rows) when is_list(rows) do
    Common.map_each(rows, &operator_action_from_map/1)
  end

  defp pending_obligations_from_maps(rows) when is_list(rows) do
    Common.map_each(rows, &pending_obligation_from_map/1)
  end

  defp pending_obligation_from_map(row) when is_map(row) do
    PendingObligation.new(%{
      obligation_id: Common.fetch_value(row, :obligation_id),
      obligation_kind:
        Common.normalize_string(
          Common.fetch_value(row, :obligation_kind) || Common.fetch_value(row, :kind)
        ),
      status: Common.normalize_string(Common.fetch_value(row, :status) || "pending"),
      summary: Common.fetch_value(row, :summary),
      decision_ref_id: Common.fetch_value(row, :decision_ref_id),
      required_by: Common.coerce_datetime(Common.fetch_value(row, :required_by)),
      blocking?: Common.fetch_value(row, :blocking?) || false,
      metadata: Common.fetch_value(row, :metadata) || %{}
    })
  end

  defp pending_obligation_from_map(_row), do: {:error, :invalid_pending_obligation}

  defp blocking_conditions_from_maps(rows) when is_list(rows) do
    Common.map_each(rows, &blocking_condition_from_map/1)
  end

  defp blocking_condition_from_map(row) when is_map(row) do
    BlockingCondition.new(%{
      blocker_kind:
        Common.normalize_string(
          Common.fetch_value(row, :blocker_kind) || Common.fetch_value(row, :kind)
        ),
      status: Common.normalize_string(Common.fetch_value(row, :status) || "blocked"),
      summary: Common.fetch_value(row, :summary),
      reason: Common.normalize_string(Common.fetch_value(row, :reason)),
      obligation_id: Common.fetch_value(row, :obligation_id),
      decision_ref_id: Common.fetch_value(row, :decision_ref_id),
      metadata: Common.fetch_value(row, :metadata) || %{}
    })
  end

  defp blocking_condition_from_map(_row), do: {:error, :invalid_blocking_condition}

  defp next_step_preview_from_map(nil), do: {:ok, nil}

  defp next_step_preview_from_map(row) when is_map(row) do
    NextStepPreview.new(%{
      step_kind: Common.normalize_string(Common.fetch_value(row, :step_kind)),
      status: Common.normalize_string(Common.fetch_value(row, :status)),
      summary: Common.fetch_value(row, :summary),
      blocking_condition_kinds:
        Enum.map(
          Common.fetch_value(row, :blocking_condition_kinds) || [],
          &Common.normalize_string/1
        ),
      obligation_ids: Common.fetch_value(row, :obligation_ids) || [],
      metadata: Common.fetch_value(row, :metadata) || %{}
    })
  end

  defp next_step_preview_from_map(_row), do: {:error, :invalid_next_step_preview}

  defp operator_action_from_map(raw_action) when is_map(raw_action) do
    raw_action_ref = Common.fetch_value(raw_action, :action_ref) || raw_action

    with {:ok, action_ref} <- operator_action_ref_from_map(raw_action_ref) do
      OperatorAction.new(%{
        action_ref: action_ref,
        label: Common.fetch_value(raw_action, :label) || action_label(action_ref.action_kind),
        description: Common.fetch_value(raw_action, :description),
        dangerous?: danger_action?(action_ref.action_kind),
        requires_confirmation?:
          Common.fetch_value(raw_action, :requires_confirmation?) ||
            danger_action?(action_ref.action_kind),
        metadata: Common.fetch_value(raw_action, :metadata) || %{}
      })
    end
  end

  defp operator_action_from_map(_raw_action), do: {:error, :invalid_operator_action}

  defp action_label(action_kind) when is_binary(action_kind) do
    action_kind
    |> String.replace("_", " ")
    |> String.capitalize()
  end

  defp danger_action?(action_kind) when action_kind in ["cancel", "grant_override"], do: true
  defp danger_action?(_action_kind), do: false

  defp timeline_event_from_map(row) when is_map(row) do
    TimelineEvent.new(%{
      ref:
        Common.fetch_value(row, :ref) || Common.fetch_value(row, :id) ||
          Common.fetch_value(row, :event_id),
      event_kind:
        Common.normalize_string(
          Common.fetch_value(row, :event_kind) || Common.fetch_value(row, :kind)
        ),
      occurred_at: Common.coerce_datetime(Common.fetch_value(row, :occurred_at)),
      summary: Common.fetch_value(row, :summary),
      actor_ref: actor_ref_from_any(Common.fetch_value(row, :actor_ref)),
      payload:
        Common.fetch_value(row, :payload) ||
          Common.compact_map(
            Map.drop(Map.new(row), [
              :ref,
              :id,
              :event_kind,
              :kind,
              :occurred_at,
              :summary,
              :actor_ref
            ])
          ),
      metadata: Common.fetch_value(row, :metadata) || %{}
    })
  end

  defp timeline_event_from_map(_row), do: {:error, :invalid_timeline_event}

  defp actor_ref_from_any(nil), do: nil
  defp actor_ref_from_any(%{} = actor_ref), do: actor_ref

  defp actor_ref_from_any(actor_ref) when is_atom(actor_ref) do
    %{id: Atom.to_string(actor_ref), kind: :system}
  end

  defp actor_ref_from_any(actor_ref) when is_binary(actor_ref) do
    %{id: actor_ref, kind: :system}
  end

  defp actor_ref_from_any(_actor_ref), do: nil

  defp subject_ref_from_any(nil, _context), do: {:ok, nil}

  defp subject_ref_from_any(raw_subject_ref, %RequestContext{} = context)
       when is_map(raw_subject_ref) do
    SubjectRef.new(%{
      id: Common.fetch_value(raw_subject_ref, :id),
      subject_kind:
        Common.normalize_string(Common.fetch_value(raw_subject_ref, :subject_kind) || "subject"),
      installation_ref: context.installation_ref
    })
  end

  defp operator_action_ref_from_map(nil), do: {:ok, nil}

  defp operator_action_ref_from_map(raw_action_ref) when is_map(raw_action_ref) do
    with {:ok, subject_ref} <- subject_ref_from_action_map(raw_action_ref) do
      OperatorActionRef.new(%{
        id: Common.fetch_value(raw_action_ref, :id),
        action_kind: Common.fetch_value(raw_action_ref, :action_kind),
        subject_ref: subject_ref
      })
    end
  end

  defp operator_action_ref_from_map(_raw_action_ref), do: {:error, :invalid_operator_action_ref}

  defp subject_ref_from_action_map(raw_action_ref) do
    case Common.fetch_value(raw_action_ref, :subject_ref) do
      nil -> {:ok, nil}
      raw_subject_ref when is_map(raw_subject_ref) -> SubjectRef.new(raw_subject_ref)
      _ -> {:error, :invalid_subject_ref}
    end
  end

  defp public_action_ref(nil, _action_kind), do: {:ok, nil}

  defp public_action_ref(%OperatorActionRef{} = action_ref, action_kind) do
    rewritten_id =
      case String.split(action_ref.id, ":", parts: 2) do
        [subject_id, _legacy_kind] -> "#{subject_id}:#{action_kind}"
        _other -> action_ref.id
      end

    OperatorActionRef.new(%{
      id: rewritten_id,
      action_kind: action_kind,
      subject_ref: action_ref.subject_ref
    })
  end

  defp public_action_message(nil, "retry"), do: "Retry queued"
  defp public_action_message(nil, "cancel"), do: "Cancelled"
  defp public_action_message(message, _action_kind), do: message

  defp run_state(%OperatorProjection{pending_decision_refs: [_ | _]}), do: :waiting_review
  defp run_state(_projection), do: :scheduled
end
