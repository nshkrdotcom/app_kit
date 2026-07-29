defmodule AppKit.Bridges.MezzanineBridge.AgentIntakeMapping do
  @moduledoc false

  alias AppKit.Bridges.MezzanineBridge.{Common, WorkContext}

  alias AppKit.Core.AgentIntake.{
    AgentRunCursor,
    AgentRunEvent,
    AgentRunEventPage,
    RunOutcomeFuture,
    TurnSubmission
  }

  alias AppKit.Core.PersistencePosture
  alias AppKit.Core.RequestContext

  alias AppKit.Core.RuntimeReadback.{
    CommandResult,
    ControlRequest,
    RuntimeEventRow,
    RuntimeRow,
    RuntimeRunDetail
  }

  alias Mezzanine.Runs.{
    AcceptCommand,
    Acceptance,
    Event,
    EventCursor,
    TurnAcceptance,
    TurnCommand
  }

  @default_event_limit 100

  def accept_command(%RequestContext{} = context, request, opts) do
    params = request.params || %{}

    with {:ok, program_id} <- WorkContext.program_id(context, opts),
         {:ok, work_class_id} <- WorkContext.work_class_id(context, params, opts),
         {:ok, deadline_at} <- deadline_at(params),
         {:ok, runtime_profile_ref} <- profile_ref(request.profile_bundle.runtime_profile_ref),
         {:ok, command} <-
           AcceptCommand.new(%{
             command_ref: stable_ref("command", request, context),
             idempotency_key: request.idempotency_key,
             request_hash: request_hash(request, context, program_id, work_class_id),
             tenant_ref: context.tenant_ref.id,
             installation_ref: installation_id(context, request),
             actor_ref: context.actor_ref.id,
             program_id: program_id,
             work_class_id: work_class_id,
             subject_ref: request.subject_ref,
             run_ref: run_ref(request, context),
             trace_ref: request.trace_id,
             correlation_ref: request.correlation_id,
             authority_context_ref: authority_context_ref(request, context),
             runtime_profile_ref: runtime_profile_ref,
             tool_catalog_ref: request.tool_catalog_ref,
             budget_ref: request.budget_ref,
             deadline_at: deadline_at,
             expected_revision: 0,
             first_turn: %{
               turn_ref: stable_ref("turn", request, context),
               subject_ref: request.subject_ref,
               input_artifact_ref: request.initial_input_ref,
               payload_digest: digest(request.initial_input_ref),
               idempotency_key: request.idempotency_key <> ":first-turn",
               sequence: 1,
               row_version: 1
             }
           }) do
      {:ok, command}
    end
  end

  def future(%Acceptance{} = acceptance, request \\ %{}) do
    correlation_id =
      Common.fetch_value(request || %{}, :correlation_id) || acceptance.run_ref

    existing_refs = Common.fetch_value(request || %{}, :governed_effect_refs) || %{}

    RunOutcomeFuture.new(%{
      run_ref: acceptance.run_ref,
      accepted?: true,
      command_ref: acceptance.command_ref,
      correlation_id: correlation_id,
      governed_effect_refs:
        Map.merge(existing_refs, %{
          "turn_ref" => acceptance.turn_ref,
          "event_ref" => acceptance.event_ref,
          "workflow_outbox_ref" => acceptance.workflow_outbox_ref,
          "cursor_ref" => acceptance.cursor.last_event_ref,
          "cursor_sequence" => acceptance.cursor.sequence
        }),
      polling_hint: %{checking?: false, poll_interval_ms: 1_000, staleness_ms: 0}
    })
  end

  def future_from_projection(projection, request) do
    with {:ok, acceptance} <- projection_acceptance(projection) do
      future(acceptance, request)
    end
  end

  def turn_command(
        %RequestContext{} = context,
        %TurnSubmission{} = submission,
        opts
      )
      when is_list(opts) do
    with :ok <- ensure_turn_actor(context, submission),
         {:ok, authority_ref} <- turn_authority_ref(context, opts),
         {:ok, correlation_ref} <- turn_correlation_ref(context),
         {:ok, command} <-
           TurnCommand.new(%{
             command_ref: turn_stable_ref("command", context, submission),
             idempotency_key: submission.idempotency_key,
             request_hash: turn_request_hash(context, submission, authority_ref),
             tenant_ref: context.tenant_ref.id,
             actor_ref: context.actor_ref.id,
             authority_ref: authority_ref,
             run_ref: submission.run_ref,
             turn_ref: turn_stable_ref("turn", context, submission),
             trace_ref: context.trace_id,
             correlation_ref: correlation_ref,
             kind: submission.kind,
             payload_ref: submission.payload_ref,
             payload_digest: digest(submission.payload_ref),
             cursor_ref: submission.cursor_ref,
             pending_ref: submission.pending_ref,
             params: submission.params || %{}
           }) do
      {:ok, command}
    end
  end

  def turn_result(
        %RequestContext{} = context,
        %TurnCommand{} = command,
        acceptance
      ) do
    with {:ok, acceptance} <- TurnAcceptance.new(acceptance),
         :ok <- validate_turn_acceptance(command, acceptance) do
      CommandResult.new(%{
        command_ref: acceptance.command_ref,
        command_kind: :submit_turn,
        accepted?: true,
        coalesced?: acceptance.idempotent_replay?,
        status: :accepted,
        authority_state: :admitted,
        authority_refs: [command.authority_ref],
        workflow_effect_state: "queued_signal",
        projection_state: acceptance.state,
        trace_id: context.trace_id,
        correlation_id: command.correlation_ref,
        receipt_ref: acceptance.event_ref,
        idempotency_key: command.idempotency_key,
        persistence_posture: PersistencePosture.durable(:runtime_projection)
      })
    end
  end

  def cancel_request(%RequestContext{} = context, run_ref, opts)
      when is_binary(run_ref) and run_ref != "" and is_list(opts) do
    with {:ok, idempotency_key} <- cancel_idempotency_key(context, opts),
         {:ok, expected_version} <- cancel_expected_version(opts) do
      ControlRequest.new(%{
        idempotency_key: idempotency_key,
        actor_ref: context.actor_ref.id,
        run_ref: run_ref,
        action: :cancel,
        params:
          %{
            expected_control_row_version: expected_version
          }
          |> Common.maybe_put(:reason, Keyword.get(opts, :cancel_reason))
          |> Common.maybe_put(:payload_ref, Keyword.get(opts, :cancel_payload_ref))
      })
    end
  end

  def cancel_request(_context, _run_ref, _opts),
    do: {:error, :invalid_agent_run_cancel_request}

  def authorize_projection(%RequestContext{} = context, run_ref, projection)
      when is_binary(run_ref) and is_map(projection) do
    projection_run_ref = Common.fetch_value(projection, :run_ref)
    projection_tenant_ref = Common.fetch_value(projection, :tenant_ref)

    cond do
      projection_run_ref != run_ref ->
        {:error, :cursor_run_mismatch}

      not same_tenant?(projection_tenant_ref, context.tenant_ref.id) ->
        {:error, :unauthorized_lower_read}

      true ->
        :ok
    end
  end

  def authorize_cursor(%RequestContext{} = context, %AgentRunCursor{} = cursor) do
    if same_tenant?(cursor.tenant_ref, context.tenant_ref.id) do
      :ok
    else
      {:error, :unauthorized_lower_read}
    end
  end

  def lower_cursor(%AgentRunCursor{last_seq_seen: 0}), do: {:ok, nil}

  def lower_cursor(%AgentRunCursor{} = cursor) do
    EventCursor.new(%{
      run_ref: cursor.ledger_ref,
      last_event_ref: cursor.cursor_ref,
      sequence: cursor.last_seq_seen
    })
  end

  def event_page(%AgentRunCursor{} = requested_cursor, events, limit \\ @default_event_limit)
      when is_list(events) and is_integer(limit) and limit > 0 do
    {visible_events, remaining} = Enum.split(events, limit)

    with :ok <- validate_event_stream(requested_cursor, events),
         {:ok, app_events} <- map_events(visible_events),
         {:ok, cursor} <- advance_cursor(requested_cursor, visible_events) do
      AgentRunEventPage.new(%{
        cursor: cursor,
        events: app_events,
        has_more?: remaining != [],
        next_cursor_ref: if(remaining == [], do: nil, else: cursor.cursor_ref)
      })
    end
  end

  def run_detail(projection, turns, events, provider_events \\ [])
      when is_map(projection) and is_list(turns) and is_list(events) and
             is_list(provider_events) do
    updated_at = Common.fetch_value(projection, :updated_at) || DateTime.utc_now()
    run_ref = Common.fetch_value(projection, :run_ref)
    subject_ref = Common.fetch_value(projection, :subject_ref)
    event_sequence = Common.fetch_value(projection, :event_sequence) || 0

    with :ok <- validate_projection_events(projection, events),
         :ok <- validate_provider_events(projection, provider_events),
         {:ok, turn_rows} <- turn_rows(turns, projection, provider_events),
         {:ok, runtime_row} <-
           RuntimeRow.new(%{
             subject_ref: subject_ref,
             run_ref: run_ref,
             state: Common.fetch_value(projection, :status) || "unknown",
             updated_at: updated_at,
             polling_state: %{checking?: false, poll_interval_ms: 1_000, staleness_ms: 0},
             persistence_posture: PersistencePosture.durable(:runtime_projection),
             extensions: %{
               "owner_cursor_ref" => Common.fetch_value(projection, :latest_event_ref),
               "owner_event_sequence" => event_sequence,
               "owner_run_revision" => Common.fetch_value(projection, :run_revision),
               "control" => control_projection(Common.fetch_value(projection, :control))
             }
           }),
         {:ok, runtime_events} <- map_runtime_events(events) do
      RuntimeRunDetail.new(%{
        run_ref: run_ref,
        runtime_row: runtime_row,
        events: runtime_events,
        turns: turn_rows,
        persistence_posture: PersistencePosture.durable(:runtime_projection)
      })
    end
  end

  def model_turn_ref(projection) when is_map(projection) do
    projection
    |> model_turn_projection()
    |> Common.fetch_value(:turn_ref)
  end

  def event_limit(opts) do
    case Keyword.get(opts, :event_limit, @default_event_limit) do
      value when is_integer(value) and value > 0 and value <= 500 -> value
      _other -> @default_event_limit
    end
  end

  @control_projection_fields [
    :state,
    :generation,
    :attempt_sequence,
    :sequence,
    :row_version,
    :attempt_ref,
    :generation_ref,
    :external_operation_ref,
    :deadline_at,
    :fence_epoch,
    :reconciliation_attempts,
    :reconcile_owner,
    :reconcile_lease_expires_at,
    :next_reconcile_at,
    :terminal_receipt_ref,
    :last_error,
    :updated_at
  ]

  defp control_projection(control) when is_map(control) do
    Map.new(@control_projection_fields, fn field ->
      {Atom.to_string(field), Common.fetch_value(control, field)}
    end)
  end

  defp control_projection(_control), do: %{}

  defp projection_acceptance(projection) do
    projection
    |> Common.fetch_value(:projection)
    |> Common.fetch_value(:acceptance)
    |> Acceptance.new()
  end

  defp ensure_turn_actor(
         %RequestContext{actor_ref: %{id: actor_ref}},
         %TurnSubmission{actor_ref: actor_ref}
       ),
       do: :ok

  defp ensure_turn_actor(_context, _submission),
    do: {:error, :operator_actor_context_mismatch}

  defp turn_authority_ref(%RequestContext{} = context, opts) do
    metadata = context.metadata || %{}

    value =
      Keyword.get(opts, :turn_authority_ref) ||
        Common.fetch_value(metadata, :turn_authority_ref)

    required_turn_ref(value, :missing_turn_authority_ref)
  end

  defp turn_correlation_ref(%RequestContext{} = context) do
    value =
      context.request_id || context.causation_id || context.idempotency_key || context.trace_id

    required_turn_ref(value, :missing_turn_correlation_ref)
  end

  defp required_turn_ref(value, _error) when is_binary(value) and value != "",
    do: {:ok, value}

  defp required_turn_ref(_value, error), do: {:error, error}

  defp cancel_idempotency_key(%RequestContext{} = context, opts) do
    value = Keyword.get(opts, :cancel_idempotency_key) || context.idempotency_key

    case value do
      value when is_binary(value) and value != "" -> {:ok, value}
      _other -> {:error, :missing_agent_cancel_idempotency_key}
    end
  end

  defp cancel_expected_version(opts) do
    case Keyword.get(opts, :expected_control_row_version) do
      value when is_integer(value) and value > 0 -> {:ok, value}
      _other -> {:error, :invalid_expected_control_row_version}
    end
  end

  defp validate_turn_acceptance(command, acceptance) do
    if acceptance.command_ref == command.command_ref and
         acceptance.run_ref == command.run_ref and
         acceptance.turn_ref == command.turn_ref and
         acceptance.cursor.run_ref == command.run_ref and
         acceptance.cursor.last_event_ref == acceptance.event_ref do
      :ok
    else
      {:error, :turn_acceptance_mismatch}
    end
  end

  defp map_events(events) do
    events
    |> Enum.map(&app_event/1)
    |> Common.collect()
  end

  defp validate_event_stream(cursor, events) do
    events
    |> Enum.with_index(cursor.last_seq_seen + 1)
    |> Enum.reduce_while(:ok, fn {event, expected_sequence}, :ok ->
      cond do
        event.run_ref != cursor.ledger_ref ->
          {:halt, {:error, :cursor_run_mismatch}}

        not same_tenant?(event.tenant_ref, cursor.tenant_ref) ->
          {:halt, {:error, :unauthorized_lower_read}}

        event.sequence != expected_sequence ->
          {:halt, {:error, :non_contiguous_event}}

        true ->
          {:cont, :ok}
      end
    end)
  end

  defp validate_projection_events(projection, events) do
    run_ref = Common.fetch_value(projection, :run_ref)
    tenant_ref = Common.fetch_value(projection, :tenant_ref)

    events
    |> Enum.with_index(1)
    |> Enum.reduce_while(:ok, fn {event, expected_sequence}, :ok ->
      cond do
        event.run_ref != run_ref ->
          {:halt, {:error, :cursor_run_mismatch}}

        not same_tenant?(event.tenant_ref, tenant_ref) ->
          {:halt, {:error, :unauthorized_lower_read}}

        event.sequence != expected_sequence ->
          {:halt, {:error, :non_contiguous_event}}

        true ->
          {:cont, :ok}
      end
    end)
  end

  defp app_event(%Event{} = event) do
    with {:ok, event_kind, summary} <- event_presentation(event.event_type) do
      AgentRunEvent.new(%{
        event_ref: event.event_ref,
        ledger_ref: event.run_ref,
        event_seq: event.sequence,
        event_kind: event_kind,
        visibility: :product,
        observed_at: DateTime.to_iso8601(event.recorded_at),
        summary: summary,
        payload_ref: event.payload_ref
      })
    end
  end

  defp advance_cursor(cursor, []), do: {:ok, cursor}

  defp advance_cursor(cursor, events) do
    last = List.last(events)

    AgentRunCursor.new(%{
      cursor_ref: last.event_ref,
      ledger_ref: last.run_ref,
      tenant_ref: cursor.tenant_ref,
      actor_ref: cursor.actor_ref,
      last_seq_seen: last.sequence,
      visibility: cursor.visibility,
      issued_at: cursor.issued_at,
      expires_at: cursor.expires_at
    })
  end

  defp map_runtime_events(events) do
    events
    |> Enum.map(&runtime_event/1)
    |> Common.collect()
  end

  defp runtime_event(event) do
    with {:ok, _event_kind, summary} <- event_presentation(event.event_type) do
      RuntimeEventRow.new(%{
        event_ref: event.event_ref,
        event_seq: event.sequence,
        event_kind: event.event_type,
        observed_at: event.recorded_at,
        tenant_ref: event.tenant_ref,
        run_ref: event.run_ref,
        payload_ref: event.payload_ref,
        message_summary: summary,
        extensions: %{
          "command_ref" => event.command_ref,
          "correlation_ref" => event.correlation_ref,
          "row_version" => event.row_version
        }
      })
    end
  end

  @canonical_turn_fields [
    :turn_ref,
    :run_ref,
    :tenant_ref,
    :subject_ref,
    :input_artifact_ref,
    :payload_digest,
    :sequence,
    :status,
    :provider_attempt_ref,
    :row_version,
    :updated_at
  ]

  defp turn_rows(turns, projection, provider_events) do
    model_turn = model_turn_projection(projection)
    run_ref = Common.fetch_value(projection, :run_ref)
    tenant_ref = Common.fetch_value(projection, :tenant_ref)

    with :ok <- validate_canonical_turns(turns, run_ref, tenant_ref),
         :ok <- validate_model_turn_binding(model_turn, turns) do
      rows =
        Enum.map(turns, fn turn ->
          canonical = project_fields(turn, @canonical_turn_fields)

          if is_map(model_turn) and
               Common.fetch_value(model_turn, :turn_ref) == Common.fetch_value(turn, :turn_ref) do
            canonical
            |> Map.merge(model_turn_row(model_turn, provider_events))
            |> Map.put(:sequence, Common.fetch_value(turn, :sequence))
            |> Map.put(:status, Common.fetch_value(turn, :status))
            |> Map.put(:input_artifact_ref, Common.fetch_value(turn, :input_artifact_ref))
          else
            Map.put(canonical, :state, Common.fetch_value(turn, :status))
          end
        end)

      {:ok, rows}
    end
  end

  defp validate_canonical_turns(turns, run_ref, tenant_ref) do
    valid? =
      turns
      |> Enum.with_index(1)
      |> Enum.all?(fn {turn, expected_sequence} ->
        Common.fetch_value(turn, :run_ref) == run_ref and
          same_tenant?(Common.fetch_value(turn, :tenant_ref), tenant_ref) and
          Common.fetch_value(turn, :sequence) == expected_sequence and
          present_ref?(Common.fetch_value(turn, :turn_ref))
      end)

    if valid?, do: :ok, else: {:error, :invalid_durable_turn_projection}
  end

  defp validate_model_turn_binding(model_turn, turns)
       when is_map(model_turn) and map_size(model_turn) > 0 do
    turn_ref = Common.fetch_value(model_turn, :turn_ref)

    if Enum.any?(turns, &(Common.fetch_value(&1, :turn_ref) == turn_ref)),
      do: :ok,
      else: {:error, :model_turn_without_canonical_turn}
  end

  defp validate_model_turn_binding(_model_turn, _turns), do: :ok

  defp present_ref?(value), do: is_binary(value) and value != ""

  @model_turn_fields [
    :turn_ref,
    :run_ref,
    :tenant_ref,
    :context_artifact_ref,
    :context_digest,
    :prompt_artifact_ref,
    :decision_ref,
    :grant_ref,
    :provider_attempt_ref,
    :provider_family,
    :model_ref,
    :operation_ref,
    :state,
    :provisional_event_sequence,
    :committed_event_sequence,
    :last_committed_provider_event_ref,
    :reply_publication_ref,
    :reply_artifact_ref,
    :continuation_context_ref,
    :continuation_context_digest,
    :cursor,
    :row_version,
    :updated_at
  ]

  @provider_event_fields [
    :event_ref,
    :run_ref,
    :turn_ref,
    :provider_attempt_ref,
    :sequence,
    :event_type,
    :stream,
    :payload_ref,
    :payload_digest,
    :commit_state,
    :observed_at,
    :committed_at,
    :row_version
  ]

  defp model_turn_row(model_turn, provider_events) do
    model_turn
    |> project_fields(@model_turn_fields)
    |> Map.put(:events, Enum.map(provider_events, &project_fields(&1, @provider_event_fields)))
  end

  defp project_fields(value, fields) do
    Map.new(fields, fn field -> {field, Common.fetch_value(value, field)} end)
  end

  defp model_turn_projection(projection) do
    projection
    |> Common.fetch_value(:projection)
    |> Common.fetch_value(:model_turn)
  end

  defp validate_provider_events(projection, provider_events) do
    run_ref = Common.fetch_value(projection, :run_ref)
    turn_ref = model_turn_ref(projection)
    tenant_ref = Common.fetch_value(projection, :tenant_ref)

    provider_events
    |> Enum.with_index(1)
    |> Enum.reduce_while(:ok, fn {event, expected_sequence}, :ok ->
      cond do
        is_nil(turn_ref) ->
          {:halt, {:error, :provider_events_without_model_turn}}

        Common.fetch_value(event, :run_ref) != run_ref ->
          {:halt, {:error, :cursor_run_mismatch}}

        Common.fetch_value(event, :turn_ref) != turn_ref ->
          {:halt, {:error, :cursor_turn_mismatch}}

        not same_tenant?(Common.fetch_value(event, :tenant_ref) || tenant_ref, tenant_ref) ->
          {:halt, {:error, :unauthorized_lower_read}}

        Common.fetch_value(event, :sequence) != expected_sequence ->
          {:halt, {:error, :non_contiguous_provider_event}}

        true ->
          {:cont, :ok}
      end
    end)
  end

  defp event_presentation("run_accepted"), do: {:ok, :run_started, "Run accepted"}
  defp event_presentation("turn_accepted"), do: {:ok, :conversation_delta, "Turn accepted"}

  defp event_presentation("provider_event_committed"),
    do: {:ok, :conversation_delta, "Provider event committed"}

  defp event_presentation("turn_completed"),
    do: {:ok, :conversation_delta, "Turn completed"}

  defp event_presentation("run_control_updated"),
    do: {:ok, :execution_update, "Run control updated"}

  defp event_presentation("workflow_start_requested"),
    do: {:ok, :execution_update, "Workflow start requested"}

  defp event_presentation("workflow_started"),
    do: {:ok, :execution_update, "Workflow started"}

  defp event_presentation(_event_type), do: {:error, :unsupported_owner_event_type}

  defp run_ref(request, context) do
    case Common.fetch_value(request.params || %{}, :run_ref) do
      value when is_binary(value) and value != "" -> value
      _other -> stable_ref("run", request, context)
    end
  end

  defp authority_context_ref(request, context) do
    case Common.fetch_value(request.params || %{}, :authority_context_ref) do
      value when is_binary(value) and value != "" -> value
      _other -> stable_ref("authority-context", request, context)
    end
  end

  defp installation_id(%RequestContext{installation_ref: %{id: id}}, _request)
       when is_binary(id) and id != "",
       do: id

  defp installation_id(_context, request), do: request.installation_ref

  defp profile_ref({:custom, value}) when is_binary(value) and value != "", do: {:ok, value}

  defp profile_ref(value) when is_atom(value) and not is_nil(value),
    do: {:ok, "runtime-profile://app-kit/#{ref_fragment(value)}"}

  defp profile_ref(_value), do: {:error, :invalid_runtime_profile_ref}

  defp deadline_at(params) do
    case Common.fetch_value(params, :deadline_at) do
      nil -> {:ok, nil}
      %DateTime{} = deadline -> {:ok, deadline}
      value when is_binary(value) -> parse_deadline(value)
      _other -> {:error, :invalid_deadline}
    end
  end

  defp parse_deadline(value) do
    case DateTime.from_iso8601(value) do
      {:ok, deadline, _offset} -> {:ok, deadline}
      _other -> {:error, :invalid_deadline}
    end
  end

  defp stable_ref(kind, request, context) do
    token =
      digest_token({
        context.tenant_ref.id,
        installation_id(context, request),
        request.idempotency_key
      })

    "#{kind}://mezzanine/#{token}"
  end

  defp turn_stable_ref(kind, context, submission) do
    token =
      digest_token({
        context.tenant_ref.id,
        submission.run_ref,
        submission.idempotency_key
      })

    case kind do
      "command" -> "command://app-kit/agent-turn/#{token}"
      "turn" -> "turn://mezzanine/#{token}"
    end
  end

  defp turn_request_hash(context, submission, authority_ref) do
    %{
      submission: TurnSubmission.dump(submission),
      tenant_ref: context.tenant_ref.id,
      actor_ref: context.actor_ref.id,
      authority_ref: authority_ref
    }
    |> :erlang.term_to_binary([:deterministic])
    |> digest()
  end

  defp request_hash(request, context, program_id, work_class_id) do
    %{
      request: Map.from_struct(request),
      tenant_id: context.tenant_ref.id,
      installation_id: installation_id(context, request),
      actor_id: context.actor_ref.id,
      program_id: program_id,
      work_class_id: work_class_id
    }
    |> :erlang.term_to_binary([:deterministic])
    |> digest()
  end

  defp digest(value) when is_binary(value),
    do: "sha256:" <> (:crypto.hash(:sha256, value) |> Base.encode16(case: :lower))

  defp digest_token(value) do
    value
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.url_encode64(padding: false)
  end

  defp ref_fragment(value) do
    value
    |> to_string()
    |> String.replace("_", "-")
  end

  defp same_tenant?(left, right) when is_binary(left) and is_binary(right),
    do: tenant_id(left) == tenant_id(right)

  defp same_tenant?(_left, _right), do: false

  defp tenant_id("tenant://" <> value), do: value
  defp tenant_id("tenant:" <> value), do: value
  defp tenant_id(value), do: value
end
