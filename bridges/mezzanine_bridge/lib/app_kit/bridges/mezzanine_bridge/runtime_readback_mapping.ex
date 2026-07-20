defmodule AppKit.Bridges.MezzanineBridge.RuntimeReadbackMapping do
  @moduledoc false

  alias AppKit.Bridges.MezzanineBridge.{Common, Services}

  alias AppKit.Core.RequestContext

  alias AppKit.Core.RuntimeReadback.{
    CommandResult,
    Diagnostic,
    RateLimitSnapshot,
    RetryRow,
    RuntimeEventRow,
    RuntimeRow,
    RuntimeStateSnapshot,
    RuntimeSubjectDetail,
    TokenTotals
  }

  def runtime_state_snapshot(%RequestContext{} = context, rows, runtime_sources, request, now) do
    with {:ok, runtime_rows} <- Common.map_each(runtime_sources, &runtime_row_from_map(&1, now)),
         {:ok, retry_rows} <- state_snapshot_retry_rows(runtime_sources),
         {:ok, rate_limits} <- state_snapshot_rate_limits(runtime_sources),
         {:ok, diagnostics} <- state_snapshot_diagnostics(runtime_sources) do
      RuntimeStateSnapshot.new(%{
        tenant_ref: context.tenant_ref.id,
        installation_ref: readback_installation_ref(context),
        generated_at: now,
        rows: runtime_rows,
        retry_rows: retry_rows,
        token_totals: state_snapshot_token_totals(runtime_sources),
        rate_limits: rate_limits,
        diagnostics: diagnostics,
        polling_state: %{
          checking?: false,
          poll_interval_ms: fetch_readback_page_size(request, 5_000),
          staleness_ms: 0
        },
        page: %{
          page_size: fetch_readback_page_size(request, 25),
          cursor: Common.fetch_value(request || %{}, :cursor),
          total_entries: length(rows)
        }
      })
    end
  end

  def state_snapshot_source(query_service, tenant_ref, row, opts) do
    subject_id = row |> first_value([:subject_id, :subject_ref, :id]) |> readback_ref_id()

    with subject_id when is_binary(subject_id) <- subject_id,
         {:ok, projection} <-
           state_snapshot_runtime_projection(
             query_service,
             tenant_ref,
             subject_id,
             Keyword.put(opts, :runtime_projection?, true)
           ),
         true <- runtime_projection_row?(projection) do
      Map.merge(row, projection)
    else
      _reason -> row
    end
  end

  def runtime_subject_detail(subject_id, projection, now) do
    with {:ok, runtime_row} <-
           runtime_row_from_map(
             Map.merge(
               %{subject_ref: subject_id, run_ref: "run://#{subject_id}", updated_at: now},
               projection
             ),
             now
           ) do
      RuntimeSubjectDetail.new(%{
        subject_ref: subject_id,
        summary:
          Common.compact_map(%{
            title: Common.fetch_value(projection, :title),
            state: Common.fetch_value(projection, :state),
            projection_ref: Common.fetch_value(projection, :projection_ref)
          }),
        runtime_row: runtime_row,
        events: readback_events(projection, now)
      })
    end
  end

  def runtime_refresh_result(request) do
    idempotency_key = Common.fetch_value(request, :idempotency_key)

    CommandResult.new(%{
      command_ref: "command://#{idempotency_key}",
      command_kind: :refresh,
      accepted?: true,
      coalesced?: false,
      status: :accepted,
      authority_state: :local_policy,
      authority_refs: [],
      workflow_effect_state: "pending_signal",
      projection_state: :pending,
      idempotency_key: idempotency_key,
      message: "Refresh command accepted with database_first acknowledgement"
    })
  end

  def runtime_control_result(request) do
    command_kind = Common.fetch_value(request, :action)
    idempotency_key = Common.fetch_value(request, :idempotency_key)

    workflow_effect_state =
      if to_string(command_kind) == "inspect_memory_proof",
        do: "not_available",
        else: "pending_signal"

    diagnostics =
      if to_string(command_kind) == "inspect_memory_proof" do
        [
          %{
            severity: :info,
            code: "memory_proof_not_available",
            message: "Memory proof readback is not available until Phase 7"
          }
        ]
      else
        []
      end

    CommandResult.new(%{
      command_ref: "command://#{idempotency_key}",
      command_kind: command_kind,
      accepted?: true,
      coalesced?: false,
      status: :accepted,
      authority_state: :local_policy,
      authority_refs: [],
      workflow_effect_state: workflow_effect_state,
      projection_state: :pending,
      idempotency_key: idempotency_key,
      message: "Control command accepted with database_first acknowledgement",
      diagnostics: diagnostics
    })
  end

  def runtime_row_from_map(row, now) do
    RuntimeRow.new(readback_row_attrs(row, now))
  end

  def readback_ref_id(%{id: id}), do: id
  def readback_ref_id(value) when is_binary(value), do: value
  def readback_ref_id(value) when is_atom(value), do: Atom.to_string(value)
  def readback_ref_id(nil), do: nil
  def readback_ref_id(value), do: to_string(value)

  def public_readback_map(%DateTime{} = value), do: value

  def public_readback_map(%_{} = value) do
    value
    |> Map.from_struct()
    |> public_readback_map()
  end

  def public_readback_map(%{} = value) do
    Map.new(value, fn {key, val} -> {key, public_readback_map(val)} end)
  end

  def public_readback_map(values) when is_list(values),
    do: Enum.map(values, &public_readback_map/1)

  def public_readback_map(value), do: value

  defp runtime_projection_row?(projection) do
    Common.fetch_value(projection, :projection_name) == "operator_subject_runtime" and
      not is_nil(
        Common.fetch_value(projection, :computed_at) ||
          Common.fetch_value(projection, :updated_at)
      ) and
      is_map(Common.fetch_value(projection, :execution)) and
      is_map(Common.fetch_value(projection, :lower_receipt)) and
      runtime_source_binding_rows(projection) != []
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

  defp state_snapshot_runtime_projection(query_service, tenant_ref, subject_id, opts) do
    cond do
      Services.exports?(query_service, :get_subject_projection, 3) ->
        query_service.get_subject_projection(tenant_ref, subject_id, opts)

      Services.exports?(query_service, :get_subject_projection, 2) ->
        query_service.get_subject_projection(tenant_ref, subject_id)

      true ->
        {:error, :runtime_projection_not_available}
    end
  end

  defp readback_row_attrs(row, now) do
    subject_ref = subject_ref_for_row(row)

    %{
      subject_ref: subject_ref,
      run_ref: run_ref_for_row(row, subject_ref),
      execution_ref:
        normalize_optional_readback_ref(
          first_value(row, [:execution_ref, :execution_id]) ||
            nested_value(row, [:execution, :execution_id]),
          "execution"
        ),
      workflow_ref:
        normalize_optional_readback_ref(
          Common.fetch_value(row, :workflow_ref) ||
            nested_value(row, [:execution, :metadata, :workflow_ref]),
          "workflow"
        ),
      state:
        first_value(row, [:state, :lifecycle_state, :status, :work_status]) ||
          nested_value(row, [:execution, :dispatch_state]) ||
          "unknown",
      status_reason: Common.fetch_value(row, :status_reason),
      updated_at:
        first_value(row, [:updated_at, :computed_at]) ||
          nested_value(row, [:execution, :updated_at]) ||
          now,
      session_ref: readback_session_ref(row),
      workspace_ref: readback_workspace_ref(row),
      polling_state: %{checking?: false, poll_interval_ms: 5_000, staleness_ms: 0},
      token_totals: readback_token_totals(row),
      provider_refs: Common.fetch_value(row, :provider_refs) || %{},
      extensions: readback_row_extensions(row)
    }
  end

  defp state_snapshot_token_totals(rows) do
    rows
    |> Enum.flat_map(fn row ->
      case readback_token_totals(row) do
        nil -> []
        totals -> [totals]
      end
    end)
    |> case do
      [] ->
        nil

      totals ->
        %{
          total_input_tokens: Enum.sum(Enum.map(totals, & &1.total_input_tokens)),
          total_output_tokens: Enum.sum(Enum.map(totals, & &1.total_output_tokens)),
          total_tokens: Enum.sum(Enum.map(totals, & &1.total_tokens)),
          cached_input_tokens: Enum.sum(Enum.map(totals, & &1.cached_input_tokens)),
          source: "runtime:projection"
        }
    end
  end

  defp state_snapshot_retry_rows(rows) do
    rows
    |> Enum.flat_map(&readback_retry_rows/1)
    |> Common.map_each(&RetryRow.new/1)
  end

  defp state_snapshot_rate_limits(rows) do
    rows
    |> Enum.flat_map(&readback_rate_limit_rows/1)
    |> Common.map_each(&RateLimitSnapshot.new/1)
  end

  defp state_snapshot_diagnostics(rows) do
    rows
    |> Enum.flat_map(&readback_diagnostic_rows/1)
    |> Common.map_each(&Diagnostic.new/1)
  end

  defp readback_token_totals(row) do
    totals =
      Common.fetch_value(row, :token_totals) || nested_value(row, [:runtime, :token_totals])

    if is_map(totals) and map_size(totals) > 0 do
      input = integer_first(totals, [:total_input_tokens, :input_tokens, :input])
      output = integer_first(totals, [:total_output_tokens, :output_tokens, :output])

      attrs = %{
        total_input_tokens: input,
        total_output_tokens: output,
        total_tokens: integer_first(totals, [:total_tokens, :total], input + output),
        cached_input_tokens: integer_first(totals, [:cached_input_tokens, :cached_input], 0),
        source: Common.fetch_value(totals, :source)
      }

      case TokenTotals.new(attrs) do
        {:ok, token_totals} -> token_totals
        {:error, _reason} -> nil
      end
    end
  end

  defp readback_retry_rows(row) do
    row
    |> nested_value([:runtime, :retry_queue])
    |> List.wrap()
    |> Enum.with_index()
    |> Enum.flat_map(fn
      {%{} = retry, index} -> [retry_row_attrs(row, retry, index)]
      {_retry, _index} -> []
    end)
  end

  defp retry_row_attrs(row, retry, index) do
    subject_id = row |> first_value([:subject_id, :subject_ref, :id]) |> readback_ref_id()
    retry_ref = Common.fetch_value(retry, :retry_ref)

    attempt_ref =
      Common.fetch_value(retry, :attempt_ref) || retry_ref ||
        "attempt://#{subject_id}/#{index + 1}"

    %{
      retry_ref: retry_ref,
      attempt_ref: attempt_ref,
      status: Common.fetch_value(retry, :status) || "scheduled",
      reason: Common.fetch_value(retry, :reason) || Common.fetch_value(retry, :error),
      scheduled_at: Common.fetch_value(retry, :scheduled_at),
      due_at: Common.fetch_value(retry, :due_at),
      delay_ms: Common.fetch_value(retry, :delay_ms),
      delay_type: Common.fetch_value(retry, :delay_type),
      continuation?: Common.fetch_value(retry, :continuation?),
      worker_ref: Common.fetch_value(retry, :worker_ref),
      workspace_ref: Common.fetch_value(retry, :workspace_ref),
      last_error_ref: Common.fetch_value(retry, :last_error_ref),
      metadata: Common.fetch_value(retry, :metadata) || %{}
    }
    |> Common.compact_map()
  end

  defp readback_rate_limit_rows(row) do
    row
    |> nested_value([:runtime, :rate_limit])
    |> case do
      values when is_list(values) -> values
      %{} = value when map_size(value) > 0 -> [value]
      _value -> []
    end
    |> Enum.flat_map(&rate_limit_row_attrs(row, &1))
  end

  defp rate_limit_row_attrs(row, rate_limit) when is_map(rate_limit) do
    remaining = Common.fetch_value(rate_limit, :remaining)

    if is_integer(remaining) and remaining >= 0 do
      subject_id = row |> first_value([:subject_id, :subject_ref, :id]) |> readback_ref_id()

      [
        %{
          limit_id:
            Common.fetch_value(rate_limit, :limit_id) ||
              "rate-limit://subject/#{subject_id}/runtime",
          name: Common.fetch_value(rate_limit, :name),
          remaining: remaining,
          reset_at: Common.fetch_value(rate_limit, :reset_at),
          window: Common.fetch_value(rate_limit, :window),
          source_event_ref:
            Common.fetch_value(rate_limit, :source_event_ref) || subject_ref_for_row(row)
        }
        |> Common.compact_map()
      ]
    else
      []
    end
  end

  defp rate_limit_row_attrs(_row, _rate_limit), do: []

  defp readback_diagnostic_rows(row) do
    row
    |> first_value([:diagnostics])
    |> List.wrap()
    |> Enum.filter(&is_map/1)
  end

  defp readback_row_extensions(row) do
    existing = Common.fetch_value(row, :extensions) || %{}
    runtime = Common.fetch_value(row, :runtime) || %{}

    runtime_extension =
      %{
        "event_counts" => readback_event_count_rows(Common.fetch_value(runtime, :event_counts)),
        "token_dedupe" => Common.fetch_value(runtime, :token_dedupe),
        "metadata" => runtime_readback_metadata(Common.fetch_value(runtime, :metadata) || %{})
      }
      |> Common.compact_map()

    extension =
      %{
        "runtime" => runtime_extension,
        "profile_refs" => runtime_profile_refs(row),
        "source_sync" => Common.fetch_value(row, :source_sync),
        "reconciliation_warnings" => Common.fetch_value(row, :reconciliation_warnings)
      }
      |> Enum.reject(fn {_key, value} -> value in [nil, %{}, []] end)
      |> Map.new()

    Map.merge(existing, extension)
  end

  defp runtime_readback_metadata(metadata) when is_map(metadata) do
    metadata
    |> Map.take([
      "scheduler_state",
      :scheduler_state,
      "claim_state",
      :claim_state,
      "running_state",
      :running_state,
      "retry_state",
      :retry_state,
      "completion_state",
      :completion_state,
      "projection_source",
      :projection_source,
      "projection_mode",
      :projection_mode
    ])
    |> Map.new(fn {key, value} -> {to_string(key), value} end)
  end

  defp runtime_readback_metadata(_metadata), do: %{}

  defp readback_event_count_rows(event_counts) when is_map(event_counts) do
    Enum.map(event_counts, fn {event_kind, count} ->
      %{"event_kind" => to_string(event_kind), "count" => count}
    end)
  end

  defp readback_event_count_rows(_event_counts), do: nil

  defp runtime_profile_refs(row) do
    run = Common.fetch_value(row, :run) || %{}
    governance = Common.fetch_value(row, :governance) || %{}

    %{
      "runtime_profile_ref" =>
        Common.fetch_value(run, :runtime_profile_ref) ||
          Common.fetch_value(governance, :runtime_profile_ref),
      "runtime_profile_kind" =>
        Common.fetch_value(run, :runtime_profile_kind) ||
          Common.fetch_value(governance, :runtime_profile_kind)
    }
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end

  defp readback_events(source, now) do
    source
    |> event_values()
    |> Enum.with_index()
    |> Enum.flat_map(&readback_event_row(&1, now))
  end

  defp readback_event_row({event, index}, now) do
    case RuntimeEventRow.new(readback_event_attrs(event, index, now)) do
      {:ok, event_row} -> [event_row]
      {:error, _reason} -> []
    end
  end

  defp readback_event_attrs(event, index, now) do
    %{
      event_ref:
        normalize_readback_ref(Common.fetch_value(event, :event_ref) || "event-#{index}", "event"),
      event_seq: Common.fetch_value(event, :event_seq) || index,
      event_kind: first_value(event, [:event_kind, :kind]) || "unknown",
      observed_at: Common.fetch_value(event, :observed_at) || now,
      subject_ref:
        normalize_optional_readback_ref(Common.fetch_value(event, :subject_ref), "subject"),
      run_ref: normalize_optional_readback_ref(Common.fetch_value(event, :run_ref), "run"),
      level: Common.fetch_value(event, :level) || :info,
      message_summary: first_value(event, [:message_summary, :summary]),
      payload_ref:
        normalize_optional_readback_ref(Common.fetch_value(event, :payload_ref), "payload"),
      extensions: Common.fetch_value(event, :extensions) || %{}
    }
  end

  defp event_values(source) do
    case Common.fetch_value(source, :events) do
      events when is_list(events) -> events
      _other -> []
    end
  end

  defp subject_ref_for_row(row),
    do: row |> first_value([:subject_ref, :subject_id, :id]) |> normalize_readback_ref("subject")

  defp run_ref_for_row(row, subject_ref) do
    cond do
      value = first_value(row, [:run_ref, :run_id]) ->
        normalize_readback_ref(value, "run")

      value = nested_value(row, [:run, :run_ref]) ->
        normalize_readback_ref(value, "lower-run")

      value = nested_value(row, [:lower_receipt, :run_id]) ->
        normalize_readback_ref(value, "lower-run")

      true ->
        subject_ref
    end
  end

  defp first_value(source, keys), do: Enum.find_value(keys, &Common.fetch_value(source, &1))

  defp readback_session_ref(row) do
    direct = Common.fetch_value(row, :session_ref) || Common.fetch_value(row, :session_id)

    case direct || nested_value(row, [:run, :attempt_ref]) ||
           nested_value(row, [:lower_receipt, :attempt_id]) do
      nil -> nil
      ^direct when not is_nil(direct) -> %{id: normalize_readback_ref(direct, "session")}
      value -> %{id: normalize_readback_ref(value, "lower-attempt")}
    end
  end

  defp readback_workspace_ref(row) do
    case Common.fetch_value(row, :workspace_ref) || Common.fetch_value(row, :workspace_id) do
      nil ->
        nil

      value ->
        %{
          id: normalize_readback_ref(value, "workspace"),
          display_label: Common.fetch_value(row, :workspace_label),
          path_redacted?: true
        }
    end
  end

  defp readback_installation_ref(context) do
    context
    |> Common.fetch_value(:installation_ref)
    |> readback_ref_id()
    |> case do
      nil -> "installation://unknown"
      value -> normalize_readback_ref(value, "installation")
    end
  end

  defp normalize_optional_readback_ref(nil, _scheme), do: nil
  defp normalize_optional_readback_ref(value, scheme), do: normalize_readback_ref(value, scheme)

  defp normalize_readback_ref(value, scheme) do
    value = readback_ref_id(value) || "unknown"

    if String.contains?(value, "://"), do: value, else: "#{scheme}://#{value}"
  end

  defp fetch_readback_page_size(request, default) do
    case Common.fetch_value(request || %{}, :page_size) do
      value when is_integer(value) and value > 0 -> value
      _other -> default
    end
  end

  defp nested_value(source, keys) do
    Enum.reduce_while(keys, source, fn key, acc ->
      case Common.fetch_value(acc, key) do
        nil -> {:halt, nil}
        value -> {:cont, value}
      end
    end)
  end

  defp integer_first(map, keys, default \\ 0) do
    Enum.find_value(keys, fn key ->
      value = Common.fetch_value(map, key)
      if is_integer(value), do: value
    end) || default
  end
end
