defmodule AppKit.RunGovernanceTest do
  use ExUnit.Case, async: true

  alias AppKit.RunGovernance

  test "builds evidence and a decision state" do
    assert {:ok, evidence} =
             RunGovernance.evidence(%{kind: :operator_note, summary: "looks good"})

    assert RunGovernance.review_state(evidence) == :approved
    assert {:ok, decision} = RunGovernance.decision(%{run_id: "run-1", state: :approved})
    assert decision.state == :approved
  end

  test "builds governed AppKit operator workload contract and script" do
    assert {:ok, workload} = RunGovernance.governed_agent_workload(valid_workload_attrs())

    assert workload.contract_name == "GovernedAgentWorkloadContract.v1"
    assert workload.ingress_ref == "app_kit_operator_surface_via_mezzanine_bridge"
    assert workload.synthetic_operator_driver_ref == "operator_script_in_app_kit"
    assert workload.work_class_ref == "extravaganza/work_classes/coding_operations"
    assert workload.pack_ref == "mezzanine/packs/extravaganza_coding_ops@1"
    assert workload.subject_kind == "coding_task"

    assert workload.lifecycle_states == [
             :submitted,
             :retry_submission,
             :awaiting_review,
             :completed,
             :rejected,
             :expired
           ]

    assert RunGovernance.operator_script(workload) == [
             %{
               state: :submitted,
               surface: :app_kit_work_control,
               action: :start_run,
               ingress_ref: "app_kit_operator_surface_via_mezzanine_bridge"
             },
             %{
               state: :awaiting_review,
               surface: :app_kit_review_surface,
               action: :list_pending,
               review_gate_ref: "extravaganza/review_gates/operator_review"
             },
             %{
               state: :completed,
               surface: :app_kit_operator_surface,
               action: :review_run,
               operator_decision: :accept
             }
           ]
  end

  test "rejects workloads that skip the review gate" do
    assert {:error, :review_gate_required} =
             RunGovernance.governed_agent_workload(
               Map.put(valid_workload_attrs(), :review_gate_skipped?, true)
             )

    assert {:error, {:missing_required_fields, [:review_gate_ref]}} =
             RunGovernance.governed_agent_workload(
               Map.delete(valid_workload_attrs(), :review_gate_ref)
             )
  end

  test "rejects bare ASM calls as a substitute workload driver" do
    assert {:error, :bare_asm_workload_forbidden} =
             RunGovernance.governed_agent_workload(
               Map.merge(valid_workload_attrs(), %{
                 synthetic_operator_driver_ref: "task_async_stream_of_asm_calls",
                 driver: :task_async_stream,
                 execution_mode: :bare_asm_calls
               })
             )
  end

  test "records governed lifecycle transition and rejection paths" do
    assert {:ok, workload} = RunGovernance.governed_agent_workload(valid_workload_attrs())

    assert RunGovernance.lifecycle_transition_paths(workload) == %{
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

  test "exports the M5 tenant agent shape as an M11 scale-pressure seed" do
    assert {:ok, workload} =
             RunGovernance.governed_agent_workload(
               Map.merge(valid_workload_attrs(), %{
                 tenant_count: 2,
                 agent_count: 3,
                 runs_per_agent: 5,
                 max_concurrency: 4
               })
             )

    assert RunGovernance.scale_pressure_seed(workload) == %{
             contract_name: "ScalePressureProfile.v1",
             workload_contract_ref: "GovernedAgentWorkloadContract.v1",
             workload_ref: "workloads/extravaganza-coding-ops",
             profile_id: "profiles/extravaganza/local_default",
             tenant_count: 2,
             agents_per_tenant: 3,
             work_items_per_agent: 5,
             max_concurrency: 4
           }
  end

  defp valid_workload_attrs do
    %{
      workload_ref: "workloads/extravaganza-coding-ops",
      profile_id: "profiles/extravaganza/local_default",
      ingress_ref: "app_kit_operator_surface_via_mezzanine_bridge",
      work_class_ref: "extravaganza/work_classes/coding_operations",
      pack_ref: "mezzanine/packs/extravaganza_coding_ops@1",
      subject_kind: "coding_task",
      lifecycle_states: [
        :submitted,
        :retry_submission,
        :awaiting_review,
        :completed,
        :rejected,
        :expired
      ],
      review_gate_ref: "extravaganza/review_gates/operator_review",
      tenant_count: 1,
      agent_count: 1,
      runs_per_agent: 1,
      max_concurrency: 1,
      synthetic_operator_driver_ref: "operator_script_in_app_kit"
    }
  end
end
