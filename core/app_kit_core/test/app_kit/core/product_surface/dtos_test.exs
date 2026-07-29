defmodule AppKit.Core.ProductSurface.DTOsTest do
  use ExUnit.Case, async: true

  alias AppKit.Core.PersistencePosture

  alias AppKit.Core.ProductSurface.{
    ArtifactProjection,
    Availability,
    CapabilityProjection,
    ContextProjection,
    ControlProjection,
    OperationProjection,
    ReviewProjection,
    RunProjection,
    TurnProjection
  }

  test "availability is a closed product state with refs-only degraded details" do
    assert {:ok, %Availability{state: :available}} = Availability.new(:available)

    assert {:ok, %Availability{state: :degraded, reason_ref: "reason://runtime/lag"}} =
             Availability.new({:degraded, "reason://runtime/lag"})

    assert {:ok, %Availability{state: :unavailable, reason: :not_configured}} =
             Availability.new(%{"state" => "unavailable", "reason" => "not_configured"})

    assert {:error, :invalid_product_availability} =
             Availability.new(%{state: :unavailable, reason: "invented_reason"})

    assert {:error, :invalid_product_availability} =
             Availability.new(%{state: :degraded, reason_ref: "/tmp/raw-reason"})
  end

  test "artifact projections require truthful retention and reject raw payload selectors" do
    assert {:ok, %ArtifactProjection{retained?: true}} =
             ArtifactProjection.new(artifact_attrs())

    assert {:error, :invalid_product_artifact_projection} =
             artifact_attrs()
             |> Map.put(:retained?, false)
             |> ArtifactProjection.new()

    assert {:error, :invalid_product_artifact_projection} =
             artifact_attrs()
             |> Map.put(:provider_payload, %{text: "hidden"})
             |> ArtifactProjection.new()
  end

  test "context projections require proof refs whenever memory contributed" do
    assert {:ok, %ContextProjection{working_memory_refs: ["memory://working/1"]}} =
             ContextProjection.new(context_attrs())

    assert {:error, :invalid_product_context_projection} =
             context_attrs()
             |> Map.put(:memory_proof_refs, [])
             |> ContextProjection.new()
  end

  test "turn streaming carries a durable cursor and completion carries an artifact" do
    assert {:ok, %TurnProjection{state: :streaming}} =
             TurnProjection.new(turn_attrs(:streaming))

    assert {:error, :invalid_product_turn_projection} =
             turn_attrs(:streaming)
             |> Map.put(:stream_cursor, nil)
             |> TurnProjection.new()

    assert {:ok, %TurnProjection{state: :completed}} =
             TurnProjection.new(turn_attrs(:completed))

    assert {:error, :invalid_product_turn_projection} =
             turn_attrs(:completed)
             |> Map.put(:output_artifact_ref, nil)
             |> TurnProjection.new()
  end

  test "reviews expose admitted actions only while pending" do
    assert {:ok, %ReviewProjection{status: :pending, allowed_actions: [:approve, :reject]}} =
             ReviewProjection.new(review_attrs())

    assert {:error, :invalid_product_review_projection} =
             review_attrs()
             |> Map.merge(%{status: :approved, decision_ref: "decision://review/1"})
             |> ReviewProjection.new()
  end

  test "completed operations require receipts and unknown outcomes retain operation identity" do
    assert {:ok, %OperationProjection{state: :completed}} =
             OperationProjection.new(operation_attrs(:completed))

    assert {:error, :invalid_product_operation_projection} =
             operation_attrs(:completed)
             |> Map.put(:receipt_ref, nil)
             |> OperationProjection.new()

    assert {:ok, %OperationProjection{state: :outcome_unknown}} =
             OperationProjection.new(operation_attrs(:outcome_unknown))

    assert {:error, :invalid_product_operation_projection} =
             operation_attrs(:outcome_unknown)
             |> Map.put(:availability, {:outcome_unknown, "operation://different"})
             |> OperationProjection.new()
  end

  test "control projections enforce optimistic versions and state-specific actions" do
    assert {:ok, %ControlProjection{available_actions: [:pause, :cancel, :supersede]}} =
             ControlProjection.new(control_attrs(:running))

    assert {:error, :invalid_product_control_projection} =
             control_attrs(:running)
             |> Map.put(:available_actions, [:resume])
             |> ControlProjection.new()

    assert {:error, :invalid_product_control_projection} =
             control_attrs(:running)
             |> Map.put(:row_version, 0)
             |> ControlProjection.new()
  end

  test "only executable available capabilities can enter product catalogs" do
    assert {:ok, %CapabilityProjection{advertised?: true}} =
             CapabilityProjection.new(capability_attrs())

    assert {:error, :invalid_product_capability_projection} =
             capability_attrs()
             |> Map.merge(%{
               advertised?: true,
               availability: {:degraded, "reason://provider/backpressure"}
             })
             |> CapabilityProjection.new()

    assert {:ok, %CapabilityProjection{advertised?: false}} =
             capability_attrs()
             |> Map.merge(%{
               advertised?: false,
               operation_refs: [],
               availability: {:unavailable, :not_admitted}
             })
             |> CapabilityProjection.new()
  end

  test "run snapshots are durable, ordered, and preserve typed cursor state" do
    attrs =
      run_attrs()
      |> Map.put(:turns, [
        turn_attrs(:completed) |> Map.put(:sequence, 2) |> Map.put(:turn_ref, "turn://run/2"),
        turn_attrs(:completed)
      ])
      |> Map.put(:events, [
        event_attrs(2),
        event_attrs(1)
      ])

    assert {:ok, %RunProjection{} = projection} = RunProjection.new(attrs)
    assert Enum.map(projection.turns, & &1.sequence) == [1, 2]
    assert Enum.map(projection.events, & &1.event_seq) == [1, 2]
    assert projection.cursor.last_seq_seen == 2
    assert projection.persistence_posture.durable?

    assert {:error, :invalid_product_run_projection} =
             attrs
             |> Map.put(:persistence_posture, PersistencePosture.memory(:runtime_projection))
             |> RunProjection.new()
  end

  defp artifact_attrs do
    %{
      artifact_ref: "artifact://turn/output/1",
      owner_projection_ref: "projection://mezzanine/artifact/1",
      source_contract_ref: "contract://mezzanine/artifact/v1",
      kind: :turn_output,
      status: :retained,
      retained?: true,
      availability: :available,
      content_ref: "content://artifact/turn-output/1",
      content_hash: "sha256:" <> String.duplicate("a", 64),
      retention_policy_ref: "retention://turn-output/default",
      evidence_refs: ["evidence://artifact/1"],
      lineage_refs: ["turn://run/1"]
    }
  end

  defp context_attrs do
    %{
      context_ref: "context://run/1/turn/1",
      snapshot_ref: "context-snapshot://run/1/turn/1",
      run_ref: "run://synapse/1",
      turn_ref: "turn://run/1",
      owner_projection_ref: "projection://outer-brain/context/1",
      source_contract_ref: "contract://outer-brain/context/v1",
      retrieval_snapshot_ref: "retrieval-snapshot://run/1/turn/1",
      context_manifest_artifact_ref: "artifact://context/1",
      working_memory_refs: ["memory://working/1"],
      episodic_memory_refs: ["memory://episodic/1"],
      memory_proof_refs: ["memory-proof://run/1/turn/1"],
      exclusion_refs: ["memory-exclusion://retention/1"],
      availability: :available
    }
  end

  defp turn_attrs(:streaming) do
    turn_base()
    |> Map.merge(%{
      state: :streaming,
      stream_cursor: cursor_attrs(),
      availability: :available
    })
  end

  defp turn_attrs(:completed) do
    turn_base()
    |> Map.merge(%{
      state: :completed,
      output_artifact_ref: "artifact://turn/output/1",
      artifact_refs: ["artifact://turn/output/1"],
      availability: :available
    })
  end

  defp turn_base do
    %{
      turn_ref: "turn://run/1",
      run_ref: "run://synapse/1",
      owner_projection_ref: "projection://mezzanine/turn/1",
      source_contract_ref: "contract://mezzanine/turn/v1",
      sequence: 1,
      input_ref: "payload://turn/input/1",
      context: context_attrs(),
      usage_ref: "usage://turn/1",
      event_refs: ["event://run/1"]
    }
  end

  defp review_attrs do
    %{
      review_ref: "review://effect/1",
      effect_ref: "effect://run/1",
      owner_projection_ref: "projection://mezzanine/review/1",
      source_contract_ref: "contract://mezzanine/review/v1",
      status: :pending,
      row_version: 1,
      allowed_actions: [:approve, :reject],
      obligation_refs: ["obligation://review/1"],
      availability: :available
    }
  end

  defp operation_attrs(:completed) do
    operation_base()
    |> Map.merge(%{
      state: :completed,
      receipt_ref: "receipt://operation/1",
      artifact_refs: ["artifact://turn/output/1"],
      evidence_refs: ["evidence://operation/1"],
      availability: :available
    })
  end

  defp operation_attrs(:outcome_unknown) do
    operation_base()
    |> Map.merge(%{
      state: :outcome_unknown,
      external_operation_ref: "external-operation://provider/1",
      availability: {:outcome_unknown, "operation://run/1"}
    })
  end

  defp operation_base do
    %{
      operation_ref: "operation://run/1",
      run_ref: "run://synapse/1",
      turn_ref: "turn://run/1",
      owner_projection_ref: "projection://mezzanine/operation/1",
      source_contract_ref: "contract://mezzanine/operation/v1",
      kind: :model_invocation,
      attempt_ref: "attempt://operation/1"
    }
  end

  defp control_attrs(:running) do
    %{
      run_ref: "run://synapse/1",
      owner_projection_ref: "projection://mezzanine/control/1",
      source_contract_ref: "contract://mezzanine/control/v1",
      row_version: 3,
      state: :running,
      available_actions: [:pause, :cancel, :supersede],
      deadline_at: "2026-07-28T12:00:00Z",
      availability: :available
    }
  end

  defp capability_attrs do
    %{
      capability_ref: "capability://model/gemini-completion",
      owner_projection_ref: "projection://runtime/capability/gemini-completion",
      source_contract_ref: "contract://runtime/capability/v1",
      producer_revision_ref: "revision://jido-integration/current",
      contract_version: "1",
      kind: :model,
      configured_mode: :local_effect,
      advertised?: true,
      health_ref: "health://model/gemini-completion/ready",
      operation_refs: ["operation-class://model/completion"],
      scope_refs: ["scope://tenant/default"],
      availability: :available
    }
  end

  defp run_attrs do
    %{
      run_ref: "run://synapse/1",
      subject_ref: "subject://synapse/1",
      workflow_ref: "workflow://synapse/1",
      owner_projection_ref: "projection://mezzanine/run/1",
      source_contract_ref: "contract://mezzanine/run/v1",
      state: :running,
      updated_at: "2026-07-28T11:00:00Z",
      cursor: cursor_attrs(),
      control: control_attrs(:running),
      turns: [turn_attrs(:streaming)],
      events: [event_attrs(2)],
      reviews: [review_attrs()],
      artifacts: [artifact_attrs()],
      operations: [operation_attrs(:completed)],
      capabilities: [capability_attrs()],
      persistence_posture: PersistencePosture.durable(:runtime_projection),
      availability: :available
    }
  end

  defp cursor_attrs do
    %{
      cursor_ref: "cursor://run/1/2",
      ledger_ref: "run://synapse/1",
      tenant_ref: "tenant://default",
      actor_ref: "actor://synapse/operator",
      last_seq_seen: 2,
      visibility: :product
    }
  end

  defp event_attrs(sequence) do
    %{
      event_ref: "event://run/#{sequence}",
      ledger_ref: "run://synapse/1",
      event_seq: sequence,
      event_kind: :execution_update,
      visibility: :product,
      observed_at: "2026-07-28T11:00:0#{sequence}Z",
      summary: "Durable event #{sequence}",
      payload_ref: "payload://event/#{sequence}"
    }
  end
end
