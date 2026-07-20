defmodule AppKit.Bridges.MezzanineBridge.AgentIntakeMapping do
  @moduledoc false

  alias AppKit.Bridges.MezzanineBridge.{Common, WorkContext}

  alias AppKit.Core.AgentIntake.{
    AgentRunCursor,
    AgentRunEvent,
    AgentRunEventPage,
    RunOutcomeFuture
  }

  alias AppKit.Core.PersistencePosture
  alias AppKit.Core.RequestContext
  alias AppKit.Core.RuntimeReadback.{RuntimeEventRow, RuntimeRow, RuntimeRunDetail}
  alias Mezzanine.Runs.{AcceptCommand, Acceptance, Event, EventCursor}

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

  def run_detail(projection, events) when is_map(projection) and is_list(events) do
    updated_at = Common.fetch_value(projection, :updated_at) || DateTime.utc_now()
    run_ref = Common.fetch_value(projection, :run_ref)
    subject_ref = Common.fetch_value(projection, :subject_ref)
    latest_turn_ref = Common.fetch_value(projection, :latest_turn_ref)
    event_sequence = Common.fetch_value(projection, :event_sequence) || 0

    with :ok <- validate_projection_events(projection, events),
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
               "owner_run_revision" => Common.fetch_value(projection, :run_revision)
             }
           }),
         {:ok, runtime_events} <- map_runtime_events(events) do
      RuntimeRunDetail.new(%{
        run_ref: run_ref,
        runtime_row: runtime_row,
        events: runtime_events,
        turns: turn_rows(latest_turn_ref),
        persistence_posture: PersistencePosture.durable(:runtime_projection)
      })
    end
  end

  def event_limit(opts) do
    case Keyword.get(opts, :event_limit, @default_event_limit) do
      value when is_integer(value) and value > 0 and value <= 500 -> value
      _other -> @default_event_limit
    end
  end

  defp projection_acceptance(projection) do
    projection
    |> Common.fetch_value(:projection)
    |> Common.fetch_value(:acceptance)
    |> Acceptance.new()
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
    AgentRunEvent.new(%{
      event_ref: event.event_ref,
      ledger_ref: event.run_ref,
      event_seq: event.sequence,
      event_kind: event_kind(event.event_type),
      visibility: :product,
      observed_at: DateTime.to_iso8601(event.recorded_at),
      summary: event_summary(event.event_type),
      payload_ref: event.payload_ref
    })
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
    |> Enum.map(fn event ->
      RuntimeEventRow.new(%{
        event_ref: event.event_ref,
        event_seq: event.sequence,
        event_kind: event.event_type,
        observed_at: event.recorded_at,
        tenant_ref: event.tenant_ref,
        run_ref: event.run_ref,
        payload_ref: event.payload_ref,
        message_summary: event_summary(event.event_type),
        extensions: %{
          "command_ref" => event.command_ref,
          "correlation_ref" => event.correlation_ref,
          "row_version" => event.row_version
        }
      })
    end)
    |> Common.collect()
  end

  defp turn_rows(nil), do: []
  defp turn_rows(turn_ref), do: [%{turn_ref: turn_ref, sequence: 1, status: "accepted"}]

  defp event_kind("run_accepted"), do: :run_started
  defp event_kind("turn_accepted"), do: :conversation_delta
  defp event_kind("workflow_start_requested"), do: :execution_update
  defp event_kind("workflow_started"), do: :execution_update

  defp event_summary("run_accepted"), do: "Run accepted"
  defp event_summary("turn_accepted"), do: "Turn accepted"
  defp event_summary("workflow_start_requested"), do: "Workflow start requested"
  defp event_summary("workflow_started"), do: "Workflow started"

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
