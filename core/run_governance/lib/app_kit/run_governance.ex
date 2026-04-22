defmodule AppKit.RunGovernance do
  @moduledoc """
  Reusable evidence and decision helpers for governed runs.
  """

  @governed_agent_workload_contract "GovernedAgentWorkloadContract.v1"
  @scale_pressure_profile_contract "ScalePressureProfile.v1"
  @canonical_ingress "app_kit_operator_surface_via_mezzanine_bridge"
  @operator_script_driver "operator_script_in_app_kit"
  @coding_operations_work_class "extravaganza/work_classes/coding_operations"
  @coding_task_subject_kind "coding_task"
  @pack_ref_prefix "mezzanine/packs/extravaganza_coding_ops"
  @review_gate_skip_refs ["skip", "skipped", "review_gate_skipped_for_speed"]
  @bare_asm_driver_refs ["task_async_stream_of_asm_calls", "bare_asm_calls"]
  @lifecycle_states [
    :submitted,
    :retry_submission,
    :awaiting_review,
    :completed,
    :rejected,
    :expired
  ]
  @required_workload_fields [
    :profile_id,
    :ingress_ref,
    :work_class_ref,
    :pack_ref,
    :subject_kind,
    :lifecycle_states,
    :review_gate_ref,
    :tenant_count,
    :agent_count,
    :runs_per_agent,
    :max_concurrency,
    :synthetic_operator_driver_ref
  ]

  defmodule Evidence do
    @moduledoc """
    Host-visible review evidence descriptor for governed runs.
    """

    @enforce_keys [:kind, :summary]
    defstruct [:kind, :summary, details: %{}]

    @type t :: %__MODULE__{
            kind: atom(),
            summary: String.t(),
            details: map()
          }
  end

  defmodule Decision do
    @moduledoc """
    Host-visible review decision descriptor for governed runs.
    """

    @enforce_keys [:run_id, :state]
    defstruct [:run_id, :state, reason: nil]

    @type state :: :approved | :needs_changes

    @type t :: %__MODULE__{
            run_id: String.t(),
            state: state(),
            reason: String.t() | nil
          }
  end

  defmodule GovernedAgentWorkload do
    @moduledoc """
    AppKit-owned contract descriptor for the M5 governed agent workload.

    Contract: `GovernedAgentWorkloadContract.v1`.
    """

    @enforce_keys [
      :contract_name,
      :profile_id,
      :ingress_ref,
      :work_class_ref,
      :pack_ref,
      :subject_kind,
      :lifecycle_states,
      :review_gate_ref,
      :tenant_count,
      :agent_count,
      :runs_per_agent,
      :max_concurrency,
      :synthetic_operator_driver_ref
    ]
    defstruct [
      :contract_name,
      :workload_ref,
      :profile_id,
      :ingress_ref,
      :work_class_ref,
      :pack_ref,
      :subject_kind,
      :lifecycle_states,
      :review_gate_ref,
      :tenant_count,
      :agent_count,
      :runs_per_agent,
      :max_concurrency,
      :synthetic_operator_driver_ref
    ]

    @type lifecycle_state ::
            :submitted
            | :retry_submission
            | :awaiting_review
            | :completed
            | :rejected
            | :expired

    @type t :: %__MODULE__{
            contract_name: String.t(),
            workload_ref: String.t() | nil,
            profile_id: String.t(),
            ingress_ref: String.t(),
            work_class_ref: String.t(),
            pack_ref: String.t(),
            subject_kind: String.t(),
            lifecycle_states: [lifecycle_state()],
            review_gate_ref: String.t(),
            tenant_count: pos_integer(),
            agent_count: pos_integer(),
            runs_per_agent: pos_integer(),
            max_concurrency: pos_integer(),
            synthetic_operator_driver_ref: String.t()
          }
  end

  @spec evidence(map() | keyword()) :: {:ok, Evidence.t()} | {:error, atom()}
  def evidence(attrs) do
    attrs = Map.new(attrs)

    with kind when is_atom(kind) <- Map.get(attrs, :kind),
         summary when is_binary(summary) <- Map.get(attrs, :summary) do
      {:ok, %Evidence{kind: kind, summary: summary, details: Map.get(attrs, :details, %{})}}
    else
      _ -> {:error, :invalid_evidence}
    end
  end

  @spec decision(map() | keyword()) :: {:ok, Decision.t()} | {:error, atom()}
  def decision(attrs) do
    attrs = Map.new(attrs)
    state = Map.get(attrs, :state)

    with run_id when is_binary(run_id) <- Map.get(attrs, :run_id),
         true <- state in [:approved, :needs_changes] do
      {:ok, %Decision{run_id: run_id, state: state, reason: Map.get(attrs, :reason)}}
    else
      _ -> {:error, :invalid_decision}
    end
  end

  @spec review_state(Evidence.t(), keyword()) :: Decision.state()
  def review_state(%Evidence{} = evidence, opts \\ []) do
    cond do
      Keyword.get(opts, :force_needs_changes, false) -> :needs_changes
      evidence.kind in [:risk_notice, :policy_gap] -> :needs_changes
      true -> :approved
    end
  end

  @spec governed_agent_workload(map() | keyword()) ::
          {:ok, GovernedAgentWorkload.t()}
          | {:error, atom() | {:missing_required_fields, [atom()]}}
  def governed_agent_workload(attrs) do
    attrs = Map.new(attrs)

    with [] <- missing_required_workload_fields(attrs),
         :ok <- reject_bare_asm_workload(attrs),
         :ok <- validate_review_gate(attrs),
         :ok <- validate_operator_driver(attrs),
         :ok <- validate_canonical_ingress(attrs),
         :ok <- validate_extravaganza_pack_subject(attrs),
         {:ok, lifecycle_states} <- normalize_lifecycle_states(Map.get(attrs, :lifecycle_states)),
         :ok <- validate_scale_shape(attrs) do
      {:ok, build_governed_agent_workload(attrs, lifecycle_states)}
    else
      fields when is_list(fields) -> {:error, {:missing_required_fields, fields}}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec operator_script(GovernedAgentWorkload.t()) :: [map()]
  def operator_script(%GovernedAgentWorkload{} = workload) do
    [
      %{
        state: :submitted,
        surface: :app_kit_work_control,
        action: :start_run,
        ingress_ref: workload.ingress_ref
      },
      %{
        state: :awaiting_review,
        surface: :app_kit_review_surface,
        action: :list_pending,
        review_gate_ref: workload.review_gate_ref
      },
      %{
        state: :completed,
        surface: :app_kit_operator_surface,
        action: :review_run,
        operator_decision: :accept
      }
    ]
  end

  @spec lifecycle_transition_paths(GovernedAgentWorkload.t()) :: map()
  def lifecycle_transition_paths(%GovernedAgentWorkload{}) do
    %{
      happy_path: [:submitted, :awaiting_review, :completed],
      retry_path: [
        :submitted,
        :retry_submission,
        :submitted,
        :awaiting_review,
        :completed
      ],
      rejection_path: [:submitted, :awaiting_review, :rejected],
      expiry_path: [:submitted, :awaiting_review, :expired]
    }
  end

  @spec scale_pressure_seed(GovernedAgentWorkload.t()) :: map()
  def scale_pressure_seed(%GovernedAgentWorkload{} = workload) do
    %{
      contract_name: @scale_pressure_profile_contract,
      workload_contract_ref: @governed_agent_workload_contract,
      workload_ref: workload.workload_ref,
      profile_id: workload.profile_id,
      tenant_count: workload.tenant_count,
      agents_per_tenant: workload.agent_count,
      work_items_per_agent: workload.runs_per_agent,
      max_concurrency: workload.max_concurrency
    }
  end

  defp missing_required_workload_fields(attrs) do
    Enum.filter(@required_workload_fields, fn field ->
      missing_workload_field?(Map.get(attrs, field))
    end)
  end

  defp missing_workload_field?(value) when is_binary(value), do: String.trim(value) == ""
  defp missing_workload_field?(value), do: value in [nil, []]

  defp reject_bare_asm_workload(attrs) do
    if bare_asm_workload?(attrs),
      do: {:error, :bare_asm_workload_forbidden},
      else: :ok
  end

  defp bare_asm_workload?(attrs) do
    Map.get(attrs, :execution_mode) in [:bare_asm_calls, "bare_asm_calls"] or
      Map.get(attrs, :driver) in [:task_async_stream, "task_async_stream"] or
      Map.get(attrs, :task_async_stream?) == true or
      Map.get(attrs, :synthetic_operator_driver_ref) in @bare_asm_driver_refs
  end

  defp validate_review_gate(attrs) do
    cond do
      Map.get(attrs, :review_gate_skipped?) == true ->
        {:error, :review_gate_required}

      Map.get(attrs, :review_gate_ref) in @review_gate_skip_refs ->
        {:error, :review_gate_required}

      true ->
        :ok
    end
  end

  defp validate_operator_driver(attrs) do
    if Map.get(attrs, :synthetic_operator_driver_ref) == @operator_script_driver,
      do: :ok,
      else: {:error, :invalid_operator_driver}
  end

  defp validate_canonical_ingress(attrs) do
    if Map.get(attrs, :ingress_ref) == @canonical_ingress,
      do: :ok,
      else: {:error, :invalid_governed_ingress}
  end

  defp validate_extravaganza_pack_subject(attrs) do
    pack_ref = Map.get(attrs, :pack_ref)

    cond do
      Map.get(attrs, :work_class_ref) != @coding_operations_work_class ->
        {:error, :invalid_work_class_ref}

      Map.get(attrs, :subject_kind) != @coding_task_subject_kind ->
        {:error, :invalid_subject_kind}

      not is_binary(pack_ref) or not String.starts_with?(pack_ref, @pack_ref_prefix) ->
        {:error, :invalid_pack_ref}

      true ->
        :ok
    end
  end

  defp normalize_lifecycle_states(states) when is_list(states) do
    normalized = Enum.map(states, &normalize_lifecycle_state/1)

    if normalized == @lifecycle_states and Enum.all?(normalized, &is_atom/1),
      do: {:ok, normalized},
      else: {:error, :invalid_lifecycle_states}
  end

  defp normalize_lifecycle_states(_states), do: {:error, :invalid_lifecycle_states}

  defp normalize_lifecycle_state(state) when state in @lifecycle_states, do: state

  defp normalize_lifecycle_state(state) when is_binary(state) do
    Enum.find(@lifecycle_states, fn lifecycle_state ->
      Atom.to_string(lifecycle_state) == state
    end)
  end

  defp normalize_lifecycle_state(_state), do: nil

  defp validate_scale_shape(attrs) do
    tenant_count = Map.get(attrs, :tenant_count)
    agent_count = Map.get(attrs, :agent_count)
    runs_per_agent = Map.get(attrs, :runs_per_agent)
    max_concurrency = Map.get(attrs, :max_concurrency)

    if Enum.all?(
         [tenant_count, agent_count, runs_per_agent, max_concurrency],
         &positive_integer?/1
       ) and
         max_concurrency <= tenant_count * agent_count * runs_per_agent,
       do: :ok,
       else: {:error, :invalid_scale_pressure_shape}
  end

  defp build_governed_agent_workload(attrs, lifecycle_states) do
    %GovernedAgentWorkload{
      contract_name: @governed_agent_workload_contract,
      workload_ref: Map.get(attrs, :workload_ref),
      profile_id: Map.fetch!(attrs, :profile_id),
      ingress_ref: Map.fetch!(attrs, :ingress_ref),
      work_class_ref: Map.fetch!(attrs, :work_class_ref),
      pack_ref: Map.fetch!(attrs, :pack_ref),
      subject_kind: Map.fetch!(attrs, :subject_kind),
      lifecycle_states: lifecycle_states,
      review_gate_ref: Map.fetch!(attrs, :review_gate_ref),
      tenant_count: Map.fetch!(attrs, :tenant_count),
      agent_count: Map.fetch!(attrs, :agent_count),
      runs_per_agent: Map.fetch!(attrs, :runs_per_agent),
      max_concurrency: Map.fetch!(attrs, :max_concurrency),
      synthetic_operator_driver_ref: Map.fetch!(attrs, :synthetic_operator_driver_ref)
    }
  end

  defp positive_integer?(value), do: is_integer(value) and value > 0
end
