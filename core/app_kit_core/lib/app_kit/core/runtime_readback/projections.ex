defmodule AppKit.Core.RuntimeReadback.RuntimeRunDetail do
  @moduledoc "Run detail readback DTO with deterministic event ordering."

  alias AppKit.Core.PersistencePosture
  alias AppKit.Core.RuntimeReadback.{Diagnostic, RetryRow, RuntimeEventRow, RuntimeRow, Support}

  @enforce_keys [:schema_ref, :schema_version, :run_ref]
  defstruct [
    :schema_ref,
    :schema_version,
    :run_ref,
    :runtime_row,
    events: [],
    retries: [],
    turns: [],
    budget_state: nil,
    candidate_fact_refs: [],
    memory_proof_refs: [],
    agent_loop_diagnostics: [],
    persistence_posture: PersistencePosture.memory(:runtime_projection),
    diagnostics: []
  ]

  def new(%__MODULE__{} = value), do: {:ok, value}

  def new(attrs) do
    with {:ok, attrs, nil} <- Support.normalize(attrs),
         :ok <- Support.reject_selectors(attrs, :invalid_runtime_run_detail),
         schema_ref <- Support.optional(attrs, :schema_ref, "runtime_readback/run_detail.v1"),
         true <- Support.present_binary?(schema_ref),
         schema_version <- Support.optional(attrs, :schema_version, 1),
         true <- schema_version == 1,
         run_ref when is_binary(run_ref) <- Support.required(attrs, :run_ref),
         true <- Support.safe_ref?(run_ref),
         {:ok, runtime_row} <- Support.nested(Support.optional(attrs, :runtime_row), RuntimeRow),
         {:ok, events} <-
           Support.nested_list(Support.optional(attrs, :events, []), RuntimeEventRow),
         {:ok, retries} <- Support.nested_list(Support.optional(attrs, :retries, []), RetryRow),
         turns <- Support.optional(attrs, :turns, []),
         true <- is_list(turns),
         budget_state <- Support.optional(attrs, :budget_state),
         true <- is_nil(budget_state) or is_map(budget_state),
         candidate_fact_refs <- Support.optional(attrs, :candidate_fact_refs, []),
         true <-
           is_list(candidate_fact_refs) and Enum.all?(candidate_fact_refs, &Support.safe_ref?/1),
         memory_proof_refs <- Support.optional(attrs, :memory_proof_refs, []),
         true <- is_list(memory_proof_refs) and Enum.all?(memory_proof_refs, &Support.safe_ref?/1),
         {:ok, agent_loop_diagnostics} <-
           Support.nested_list(Support.optional(attrs, :agent_loop_diagnostics, []), Diagnostic),
         persistence_posture <- Support.persistence_posture(attrs),
         {:ok, diagnostics} <-
           Support.nested_list(Support.optional(attrs, :diagnostics, []), Diagnostic) do
      {:ok,
       %__MODULE__{
         schema_ref: schema_ref,
         schema_version: schema_version,
         run_ref: run_ref,
         runtime_row: runtime_row,
         events: Enum.sort_by(events, &RuntimeEventRow.sort_key/1),
         retries: retries,
         turns: turns,
         budget_state: budget_state,
         candidate_fact_refs: candidate_fact_refs,
         memory_proof_refs: memory_proof_refs,
         agent_loop_diagnostics: agent_loop_diagnostics,
         persistence_posture: persistence_posture,
         diagnostics: diagnostics
       }}
    else
      _ -> {:error, :invalid_runtime_run_detail}
    end
  end

  def dump(%__MODULE__{} = value), do: Support.dump_struct(value)
end

defmodule AppKit.Core.RuntimeReadback.RuntimeStateSnapshot do
  @moduledoc "Aggregate M1 state snapshot exposed by `AppKit.HeadlessSurface`."

  alias AppKit.Core.PersistencePosture

  alias AppKit.Core.RuntimeReadback.{
    Diagnostic,
    PollingState,
    RateLimitSnapshot,
    RuntimeRow,
    Support,
    TokenTotals
  }

  @enforce_keys [:schema_ref, :schema_version, :tenant_ref, :installation_ref]
  defstruct [
    :schema_ref,
    :schema_version,
    :tenant_ref,
    :installation_ref,
    :generated_at,
    :polling_state,
    :token_totals,
    rows: [],
    retry_rows: [],
    rate_limits: [],
    diagnostics: [],
    persistence_posture: PersistencePosture.memory(:runtime_projection),
    page: %{page_size: 25, cursor: nil, total_entries: 0}
  ]

  def new(%__MODULE__{} = value), do: {:ok, value}

  def new(attrs) do
    with {:ok, attrs, nil} <- Support.normalize(attrs),
         :ok <- Support.reject_selectors(attrs, :invalid_runtime_state_snapshot),
         schema_ref <- Support.optional(attrs, :schema_ref, "runtime_readback/state_snapshot.v1"),
         true <- Support.present_binary?(schema_ref),
         schema_version <- Support.optional(attrs, :schema_version, 1),
         true <- schema_version == 1,
         tenant_ref when is_binary(tenant_ref) <- Support.required(attrs, :tenant_ref),
         true <- Support.safe_ref?(tenant_ref),
         installation_ref when is_binary(installation_ref) <-
           Support.required(attrs, :installation_ref),
         true <- Support.safe_ref?(installation_ref),
         generated_at <- Support.optional(attrs, :generated_at),
         true <- Support.optional_timestamp?(generated_at),
         {:ok, polling_state} <-
           Support.nested(Support.optional(attrs, :polling_state), PollingState),
         {:ok, token_totals} <-
           Support.nested(Support.optional(attrs, :token_totals), TokenTotals),
         {:ok, rows} <- Support.nested_list(Support.optional(attrs, :rows, []), RuntimeRow),
         {:ok, rate_limits} <-
           Support.nested_list(Support.optional(attrs, :rate_limits, []), RateLimitSnapshot),
         {:ok, diagnostics} <-
           Support.nested_list(Support.optional(attrs, :diagnostics, []), Diagnostic),
         retry_rows <- Support.optional(attrs, :retry_rows, []),
         true <- is_list(retry_rows),
         persistence_posture <- Support.persistence_posture(attrs),
         page <-
           Support.optional(attrs, :page, %{
             page_size: 25,
             cursor: nil,
             total_entries: length(rows)
           }),
         true <- is_map(page) do
      {:ok,
       %__MODULE__{
         schema_ref: schema_ref,
         schema_version: schema_version,
         tenant_ref: tenant_ref,
         installation_ref: installation_ref,
         generated_at: generated_at,
         polling_state: polling_state,
         token_totals: token_totals,
         rows: Enum.sort_by(rows, &RuntimeRow.sort_key/1, :desc),
         retry_rows: retry_rows,
         rate_limits: rate_limits,
         diagnostics: diagnostics,
         persistence_posture: persistence_posture,
         page: page
       }}
    else
      _ -> {:error, :invalid_runtime_state_snapshot}
    end
  end

  def dump(%__MODULE__{} = value), do: Support.dump_struct(value)
end

defmodule AppKit.Core.RuntimeReadback.RuntimeSubjectDetail do
  @moduledoc "Subject detail readback DTO."

  alias AppKit.Core.PersistencePosture
  alias AppKit.Core.RuntimeReadback.{Diagnostic, RuntimeEventRow, RuntimeRow, Support}

  @enforce_keys [:schema_ref, :schema_version, :subject_ref]
  defstruct [
    :schema_ref,
    :schema_version,
    :subject_ref,
    :summary,
    :runtime_row,
    events: [],
    runs: [],
    persistence_posture: PersistencePosture.memory(:runtime_projection),
    diagnostics: []
  ]

  def new(%__MODULE__{} = value), do: {:ok, value}

  def new(attrs) do
    with {:ok, attrs, nil} <- Support.normalize(attrs),
         :ok <- Support.reject_selectors(attrs, :invalid_runtime_subject_detail),
         schema_ref <- Support.optional(attrs, :schema_ref, "runtime_readback/subject_detail.v1"),
         true <- Support.present_binary?(schema_ref),
         schema_version <- Support.optional(attrs, :schema_version, 1),
         true <- schema_version == 1,
         subject_ref when is_binary(subject_ref) <- Support.required(attrs, :subject_ref),
         true <- Support.safe_ref?(subject_ref),
         summary <- Support.optional(attrs, :summary, %{}),
         true <- is_map(summary),
         {:ok, runtime_row} <- Support.nested(Support.optional(attrs, :runtime_row), RuntimeRow),
         {:ok, events} <-
           Support.nested_list(Support.optional(attrs, :events, []), RuntimeEventRow),
         runs <- Support.optional(attrs, :runs, []),
         true <- is_list(runs),
         persistence_posture <- Support.persistence_posture(attrs),
         {:ok, diagnostics} <-
           Support.nested_list(Support.optional(attrs, :diagnostics, []), Diagnostic) do
      {:ok,
       %__MODULE__{
         schema_ref: schema_ref,
         schema_version: schema_version,
         subject_ref: subject_ref,
         summary: summary,
         runtime_row: runtime_row,
         events: Enum.sort_by(events, &RuntimeEventRow.sort_key/1),
         runs: runs,
         persistence_posture: persistence_posture,
         diagnostics: diagnostics
       }}
    else
      _ -> {:error, :invalid_runtime_subject_detail}
    end
  end

  def dump(%__MODULE__{} = value), do: Support.dump_struct(value)
end
