defmodule AppKit.Core.RuntimeProjectionSupport do
  @moduledoc false

  alias AppKit.Core.Support

  @forbidden_selector_keys MapSet.new([
                             "codex_session_id",
                             "github_issue_id",
                             "github_issue_number",
                             "github_pr_id",
                             "github_pr_number",
                             "issue_id",
                             "issue_number",
                             "linear_comment_id",
                             "linear_issue_id",
                             "linear_issue_number",
                             "pr_id",
                             "pr_number",
                             "workflow_id"
                           ])

  @spec normalize_attrs(map() | keyword()) :: {:ok, map()} | {:error, :invalid_attrs}
  def normalize_attrs(attrs), do: Support.normalize_attrs(attrs)

  @spec reject_static_selectors(map(), atom()) :: :ok | {:error, atom()}
  def reject_static_selectors(attrs, error) when is_map(attrs) do
    if selector_key_present?(attrs), do: {:error, error}, else: :ok
  end

  def present_binary?(value), do: Support.present_binary?(value)
  def optional_binary?(value), do: Support.optional_binary?(value)
  def optional_atom_or_binary?(value), do: Support.optional_atom_or_binary?(value)
  def optional_datetime?(value), do: Support.optional_datetime?(value)
  def optional_non_neg_integer?(value), do: Support.optional_non_neg_integer?(value)

  def optional_string_list?(nil), do: true

  def optional_string_list?(values),
    do: is_list(values) and Enum.all?(values, &Support.present_binary?/1)

  def map?(value), do: is_map(value)
  def optional_map?(value), do: Support.optional_map?(value)
  def nested_struct(value, module), do: Support.nested_struct(value, module)
  def nested_structs(values, module), do: Support.nested_structs(values, module)

  defp selector_key_present?(%DateTime{}), do: false

  defp selector_key_present?(%_{} = struct) do
    struct
    |> Map.from_struct()
    |> selector_key_present?()
  end

  defp selector_key_present?(map) when is_map(map) do
    Enum.any?(map, fn {key, value} ->
      forbidden_key?(key) or selector_key_present?(value)
    end)
  end

  defp selector_key_present?(values) when is_list(values),
    do: Enum.any?(values, &selector_key_present?/1)

  defp selector_key_present?(_value), do: false

  defp forbidden_key?(key) when is_atom(key), do: forbidden_key?(Atom.to_string(key))

  defp forbidden_key?(key) when is_binary(key) do
    MapSet.member?(@forbidden_selector_keys, String.downcase(key))
  end

  defp forbidden_key?(_key), do: false
end

defmodule AppKit.Core.SourceBindingProjection do
  @moduledoc """
  Public-safe source binding state carried by source admission and reducers.
  """

  alias AppKit.Core.RuntimeProjectionSupport, as: Support

  @enforce_keys [:binding_ref, :source_ref, :source_kind]
  defstruct [
    :binding_ref,
    :source_ref,
    :source_kind,
    external_system: nil,
    source_state: nil,
    source_url: nil,
    workpad_refs: [],
    metadata: %{}
  ]

  @type t :: %__MODULE__{
          binding_ref: String.t(),
          source_ref: String.t(),
          source_kind: String.t(),
          external_system: String.t() | nil,
          source_state: String.t() | nil,
          source_url: String.t() | nil,
          workpad_refs: [String.t()],
          metadata: map()
        }

  @spec new(map() | keyword()) :: {:ok, t()} | {:error, :invalid_source_binding_projection}
  def new(attrs) do
    with {:ok, attrs} <- Support.normalize_attrs(attrs),
         :ok <- Support.reject_static_selectors(attrs, :invalid_source_binding_projection),
         binding_ref <- Map.get(attrs, :binding_ref),
         true <- Support.present_binary?(binding_ref),
         source_ref <- Map.get(attrs, :source_ref),
         true <- Support.present_binary?(source_ref),
         source_kind <- Map.get(attrs, :source_kind),
         true <- Support.present_binary?(source_kind),
         external_system <- Map.get(attrs, :external_system),
         true <- Support.optional_binary?(external_system),
         source_state <- Map.get(attrs, :source_state),
         true <- Support.optional_binary?(source_state),
         source_url <- Map.get(attrs, :source_url),
         true <- Support.optional_binary?(source_url),
         workpad_refs <- Map.get(attrs, :workpad_refs, []),
         true <- Support.optional_string_list?(workpad_refs),
         metadata <- Map.get(attrs, :metadata, %{}),
         true <- Support.map?(metadata) do
      {:ok,
       %__MODULE__{
         binding_ref: binding_ref,
         source_ref: source_ref,
         source_kind: source_kind,
         external_system: external_system,
         source_state: source_state,
         source_url: source_url,
         workpad_refs: workpad_refs,
         metadata: metadata
       }}
    else
      _ -> {:error, :invalid_source_binding_projection}
    end
  end
end

defmodule AppKit.Core.ExecutionStateProjection do
  @moduledoc """
  Public-safe execution lifecycle and dispatch state for a subject.
  """

  alias AppKit.Core.{ExecutionRef, RuntimeProjectionSupport}

  @enforce_keys [:execution_ref, :lifecycle_state, :dispatch_state]
  defstruct [
    :execution_ref,
    :lifecycle_state,
    :dispatch_state,
    failure_kind: nil,
    updated_at: nil,
    metadata: %{}
  ]

  @type t :: %__MODULE__{
          execution_ref: ExecutionRef.t(),
          lifecycle_state: String.t(),
          dispatch_state: String.t(),
          failure_kind: String.t() | atom() | nil,
          updated_at: DateTime.t() | nil,
          metadata: map()
        }

  @spec new(map() | keyword()) :: {:ok, t()} | {:error, :invalid_execution_state_projection}
  def new(attrs) do
    with {:ok, attrs} <- RuntimeProjectionSupport.normalize_attrs(attrs),
         :ok <-
           RuntimeProjectionSupport.reject_static_selectors(
             attrs,
             :invalid_execution_state_projection
           ),
         {:ok, execution_ref} <-
           RuntimeProjectionSupport.nested_struct(Map.get(attrs, :execution_ref), ExecutionRef),
         false <- is_nil(execution_ref),
         lifecycle_state <- Map.get(attrs, :lifecycle_state),
         true <- RuntimeProjectionSupport.present_binary?(lifecycle_state),
         dispatch_state <- Map.get(attrs, :dispatch_state),
         true <- RuntimeProjectionSupport.present_binary?(dispatch_state),
         failure_kind <- Map.get(attrs, :failure_kind),
         true <- RuntimeProjectionSupport.optional_atom_or_binary?(failure_kind),
         updated_at <- Map.get(attrs, :updated_at),
         true <- RuntimeProjectionSupport.optional_datetime?(updated_at),
         metadata <- Map.get(attrs, :metadata, %{}),
         true <- RuntimeProjectionSupport.map?(metadata) do
      {:ok,
       %__MODULE__{
         execution_ref: execution_ref,
         lifecycle_state: lifecycle_state,
         dispatch_state: dispatch_state,
         failure_kind: failure_kind,
         updated_at: updated_at,
         metadata: metadata
       }}
    else
      _ -> {:error, :invalid_execution_state_projection}
    end
  end
end

defmodule AppKit.Core.LowerReceiptSummary do
  @moduledoc """
  Compact lower receipt summary carried by reducer-owned runtime projections.
  """

  alias AppKit.Core.{ExecutionRef, RuntimeProjectionSupport}

  @enforce_keys [:receipt_ref, :receipt_state]
  defstruct [
    :receipt_ref,
    :receipt_state,
    lower_receipt_ref: nil,
    run_ref: nil,
    attempt_ref: nil,
    execution_ref: nil,
    metadata: %{}
  ]

  @type t :: %__MODULE__{
          receipt_ref: String.t(),
          receipt_state: String.t(),
          lower_receipt_ref: String.t() | nil,
          run_ref: String.t() | nil,
          attempt_ref: String.t() | nil,
          execution_ref: ExecutionRef.t() | nil,
          metadata: map()
        }

  @spec new(map() | keyword()) :: {:ok, t()} | {:error, :invalid_lower_receipt_summary}
  def new(attrs) do
    with {:ok, attrs} <- RuntimeProjectionSupport.normalize_attrs(attrs),
         :ok <-
           RuntimeProjectionSupport.reject_static_selectors(attrs, :invalid_lower_receipt_summary),
         receipt_ref <- Map.get(attrs, :receipt_ref),
         true <- RuntimeProjectionSupport.present_binary?(receipt_ref),
         receipt_state <- Map.get(attrs, :receipt_state),
         true <- RuntimeProjectionSupport.present_binary?(receipt_state),
         lower_receipt_ref <- Map.get(attrs, :lower_receipt_ref),
         true <- RuntimeProjectionSupport.present_binary?(lower_receipt_ref),
         run_ref <- Map.get(attrs, :run_ref),
         true <- RuntimeProjectionSupport.optional_binary?(run_ref),
         attempt_ref <- Map.get(attrs, :attempt_ref),
         true <- RuntimeProjectionSupport.optional_binary?(attempt_ref),
         {:ok, execution_ref} <-
           RuntimeProjectionSupport.nested_struct(Map.get(attrs, :execution_ref), ExecutionRef),
         false <- is_nil(execution_ref),
         metadata <- Map.get(attrs, :metadata, %{}),
         true <- RuntimeProjectionSupport.map?(metadata) do
      {:ok,
       %__MODULE__{
         receipt_ref: receipt_ref,
         receipt_state: receipt_state,
         lower_receipt_ref: lower_receipt_ref,
         run_ref: run_ref,
         attempt_ref: attempt_ref,
         execution_ref: execution_ref,
         metadata: metadata
       }}
    else
      _ -> {:error, :invalid_lower_receipt_summary}
    end
  end
end

defmodule AppKit.Core.RuntimeEventSummary do
  @moduledoc """
  Counted runtime event summary for product-facing dashboards and harnesses.
  """

  alias AppKit.Core.RuntimeProjectionSupport, as: Support

  @enforce_keys [:event_kind, :count]
  defstruct [:event_kind, :count, latest_event_ref: nil, metadata: %{}]

  @type t :: %__MODULE__{
          event_kind: String.t(),
          count: non_neg_integer(),
          latest_event_ref: String.t() | nil,
          metadata: map()
        }

  @spec new(map() | keyword()) :: {:ok, t()} | {:error, :invalid_runtime_event_summary}
  def new(attrs) do
    with {:ok, attrs} <- Support.normalize_attrs(attrs),
         :ok <- Support.reject_static_selectors(attrs, :invalid_runtime_event_summary),
         event_kind <- Map.get(attrs, :event_kind),
         true <- Support.present_binary?(event_kind),
         count <- Map.get(attrs, :count),
         true <- is_integer(count) and count >= 0,
         latest_event_ref <- Map.get(attrs, :latest_event_ref),
         true <- Support.optional_binary?(latest_event_ref),
         metadata <- Map.get(attrs, :metadata, %{}),
         true <- Support.map?(metadata) do
      {:ok,
       %__MODULE__{
         event_kind: event_kind,
         count: count,
         latest_event_ref: latest_event_ref,
         metadata: metadata
       }}
    else
      _ -> {:error, :invalid_runtime_event_summary}
    end
  end
end

defmodule AppKit.Core.RuntimeFactsProjection do
  @moduledoc """
  Public-safe runtime facts projected from lower receipts and events.
  """

  alias AppKit.Core.{RuntimeEventSummary, RuntimeProjectionSupport}

  defstruct token_totals: %{}, rate_limit: %{}, events: [], metadata: %{}

  @type t :: %__MODULE__{
          token_totals: map(),
          rate_limit: map(),
          events: [RuntimeEventSummary.t()],
          metadata: map()
        }

  @spec new(map() | keyword()) :: {:ok, t()} | {:error, :invalid_runtime_facts_projection}
  def new(attrs) do
    with {:ok, attrs} <- RuntimeProjectionSupport.normalize_attrs(attrs),
         :ok <-
           RuntimeProjectionSupport.reject_static_selectors(
             attrs,
             :invalid_runtime_facts_projection
           ),
         token_totals <- Map.get(attrs, :token_totals, %{}),
         true <- RuntimeProjectionSupport.map?(token_totals),
         rate_limit <- Map.get(attrs, :rate_limit, %{}),
         true <- RuntimeProjectionSupport.map?(rate_limit),
         {:ok, events} <-
           RuntimeProjectionSupport.nested_structs(
             Map.get(attrs, :events, []),
             RuntimeEventSummary
           ),
         metadata <- Map.get(attrs, :metadata, %{}),
         true <- RuntimeProjectionSupport.map?(metadata) do
      {:ok,
       %__MODULE__{
         token_totals: token_totals,
         rate_limit: rate_limit,
         events: events,
         metadata: metadata
       }}
    else
      _ -> {:error, :invalid_runtime_facts_projection}
    end
  end
end

defmodule AppKit.Core.EvidenceProjection do
  @moduledoc """
  Evidence ref summary without raw provider payloads.
  """

  alias AppKit.Core.RuntimeProjectionSupport, as: Support

  @enforce_keys [:evidence_ref, :evidence_kind, :status]
  defstruct [:evidence_ref, :evidence_kind, :status, content_ref: nil, metadata: %{}]

  @type t :: %__MODULE__{
          evidence_ref: String.t(),
          evidence_kind: String.t(),
          status: String.t(),
          content_ref: String.t() | nil,
          metadata: map()
        }

  @spec new(map() | keyword()) :: {:ok, t()} | {:error, :invalid_evidence_projection}
  def new(attrs) do
    with {:ok, attrs} <- Support.normalize_attrs(attrs),
         :ok <- Support.reject_static_selectors(attrs, :invalid_evidence_projection),
         evidence_ref <- Map.get(attrs, :evidence_ref),
         true <- Support.present_binary?(evidence_ref),
         evidence_kind <- Map.get(attrs, :evidence_kind),
         true <- Support.present_binary?(evidence_kind),
         status <- Map.get(attrs, :status),
         true <- Support.present_binary?(status),
         content_ref <- Map.get(attrs, :content_ref),
         true <- Support.optional_binary?(content_ref),
         metadata <- Map.get(attrs, :metadata, %{}),
         true <- Support.map?(metadata) do
      {:ok,
       %__MODULE__{
         evidence_ref: evidence_ref,
         evidence_kind: evidence_kind,
         status: status,
         content_ref: content_ref,
         metadata: metadata
       }}
    else
      _ -> {:error, :invalid_evidence_projection}
    end
  end
end

defmodule AppKit.Core.ReviewProjection do
  @moduledoc """
  Review gate summary backed by durable decision ids.
  """

  alias AppKit.Core.{DecisionRef, RuntimeProjectionSupport}

  @enforce_keys [:status]
  defstruct [:status, pending_decision_refs: [], metadata: %{}]

  @type t :: %__MODULE__{
          status: String.t(),
          pending_decision_refs: [DecisionRef.t()],
          metadata: map()
        }

  @spec new(map() | keyword()) :: {:ok, t()} | {:error, :invalid_review_projection}
  def new(attrs) do
    with {:ok, attrs} <- RuntimeProjectionSupport.normalize_attrs(attrs),
         :ok <-
           RuntimeProjectionSupport.reject_static_selectors(attrs, :invalid_review_projection),
         status <- Map.get(attrs, :status),
         true <- RuntimeProjectionSupport.present_binary?(status),
         {:ok, pending_decision_refs} <-
           RuntimeProjectionSupport.nested_structs(
             Map.get(attrs, :pending_decision_refs, []),
             DecisionRef
           ),
         metadata <- Map.get(attrs, :metadata, %{}),
         true <- RuntimeProjectionSupport.map?(metadata) do
      {:ok,
       %__MODULE__{
         status: status,
         pending_decision_refs: pending_decision_refs,
         metadata: metadata
       }}
    else
      _ -> {:error, :invalid_review_projection}
    end
  end
end

defmodule AppKit.Core.OperatorCommandProjection do
  @moduledoc """
  Product-facing operator command availability and state.
  """

  alias AppKit.Core.{OperatorActionRef, RuntimeProjectionSupport}

  @enforce_keys [:command_ref, :status]
  defstruct [:command_ref, :status, enabled?: true, reason: nil, metadata: %{}]

  @type t :: %__MODULE__{
          command_ref: OperatorActionRef.t(),
          status: String.t(),
          enabled?: boolean(),
          reason: String.t() | nil,
          metadata: map()
        }

  @spec new(map() | keyword()) :: {:ok, t()} | {:error, :invalid_operator_command_projection}
  def new(attrs) do
    with {:ok, attrs} <- RuntimeProjectionSupport.normalize_attrs(attrs),
         :ok <-
           RuntimeProjectionSupport.reject_static_selectors(
             attrs,
             :invalid_operator_command_projection
           ),
         {:ok, command_ref} <-
           RuntimeProjectionSupport.nested_struct(Map.get(attrs, :command_ref), OperatorActionRef),
         false <- is_nil(command_ref),
         status <- Map.get(attrs, :status),
         true <- RuntimeProjectionSupport.present_binary?(status),
         enabled? <- Map.get(attrs, :enabled?, true),
         true <- is_boolean(enabled?),
         reason <- Map.get(attrs, :reason),
         true <- RuntimeProjectionSupport.optional_binary?(reason),
         metadata <- Map.get(attrs, :metadata, %{}),
         true <- RuntimeProjectionSupport.map?(metadata) do
      {:ok,
       %__MODULE__{
         command_ref: command_ref,
         status: status,
         enabled?: enabled?,
         reason: reason,
         metadata: metadata
       }}
    else
      _ -> {:error, :invalid_operator_command_projection}
    end
  end
end

defmodule AppKit.Core.SubjectRuntimeProjection do
  @moduledoc """
  Typed subject runtime projection for product-facing non-UI operator lanes.
  """

  alias AppKit.Core.{
    EvidenceProjection,
    ExecutionStateProjection,
    LowerReceiptSummary,
    OperatorCommandProjection,
    ReviewProjection,
    RuntimeFactsProjection,
    RuntimeProjectionSupport,
    SourceBindingProjection,
    SubjectRef,
    WorkspaceRef
  }

  @enforce_keys [:subject_ref, :lifecycle_state]
  defstruct [
    :subject_ref,
    :lifecycle_state,
    source_bindings: [],
    workspace_ref: nil,
    execution_state: nil,
    lower_receipts: [],
    runtime: nil,
    evidence: [],
    review: nil,
    operator_commands: [],
    updated_at: nil,
    schema_ref: nil,
    schema_version: nil,
    payload: %{}
  ]

  @type t :: %__MODULE__{
          subject_ref: SubjectRef.t(),
          lifecycle_state: String.t(),
          source_bindings: [SourceBindingProjection.t()],
          workspace_ref: WorkspaceRef.t() | nil,
          execution_state: ExecutionStateProjection.t() | nil,
          lower_receipts: [LowerReceiptSummary.t()],
          runtime: RuntimeFactsProjection.t() | nil,
          evidence: [EvidenceProjection.t()],
          review: ReviewProjection.t() | nil,
          operator_commands: [OperatorCommandProjection.t()],
          updated_at: DateTime.t() | nil,
          schema_ref: String.t() | nil,
          schema_version: non_neg_integer() | nil,
          payload: map()
        }

  @spec new(map() | keyword()) :: {:ok, t()} | {:error, :invalid_subject_runtime_projection}
  def new(attrs) do
    with {:ok, attrs} <- RuntimeProjectionSupport.normalize_attrs(attrs),
         :ok <-
           RuntimeProjectionSupport.reject_static_selectors(
             attrs,
             :invalid_subject_runtime_projection
           ),
         {:ok, subject_ref} <-
           RuntimeProjectionSupport.nested_struct(Map.get(attrs, :subject_ref), SubjectRef),
         false <- is_nil(subject_ref),
         lifecycle_state <- Map.get(attrs, :lifecycle_state),
         true <- RuntimeProjectionSupport.present_binary?(lifecycle_state),
         {:ok, source_bindings} <-
           RuntimeProjectionSupport.nested_structs(
             Map.get(attrs, :source_bindings, []),
             SourceBindingProjection
           ),
         true <- source_bindings != [],
         {:ok, workspace_ref} <-
           RuntimeProjectionSupport.nested_struct(Map.get(attrs, :workspace_ref), WorkspaceRef),
         {:ok, execution_state} <-
           RuntimeProjectionSupport.nested_struct(
             Map.get(attrs, :execution_state),
             ExecutionStateProjection
           ),
         false <- is_nil(execution_state),
         {:ok, lower_receipts} <-
           RuntimeProjectionSupport.nested_structs(
             Map.get(attrs, :lower_receipts, []),
             LowerReceiptSummary
           ),
         true <- lower_receipts != [],
         {:ok, runtime} <-
           RuntimeProjectionSupport.nested_struct(
             Map.get(attrs, :runtime, %{}),
             RuntimeFactsProjection
           ),
         {:ok, evidence} <-
           RuntimeProjectionSupport.nested_structs(
             Map.get(attrs, :evidence, []),
             EvidenceProjection
           ),
         {:ok, review} <-
           RuntimeProjectionSupport.nested_struct(
             Map.get(attrs, :review, %{status: "none"}),
             ReviewProjection
           ),
         {:ok, operator_commands} <-
           RuntimeProjectionSupport.nested_structs(
             Map.get(attrs, :operator_commands, []),
             OperatorCommandProjection
           ),
         updated_at <- Map.get(attrs, :updated_at),
         true <- not is_nil(updated_at) and RuntimeProjectionSupport.optional_datetime?(updated_at),
         schema_ref <- Map.get(attrs, :schema_ref),
         true <- RuntimeProjectionSupport.present_binary?(schema_ref),
         schema_version <- Map.get(attrs, :schema_version),
         true <- is_integer(schema_version) and schema_version >= 0,
         payload <- Map.get(attrs, :payload, %{}),
         true <- RuntimeProjectionSupport.map?(payload) do
      {:ok,
       %__MODULE__{
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
         updated_at: updated_at,
         schema_ref: schema_ref,
         schema_version: schema_version,
         payload: payload
       }}
    else
      _ -> {:error, :invalid_subject_runtime_projection}
    end
  end
end
