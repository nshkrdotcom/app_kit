defmodule AppKit.Core.ProductSurface.Support do
  @moduledoc false

  alias AppKit.Core.Substrate.{Dump, Support}

  def normalize(%module{} = value, module), do: {:ok, value}

  def normalize(attrs, _module) do
    with {:ok, attrs} <- Support.normalize_attrs(attrs),
         :ok <- Support.reject_selectors(attrs, :invalid_product_surface_payload) do
      {:ok, attrs}
    end
  end

  def fetch(attrs, key, default \\ nil),
    do: Map.get(attrs, key, Map.get(attrs, Atom.to_string(key), default))

  def ref?(value), do: Support.safe_ref?(value)
  def optional_ref?(nil), do: true
  def optional_ref?(value), do: ref?(value)

  def ref_list?(values) when is_list(values), do: Enum.all?(values, &ref?/1)
  def ref_list?(_values), do: false

  def non_empty_ref_list?([_ | _] = values), do: ref_list?(values)
  def non_empty_ref_list?(_values), do: false

  def optional_timestamp?(nil), do: true
  def optional_timestamp?(%DateTime{}), do: true
  def optional_timestamp?(value), do: is_binary(value) and String.trim(value) != ""

  def positive_integer?(value), do: is_integer(value) and value > 0
  def non_negative_integer?(value), do: is_integer(value) and value >= 0

  def enum(value, allowed, _lookup) when is_atom(value) do
    if value in allowed, do: {:ok, value}, else: :error
  end

  def enum(value, _allowed, lookup) when is_binary(value), do: Map.fetch(lookup, value)
  def enum(_value, _allowed, _lookup), do: :error

  def nested(nil, _module), do: {:ok, nil}
  def nested(%module{} = value, module), do: {:ok, value}
  def nested(value, module) when is_map(value) or is_list(value), do: module.new(value)
  def nested(_value, _module), do: {:error, :invalid_nested_product_surface}

  def nested_list(values, module) when is_list(values) do
    Enum.reduce_while(values, {:ok, []}, fn value, {:ok, acc} ->
      case nested(value, module) do
        {:ok, nil} -> {:halt, {:error, :invalid_nested_product_surface}}
        {:ok, normalized} -> {:cont, {:ok, [normalized | acc]}}
        {:error, _reason} = error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, normalized} -> {:ok, Enum.reverse(normalized)}
      error -> error
    end
  end

  def nested_list(_values, _module), do: {:error, :invalid_nested_product_surface}

  def dump(%_{} = value) do
    value
    |> Map.from_struct()
    |> Dump.dump_value()
    |> Dump.drop_nil_values()
  end
end

defmodule AppKit.Core.ProductSurface.Availability do
  @moduledoc """
  Product-safe availability state.

  Degraded, unknown-outcome, and operator-required states carry stable refs.
  Unavailable reasons are a closed internal enumeration and are never converted
  from arbitrary request strings into atoms.
  """

  alias AppKit.Core.ProductSurface.Support

  @states [:available, :degraded, :unavailable, :outcome_unknown, :operator_required]
  @state_lookup Map.new(@states, &{Atom.to_string(&1), &1})
  @unavailable_reasons [
    :not_configured,
    :not_admitted,
    :not_supported,
    :owner_unavailable,
    :runtime_unavailable,
    :authority_denied,
    :cursor_expired,
    :persistence_unavailable
  ]
  @reason_lookup Map.new(@unavailable_reasons, &{Atom.to_string(&1), &1})

  @enforce_keys [:state]
  defstruct [:state, :reason_ref, :reason, :operation_ref, :task_ref]

  @type t :: %__MODULE__{
          state: :available | :degraded | :unavailable | :outcome_unknown | :operator_required,
          reason_ref: String.t() | nil,
          reason: atom() | nil,
          operation_ref: String.t() | nil,
          task_ref: String.t() | nil
        }

  def new(:available), do: {:ok, %__MODULE__{state: :available}}
  def new({:degraded, reason_ref}), do: new(%{state: :degraded, reason_ref: reason_ref})
  def new({:unavailable, reason}), do: new(%{state: :unavailable, reason: reason})

  def new({:outcome_unknown, operation_ref}),
    do: new(%{state: :outcome_unknown, operation_ref: operation_ref})

  def new({:operator_required, task_ref}),
    do: new(%{state: :operator_required, task_ref: task_ref})

  def new(attrs) do
    with {:ok, attrs} <- Support.normalize(attrs, __MODULE__),
         {:ok, state} <- Support.enum(Support.fetch(attrs, :state), @states, @state_lookup),
         {:ok, availability} <- build(state, attrs) do
      {:ok, availability}
    else
      _ -> {:error, :invalid_product_availability}
    end
  end

  def dump(%__MODULE__{} = value), do: Support.dump(value)

  defp build(:available, attrs) do
    if empty_details?(attrs), do: {:ok, %__MODULE__{state: :available}}, else: :error
  end

  defp build(:degraded, attrs) do
    reason_ref = Support.fetch(attrs, :reason_ref)

    if Support.ref?(reason_ref) do
      {:ok, %__MODULE__{state: :degraded, reason_ref: reason_ref}}
    else
      :error
    end
  end

  defp build(:unavailable, attrs) do
    with {:ok, reason} <-
           Support.enum(Support.fetch(attrs, :reason), @unavailable_reasons, @reason_lookup) do
      {:ok, %__MODULE__{state: :unavailable, reason: reason}}
    end
  end

  defp build(:outcome_unknown, attrs) do
    operation_ref = Support.fetch(attrs, :operation_ref)

    if Support.ref?(operation_ref) do
      {:ok, %__MODULE__{state: :outcome_unknown, operation_ref: operation_ref}}
    else
      :error
    end
  end

  defp build(:operator_required, attrs) do
    task_ref = Support.fetch(attrs, :task_ref)

    if Support.ref?(task_ref) do
      {:ok, %__MODULE__{state: :operator_required, task_ref: task_ref}}
    else
      :error
    end
  end

  defp empty_details?(attrs) do
    Enum.all?([:reason_ref, :reason, :operation_ref, :task_ref], fn key ->
      is_nil(Support.fetch(attrs, key))
    end)
  end
end

defmodule AppKit.Core.ProductSurface.ArtifactProjection do
  @moduledoc "Refs-only retained artifact state projected by the durable owner."

  alias AppKit.Core.ProductSurface.{Availability, Support}

  @kinds [
    :turn_input,
    :turn_output,
    :tool_input,
    :tool_output,
    :evidence,
    :context_manifest,
    :memory_snapshot,
    :execution_log
  ]
  @kind_lookup Map.new(@kinds, &{Atom.to_string(&1), &1})
  @statuses [:committed, :retained, :expired, :deleted, :unavailable]
  @status_lookup Map.new(@statuses, &{Atom.to_string(&1), &1})

  @enforce_keys [
    :artifact_ref,
    :owner_projection_ref,
    :source_contract_ref,
    :kind,
    :status,
    :retained?,
    :availability
  ]
  defstruct @enforce_keys ++
              [
                :content_ref,
                :content_hash,
                :retention_policy_ref,
                evidence_refs: [],
                lineage_refs: []
              ]

  @type t :: %__MODULE__{}

  def new(attrs) do
    with {:ok, attrs} <- Support.normalize(attrs, __MODULE__),
         artifact_ref when is_binary(artifact_ref) <- Support.fetch(attrs, :artifact_ref),
         true <- Support.ref?(artifact_ref),
         owner_projection_ref when is_binary(owner_projection_ref) <-
           Support.fetch(attrs, :owner_projection_ref),
         true <- Support.ref?(owner_projection_ref),
         source_contract_ref when is_binary(source_contract_ref) <-
           Support.fetch(attrs, :source_contract_ref),
         true <- Support.ref?(source_contract_ref),
         {:ok, kind} <- Support.enum(Support.fetch(attrs, :kind), @kinds, @kind_lookup),
         {:ok, status} <-
           Support.enum(Support.fetch(attrs, :status), @statuses, @status_lookup),
         retained? when is_boolean(retained?) <- Support.fetch(attrs, :retained?),
         content_ref <- Support.fetch(attrs, :content_ref),
         true <- Support.optional_ref?(content_ref),
         content_hash <- Support.fetch(attrs, :content_hash),
         true <- optional_hash?(content_hash),
         retention_policy_ref <- Support.fetch(attrs, :retention_policy_ref),
         true <- Support.optional_ref?(retention_policy_ref),
         evidence_refs <- Support.fetch(attrs, :evidence_refs, []),
         true <- Support.ref_list?(evidence_refs),
         lineage_refs <- Support.fetch(attrs, :lineage_refs, []),
         true <- Support.ref_list?(lineage_refs),
         {:ok, availability} <-
           Availability.new(Support.fetch(attrs, :availability, :available)),
         :ok <- coherent_retention(status, retained?, content_ref) do
      {:ok,
       %__MODULE__{
         artifact_ref: artifact_ref,
         owner_projection_ref: owner_projection_ref,
         source_contract_ref: source_contract_ref,
         kind: kind,
         status: status,
         retained?: retained?,
         availability: availability,
         content_ref: content_ref,
         content_hash: content_hash,
         retention_policy_ref: retention_policy_ref,
         evidence_refs: evidence_refs,
         lineage_refs: lineage_refs
       }}
    else
      _ -> {:error, :invalid_product_artifact_projection}
    end
  end

  def dump(%__MODULE__{} = value), do: Support.dump(value)

  defp coherent_retention(status, true, content_ref)
       when status in [:committed, :retained] and is_binary(content_ref),
       do: :ok

  defp coherent_retention(status, false, nil) when status in [:expired, :deleted, :unavailable],
    do: :ok

  defp coherent_retention(_status, _retained?, _content_ref), do: :error

  defp optional_hash?(nil), do: true

  defp optional_hash?(<<"sha256:", digest::binary-size(64)>>) do
    digest
    |> :binary.bin_to_list()
    |> Enum.all?(fn byte -> byte in ?0..?9 or byte in ?a..?f end)
  end

  defp optional_hash?(_value), do: false
end

defmodule AppKit.Core.ProductSurface.ContextProjection do
  @moduledoc """
  Immutable context and governed-memory refs used by one committed turn.
  """

  alias AppKit.Core.ProductSurface.{Availability, Support}

  @enforce_keys [
    :context_ref,
    :snapshot_ref,
    :run_ref,
    :turn_ref,
    :owner_projection_ref,
    :source_contract_ref,
    :availability
  ]
  defstruct @enforce_keys ++
              [
                :retrieval_snapshot_ref,
                :context_manifest_artifact_ref,
                working_memory_refs: [],
                episodic_memory_refs: [],
                memory_proof_refs: [],
                exclusion_refs: []
              ]

  @type t :: %__MODULE__{}

  def new(attrs) do
    with {:ok, attrs} <- Support.normalize(attrs, __MODULE__),
         {:ok, refs} <- required_refs(attrs),
         retrieval_snapshot_ref <- Support.fetch(attrs, :retrieval_snapshot_ref),
         true <- Support.optional_ref?(retrieval_snapshot_ref),
         context_manifest_artifact_ref <-
           Support.fetch(attrs, :context_manifest_artifact_ref),
         true <- Support.optional_ref?(context_manifest_artifact_ref),
         working_memory_refs <- Support.fetch(attrs, :working_memory_refs, []),
         true <- Support.ref_list?(working_memory_refs),
         episodic_memory_refs <- Support.fetch(attrs, :episodic_memory_refs, []),
         true <- Support.ref_list?(episodic_memory_refs),
         memory_proof_refs <- Support.fetch(attrs, :memory_proof_refs, []),
         true <- Support.ref_list?(memory_proof_refs),
         exclusion_refs <- Support.fetch(attrs, :exclusion_refs, []),
         true <- Support.ref_list?(exclusion_refs),
         {:ok, availability} <-
           Availability.new(Support.fetch(attrs, :availability, :available)),
         :ok <-
           require_memory_proof(
             working_memory_refs,
             episodic_memory_refs,
             memory_proof_refs
           ) do
      {:ok,
       struct!(
         __MODULE__,
         Map.merge(refs, %{
           retrieval_snapshot_ref: retrieval_snapshot_ref,
           context_manifest_artifact_ref: context_manifest_artifact_ref,
           working_memory_refs: working_memory_refs,
           episodic_memory_refs: episodic_memory_refs,
           memory_proof_refs: memory_proof_refs,
           exclusion_refs: exclusion_refs,
           availability: availability
         })
       )}
    else
      _ -> {:error, :invalid_product_context_projection}
    end
  end

  def dump(%__MODULE__{} = value), do: Support.dump(value)

  defp required_refs(attrs) do
    fields = [
      :context_ref,
      :snapshot_ref,
      :run_ref,
      :turn_ref,
      :owner_projection_ref,
      :source_contract_ref
    ]

    values = Map.new(fields, &{&1, Support.fetch(attrs, &1)})

    if Enum.all?(values, fn {_key, value} -> Support.ref?(value) end),
      do: {:ok, values},
      else: :error
  end

  defp require_memory_proof([], [], _proof_refs), do: :ok
  defp require_memory_proof(_working, _episodic, [_ | _]), do: :ok
  defp require_memory_proof(_working, _episodic, []), do: :error
end

defmodule AppKit.Core.ProductSurface.TurnProjection do
  @moduledoc "Durable model-turn projection with cursor-backed provisional streaming."

  alias AppKit.Core.AgentIntake.AgentRunCursor
  alias AppKit.Core.ProductSurface.{Availability, ContextProjection, Support}

  @states [
    :accepted,
    :contextualizing,
    :invoking,
    :streaming,
    :committing,
    :completed,
    :failed,
    :cancelled,
    :operator_required,
    :outcome_unknown
  ]
  @state_lookup Map.new(@states, &{Atom.to_string(&1), &1})

  @enforce_keys [
    :turn_ref,
    :run_ref,
    :owner_projection_ref,
    :source_contract_ref,
    :sequence,
    :state,
    :input_ref,
    :availability
  ]
  defstruct @enforce_keys ++
              [
                :output_artifact_ref,
                :stream_cursor,
                :context,
                :usage_ref,
                event_refs: [],
                artifact_refs: []
              ]

  @type t :: %__MODULE__{}

  def new(attrs) do
    with {:ok, attrs} <- Support.normalize(attrs, __MODULE__),
         {:ok, refs} <- required_refs(attrs),
         sequence <- Support.fetch(attrs, :sequence),
         true <- Support.positive_integer?(sequence),
         {:ok, state} <- Support.enum(Support.fetch(attrs, :state), @states, @state_lookup),
         output_artifact_ref <- Support.fetch(attrs, :output_artifact_ref),
         true <- Support.optional_ref?(output_artifact_ref),
         {:ok, stream_cursor} <-
           Support.nested(Support.fetch(attrs, :stream_cursor), AgentRunCursor),
         {:ok, context} <-
           Support.nested(Support.fetch(attrs, :context), ContextProjection),
         usage_ref <- Support.fetch(attrs, :usage_ref),
         true <- Support.optional_ref?(usage_ref),
         event_refs <- Support.fetch(attrs, :event_refs, []),
         true <- Support.ref_list?(event_refs),
         artifact_refs <- Support.fetch(attrs, :artifact_refs, []),
         true <- Support.ref_list?(artifact_refs),
         {:ok, availability} <-
           Availability.new(Support.fetch(attrs, :availability, :available)),
         :ok <- coherent_state(state, output_artifact_ref, stream_cursor, availability) do
      {:ok,
       struct!(
         __MODULE__,
         Map.merge(refs, %{
           sequence: sequence,
           state: state,
           output_artifact_ref: output_artifact_ref,
           stream_cursor: stream_cursor,
           context: context,
           usage_ref: usage_ref,
           event_refs: event_refs,
           artifact_refs: artifact_refs,
           availability: availability
         })
       )}
    else
      _ -> {:error, :invalid_product_turn_projection}
    end
  end

  def dump(%__MODULE__{} = value), do: Support.dump(value)

  defp required_refs(attrs) do
    fields = [:turn_ref, :run_ref, :owner_projection_ref, :source_contract_ref, :input_ref]
    values = Map.new(fields, &{&1, Support.fetch(attrs, &1)})

    if Enum.all?(values, fn {_key, value} -> Support.ref?(value) end),
      do: {:ok, values},
      else: :error
  end

  defp coherent_state(:completed, output_artifact_ref, _cursor, %Availability{state: :available})
       when is_binary(output_artifact_ref),
       do: :ok

  defp coherent_state(:streaming, _output, %AgentRunCursor{}, %Availability{state: :available}),
    do: :ok

  defp coherent_state(:operator_required, _output, _cursor, %Availability{
         state: :operator_required
       }),
       do: :ok

  defp coherent_state(:outcome_unknown, _output, _cursor, %Availability{
         state: :outcome_unknown
       }),
       do: :ok

  defp coherent_state(state, nil, _cursor, %Availability{})
       when state in [
              :accepted,
              :contextualizing,
              :invoking,
              :committing,
              :failed,
              :cancelled
            ],
       do: :ok

  defp coherent_state(_state, _output, _cursor, _availability), do: :error
end

defmodule AppKit.Core.ProductSurface.ReviewProjection do
  @moduledoc "Durable review state and the actions currently admitted for the actor."

  alias AppKit.Core.ProductSurface.{Availability, Support}

  @statuses [:pending, :approved, :rejected, :amended, :expired, :cancelled]
  @status_lookup Map.new(@statuses, &{Atom.to_string(&1), &1})
  @actions [:approve, :reject, :amend]
  @action_lookup Map.new(@actions, &{Atom.to_string(&1), &1})

  @enforce_keys [
    :review_ref,
    :effect_ref,
    :owner_projection_ref,
    :source_contract_ref,
    :status,
    :row_version,
    :availability
  ]
  defstruct @enforce_keys ++
              [:decision_ref, :expires_at, allowed_actions: [], obligation_refs: []]

  @type t :: %__MODULE__{}

  def new(attrs) do
    with {:ok, attrs} <- Support.normalize(attrs, __MODULE__),
         {:ok, refs} <- required_refs(attrs),
         {:ok, status} <-
           Support.enum(Support.fetch(attrs, :status), @statuses, @status_lookup),
         row_version <- Support.fetch(attrs, :row_version),
         true <- Support.positive_integer?(row_version),
         decision_ref <- Support.fetch(attrs, :decision_ref),
         true <- Support.optional_ref?(decision_ref),
         expires_at <- Support.fetch(attrs, :expires_at),
         true <- Support.optional_timestamp?(expires_at),
         {:ok, allowed_actions} <- normalize_actions(Support.fetch(attrs, :allowed_actions, [])),
         obligation_refs <- Support.fetch(attrs, :obligation_refs, []),
         true <- Support.ref_list?(obligation_refs),
         {:ok, availability} <-
           Availability.new(Support.fetch(attrs, :availability, :available)),
         :ok <- coherent_state(status, decision_ref, allowed_actions, availability) do
      {:ok,
       struct!(
         __MODULE__,
         Map.merge(refs, %{
           status: status,
           row_version: row_version,
           decision_ref: decision_ref,
           expires_at: expires_at,
           allowed_actions: allowed_actions,
           obligation_refs: obligation_refs,
           availability: availability
         })
       )}
    else
      _ -> {:error, :invalid_product_review_projection}
    end
  end

  def dump(%__MODULE__{} = value), do: Support.dump(value)

  defp required_refs(attrs) do
    fields = [:review_ref, :effect_ref, :owner_projection_ref, :source_contract_ref]
    values = Map.new(fields, &{&1, Support.fetch(attrs, &1)})

    if Enum.all?(values, fn {_key, value} -> Support.ref?(value) end),
      do: {:ok, values},
      else: :error
  end

  defp normalize_actions(actions) when is_list(actions) do
    Enum.reduce_while(actions, {:ok, []}, fn action, {:ok, acc} ->
      case Support.enum(action, @actions, @action_lookup) do
        {:ok, normalized} -> {:cont, {:ok, [normalized | acc]}}
        _ -> {:halt, :error}
      end
    end)
    |> case do
      {:ok, normalized} -> {:ok, normalized |> Enum.reverse() |> Enum.uniq()}
      _ -> :error
    end
  end

  defp normalize_actions(_actions), do: :error

  defp coherent_state(:pending, nil, [_ | _], %Availability{state: :available}), do: :ok

  defp coherent_state(status, decision_ref, [], %Availability{})
       when status in [:approved, :rejected, :amended] and is_binary(decision_ref),
       do: :ok

  defp coherent_state(status, _decision_ref, [], %Availability{})
       when status in [:expired, :cancelled],
       do: :ok

  defp coherent_state(_status, _decision_ref, _allowed_actions, _availability), do: :error
end

defmodule AppKit.Core.ProductSurface.OperationProjection do
  @moduledoc "Durable execution/effect operation state with explicit ambiguity."

  alias AppKit.Core.ProductSurface.{Availability, Support}

  @kinds [:model_invocation, :tool_effect, :connector_effect, :execution, :reconciliation]
  @kind_lookup Map.new(@kinds, &{Atom.to_string(&1), &1})
  @states [
    :accepted,
    :running,
    :waiting_review,
    :completed,
    :failed,
    :cancelled,
    :outcome_unknown,
    :operator_required
  ]
  @state_lookup Map.new(@states, &{Atom.to_string(&1), &1})

  @enforce_keys [
    :operation_ref,
    :run_ref,
    :owner_projection_ref,
    :source_contract_ref,
    :kind,
    :state,
    :attempt_ref,
    :availability
  ]
  defstruct @enforce_keys ++
              [
                :turn_ref,
                :external_operation_ref,
                :receipt_ref,
                :review_ref,
                :operator_task_ref,
                artifact_refs: [],
                evidence_refs: []
              ]

  @type t :: %__MODULE__{}

  def new(attrs) do
    with {:ok, attrs} <- Support.normalize(attrs, __MODULE__),
         {:ok, refs} <- required_refs(attrs),
         {:ok, kind} <- Support.enum(Support.fetch(attrs, :kind), @kinds, @kind_lookup),
         {:ok, state} <- Support.enum(Support.fetch(attrs, :state), @states, @state_lookup),
         turn_ref <- Support.fetch(attrs, :turn_ref),
         true <- Support.optional_ref?(turn_ref),
         external_operation_ref <- Support.fetch(attrs, :external_operation_ref),
         true <- Support.optional_ref?(external_operation_ref),
         receipt_ref <- Support.fetch(attrs, :receipt_ref),
         true <- Support.optional_ref?(receipt_ref),
         review_ref <- Support.fetch(attrs, :review_ref),
         true <- Support.optional_ref?(review_ref),
         operator_task_ref <- Support.fetch(attrs, :operator_task_ref),
         true <- Support.optional_ref?(operator_task_ref),
         artifact_refs <- Support.fetch(attrs, :artifact_refs, []),
         true <- Support.ref_list?(artifact_refs),
         evidence_refs <- Support.fetch(attrs, :evidence_refs, []),
         true <- Support.ref_list?(evidence_refs),
         {:ok, availability} <-
           Availability.new(Support.fetch(attrs, :availability, :available)),
         :ok <-
           coherent_state(
             state,
             refs.operation_ref,
             receipt_ref,
             review_ref,
             operator_task_ref,
             availability
           ) do
      {:ok,
       struct!(
         __MODULE__,
         Map.merge(refs, %{
           kind: kind,
           state: state,
           turn_ref: turn_ref,
           external_operation_ref: external_operation_ref,
           receipt_ref: receipt_ref,
           review_ref: review_ref,
           operator_task_ref: operator_task_ref,
           artifact_refs: artifact_refs,
           evidence_refs: evidence_refs,
           availability: availability
         })
       )}
    else
      _ -> {:error, :invalid_product_operation_projection}
    end
  end

  def dump(%__MODULE__{} = value), do: Support.dump(value)

  defp required_refs(attrs) do
    fields = [
      :operation_ref,
      :run_ref,
      :owner_projection_ref,
      :source_contract_ref,
      :attempt_ref
    ]

    values = Map.new(fields, &{&1, Support.fetch(attrs, &1)})

    if Enum.all?(values, fn {_key, value} -> Support.ref?(value) end),
      do: {:ok, values},
      else: :error
  end

  defp coherent_state(:completed, _operation_ref, receipt_ref, _review, _task, %Availability{
         state: :available
       })
       when is_binary(receipt_ref),
       do: :ok

  defp coherent_state(:waiting_review, _operation_ref, _receipt, review_ref, _task, %Availability{
         state: :available
       })
       when is_binary(review_ref),
       do: :ok

  defp coherent_state(
         :outcome_unknown,
         operation_ref,
         _receipt,
         _review,
         _task,
         %Availability{state: :outcome_unknown, operation_ref: operation_ref}
       ),
       do: :ok

  defp coherent_state(
         :operator_required,
         _operation_ref,
         _receipt,
         _review,
         task_ref,
         %Availability{state: :operator_required, task_ref: task_ref}
       )
       when is_binary(task_ref),
       do: :ok

  defp coherent_state(state, _operation_ref, nil, nil, nil, %Availability{})
       when state in [:accepted, :running, :failed, :cancelled],
       do: :ok

  defp coherent_state(_state, _operation_ref, _receipt, _review, _task, _availability), do: :error
end

defmodule AppKit.Core.ProductSurface.ControlProjection do
  @moduledoc "Optimistically versioned durable run-control state."

  alias AppKit.Core.ProductSurface.{Availability, Support}

  @states [
    :accepted,
    :running,
    :pause_requested,
    :paused,
    :resume_requested,
    :failed,
    :cancelled,
    :completed,
    :operator_required,
    :outcome_unknown,
    :reconciling
  ]
  @state_lookup Map.new(@states, &{Atom.to_string(&1), &1})
  @actions [:pause, :resume, :cancel, :retry, :supersede]
  @action_lookup Map.new(@actions, &{Atom.to_string(&1), &1})
  @allowed_by_state %{
    accepted: [:cancel, :supersede],
    running: [:pause, :cancel, :supersede],
    pause_requested: [:cancel],
    paused: [:resume, :cancel, :supersede],
    resume_requested: [:cancel],
    failed: [:retry, :supersede],
    cancelled: [],
    completed: [],
    operator_required: [:retry, :cancel, :supersede],
    outcome_unknown: [],
    reconciling: []
  }

  @enforce_keys [
    :run_ref,
    :owner_projection_ref,
    :source_contract_ref,
    :row_version,
    :state,
    :available_actions,
    :availability
  ]
  defstruct @enforce_keys ++
              [:external_operation_ref, :operator_task_ref, :deadline_at, :terminal_receipt_ref]

  @type t :: %__MODULE__{}

  def new(attrs) do
    with {:ok, attrs} <- Support.normalize(attrs, __MODULE__),
         {:ok, refs} <- required_refs(attrs),
         row_version <- Support.fetch(attrs, :row_version),
         true <- Support.positive_integer?(row_version),
         {:ok, state} <- Support.enum(Support.fetch(attrs, :state), @states, @state_lookup),
         {:ok, available_actions} <-
           normalize_actions(Support.fetch(attrs, :available_actions, [])),
         true <- actions_allowed?(state, available_actions),
         external_operation_ref <- Support.fetch(attrs, :external_operation_ref),
         true <- Support.optional_ref?(external_operation_ref),
         operator_task_ref <- Support.fetch(attrs, :operator_task_ref),
         true <- Support.optional_ref?(operator_task_ref),
         deadline_at <- Support.fetch(attrs, :deadline_at),
         true <- Support.optional_timestamp?(deadline_at),
         terminal_receipt_ref <- Support.fetch(attrs, :terminal_receipt_ref),
         true <- Support.optional_ref?(terminal_receipt_ref),
         {:ok, availability} <-
           Availability.new(Support.fetch(attrs, :availability, :available)),
         :ok <-
           coherent_state(
             state,
             external_operation_ref,
             operator_task_ref,
             terminal_receipt_ref,
             availability
           ) do
      {:ok,
       struct!(
         __MODULE__,
         Map.merge(refs, %{
           row_version: row_version,
           state: state,
           available_actions: available_actions,
           external_operation_ref: external_operation_ref,
           operator_task_ref: operator_task_ref,
           deadline_at: deadline_at,
           terminal_receipt_ref: terminal_receipt_ref,
           availability: availability
         })
       )}
    else
      _ -> {:error, :invalid_product_control_projection}
    end
  end

  def dump(%__MODULE__{} = value), do: Support.dump(value)

  defp required_refs(attrs) do
    fields = [:run_ref, :owner_projection_ref, :source_contract_ref]
    values = Map.new(fields, &{&1, Support.fetch(attrs, &1)})

    if Enum.all?(values, fn {_key, value} -> Support.ref?(value) end),
      do: {:ok, values},
      else: :error
  end

  defp normalize_actions(actions) when is_list(actions) do
    Enum.reduce_while(actions, {:ok, []}, fn action, {:ok, acc} ->
      case Support.enum(action, @actions, @action_lookup) do
        {:ok, normalized} -> {:cont, {:ok, [normalized | acc]}}
        _ -> {:halt, :error}
      end
    end)
    |> case do
      {:ok, normalized} -> {:ok, normalized |> Enum.reverse() |> Enum.uniq()}
      _ -> :error
    end
  end

  defp normalize_actions(_actions), do: :error

  defp actions_allowed?(state, actions) do
    allowed = Map.fetch!(@allowed_by_state, state)
    Enum.all?(actions, &(&1 in allowed))
  end

  defp coherent_state(:outcome_unknown, operation_ref, nil, nil, %Availability{
         state: :outcome_unknown,
         operation_ref: operation_ref
       })
       when is_binary(operation_ref),
       do: :ok

  defp coherent_state(:operator_required, _operation_ref, task_ref, nil, %Availability{
         state: :operator_required,
         task_ref: task_ref
       })
       when is_binary(task_ref),
       do: :ok

  defp coherent_state(state, _operation_ref, nil, terminal_receipt_ref, %Availability{})
       when state in [:cancelled, :completed] and is_binary(terminal_receipt_ref),
       do: :ok

  defp coherent_state(state, _operation_ref, nil, nil, %Availability{})
       when state in [
              :accepted,
              :running,
              :pause_requested,
              :paused,
              :resume_requested,
              :failed,
              :reconciling
            ],
       do: :ok

  defp coherent_state(_state, _operation_ref, _task, _receipt, _availability), do: :error
end

defmodule AppKit.Core.ProductSurface.CapabilityProjection do
  @moduledoc """
  Executable capability truth.

  Degraded or absent entries may be shown in operator views, but they cannot be
  advertised in product action catalogs.
  """

  alias AppKit.Core.ProductSurface.{Availability, Support}

  @kinds [:model, :tool, :connector, :execution_lane, :memory, :review, :control]
  @kind_lookup Map.new(@kinds, &{Atom.to_string(&1), &1})
  @modes [:durable_owner, :local_effect, :runtime_admitted]
  @mode_lookup Map.new(@modes, &{Atom.to_string(&1), &1})

  @enforce_keys [
    :capability_ref,
    :owner_projection_ref,
    :source_contract_ref,
    :producer_revision_ref,
    :contract_version,
    :kind,
    :configured_mode,
    :advertised?,
    :availability
  ]
  defstruct @enforce_keys ++ [:health_ref, operation_refs: [], scope_refs: []]

  @type t :: %__MODULE__{}

  def new(attrs) do
    with {:ok, attrs} <- Support.normalize(attrs, __MODULE__),
         {:ok, refs} <- required_refs(attrs),
         contract_version <- Support.fetch(attrs, :contract_version),
         true <- is_binary(contract_version) and String.trim(contract_version) != "",
         {:ok, kind} <- Support.enum(Support.fetch(attrs, :kind), @kinds, @kind_lookup),
         {:ok, configured_mode} <-
           Support.enum(Support.fetch(attrs, :configured_mode), @modes, @mode_lookup),
         advertised? when is_boolean(advertised?) <- Support.fetch(attrs, :advertised?),
         health_ref <- Support.fetch(attrs, :health_ref),
         true <- Support.optional_ref?(health_ref),
         operation_refs <- Support.fetch(attrs, :operation_refs, []),
         true <- Support.ref_list?(operation_refs),
         scope_refs <- Support.fetch(attrs, :scope_refs, []),
         true <- Support.ref_list?(scope_refs),
         {:ok, availability} <-
           Availability.new(Support.fetch(attrs, :availability, :available)),
         :ok <- coherent_catalog(advertised?, operation_refs, availability) do
      {:ok,
       struct!(
         __MODULE__,
         Map.merge(refs, %{
           contract_version: contract_version,
           kind: kind,
           configured_mode: configured_mode,
           advertised?: advertised?,
           health_ref: health_ref,
           operation_refs: operation_refs,
           scope_refs: scope_refs,
           availability: availability
         })
       )}
    else
      _ -> {:error, :invalid_product_capability_projection}
    end
  end

  def dump(%__MODULE__{} = value), do: Support.dump(value)

  defp required_refs(attrs) do
    fields = [
      :capability_ref,
      :owner_projection_ref,
      :source_contract_ref,
      :producer_revision_ref
    ]

    values = Map.new(fields, &{&1, Support.fetch(attrs, &1)})

    if Enum.all?(values, fn {_key, value} -> Support.ref?(value) end),
      do: {:ok, values},
      else: :error
  end

  defp coherent_catalog(true, [_ | _], %Availability{state: :available}), do: :ok
  defp coherent_catalog(false, _operation_refs, %Availability{}), do: :ok
  defp coherent_catalog(_advertised?, _operation_refs, _availability), do: :error
end

defmodule AppKit.Core.ProductSurface.RunProjection do
  @moduledoc """
  Composite durable run snapshot for product presentation and cursor recovery.
  """

  alias AppKit.Core.AgentIntake.{AgentRunCursor, AgentRunEvent}

  alias AppKit.Core.ProductSurface.{
    ArtifactProjection,
    Availability,
    CapabilityProjection,
    ContextProjection,
    ControlProjection,
    OperationProjection,
    ReviewProjection,
    Support,
    TurnProjection
  }

  @states [
    :accepted,
    :running,
    :paused,
    :waiting_review,
    :completed,
    :failed,
    :cancelled,
    :operator_required,
    :outcome_unknown,
    :reconciling
  ]
  @state_lookup Map.new(@states, &{Atom.to_string(&1), &1})

  @enforce_keys [
    :run_ref,
    :subject_ref,
    :owner_projection_ref,
    :source_contract_ref,
    :state,
    :updated_at,
    :cursor,
    :control,
    :persistence_posture,
    :availability
  ]
  defstruct @enforce_keys ++
              [
                :workflow_ref,
                :context,
                turns: [],
                events: [],
                reviews: [],
                artifacts: [],
                operations: [],
                capabilities: []
              ]

  @type t :: %__MODULE__{}

  def new(attrs) do
    with {:ok, attrs} <- Support.normalize(attrs, __MODULE__),
         {:ok, refs} <- required_refs(attrs),
         workflow_ref <- Support.fetch(attrs, :workflow_ref),
         true <- Support.optional_ref?(workflow_ref),
         {:ok, state} <- Support.enum(Support.fetch(attrs, :state), @states, @state_lookup),
         updated_at <- Support.fetch(attrs, :updated_at),
         true <- Support.optional_timestamp?(updated_at) and not is_nil(updated_at),
         {:ok, cursor} <- Support.nested(Support.fetch(attrs, :cursor), AgentRunCursor),
         false <- is_nil(cursor),
         {:ok, control} <-
           Support.nested(Support.fetch(attrs, :control), ControlProjection),
         false <- is_nil(control),
         {:ok, context} <-
           Support.nested(Support.fetch(attrs, :context), ContextProjection),
         {:ok, turns} <-
           Support.nested_list(Support.fetch(attrs, :turns, []), TurnProjection),
         {:ok, events} <-
           Support.nested_list(Support.fetch(attrs, :events, []), AgentRunEvent),
         {:ok, reviews} <-
           Support.nested_list(Support.fetch(attrs, :reviews, []), ReviewProjection),
         {:ok, artifacts} <-
           Support.nested_list(Support.fetch(attrs, :artifacts, []), ArtifactProjection),
         {:ok, operations} <-
           Support.nested_list(Support.fetch(attrs, :operations, []), OperationProjection),
         {:ok, capabilities} <-
           Support.nested_list(
             Support.fetch(attrs, :capabilities, []),
             CapabilityProjection
           ),
         persistence_posture <- Support.fetch(attrs, :persistence_posture),
         true <- durable_posture?(persistence_posture),
         {:ok, availability} <-
           Availability.new(Support.fetch(attrs, :availability, :available)),
         :ok <- coherent_state(state, control, availability) do
      {:ok,
       struct!(
         __MODULE__,
         Map.merge(refs, %{
           workflow_ref: workflow_ref,
           state: state,
           updated_at: updated_at,
           cursor: cursor,
           control: control,
           context: context,
           turns: Enum.sort_by(turns, & &1.sequence),
           events: Enum.sort_by(events, & &1.event_seq),
           reviews: reviews,
           artifacts: artifacts,
           operations: operations,
           capabilities: capabilities,
           persistence_posture: persistence_posture,
           availability: availability
         })
       )}
    else
      _ -> {:error, :invalid_product_run_projection}
    end
  end

  def dump(%__MODULE__{} = value), do: Support.dump(value)

  defp required_refs(attrs) do
    fields = [:run_ref, :subject_ref, :owner_projection_ref, :source_contract_ref]
    values = Map.new(fields, &{&1, Support.fetch(attrs, &1)})

    if Enum.all?(values, fn {_key, value} -> Support.ref?(value) end),
      do: {:ok, values},
      else: :error
  end

  defp durable_posture?(posture) when is_map(posture),
    do: Map.get(posture, :durable?, Map.get(posture, "durable?")) == true

  defp durable_posture?(_posture), do: false

  defp coherent_state(
         :operator_required,
         %ControlProjection{state: :operator_required},
         %Availability{
           state: :operator_required
         }
       ),
       do: :ok

  defp coherent_state(
         :outcome_unknown,
         %ControlProjection{state: :outcome_unknown},
         %Availability{
           state: :outcome_unknown
         }
       ),
       do: :ok

  defp coherent_state(state, %ControlProjection{state: state}, %Availability{})
       when state in [
              :accepted,
              :running,
              :paused,
              :completed,
              :failed,
              :cancelled,
              :reconciling
            ],
       do: :ok

  defp coherent_state(:waiting_review, %ControlProjection{}, %Availability{state: :available}),
    do: :ok

  defp coherent_state(_state, _control, _availability), do: :error
end
