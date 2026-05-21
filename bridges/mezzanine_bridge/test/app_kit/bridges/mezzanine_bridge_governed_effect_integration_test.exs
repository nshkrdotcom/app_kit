defmodule AppKit.Bridges.MezzanineBridgeGovernedEffectIntegrationTest do
  use ExUnit.Case, async: true

  alias AITrace.GovernedEffectEvidence
  alias AppKit.Bridges.MezzanineBridge
  alias AppKit.Core.{EffectTimelineDTO, GovernedEffectDTO, RequestContext}
  alias AppKit.EffectSurface
  alias Citadel.AuthorityContract.AuthorityDecision.V1, as: AuthorityDecisionV1
  alias Citadel.AuthorityContract.GovernedEffectAuthority
  alias GroundPlane.BoundaryProtocol.CommandEnvelope
  alias Jido.Integration.Lanes.DiagnosticLane
  alias Jido.Integration.V2.{Capability, DirectRuntime, GovernedLowerEnvelope, Manifest}
  alias Mezzanine.Core.GovernedEffects.Coordinator
  alias Mezzanine.Core.GovernedEffects.Coordinator.Run
  alias Mezzanine.Core.GovernedEffects.Projection

  setup_all do
    Application.ensure_all_started(:aitrace)
    :ok
  end

  test "AppKit EffectSurface proposal and readback use Mezzanine governed effects" do
    attrs = effect_attrs("appkit-proposal")

    assert {:ok, %GovernedEffectDTO{} = proposed} =
             EffectSurface.propose_effect(context(), attrs,
               effect_surface_adapter: MezzanineBridge
             )

    assert proposed.effect_ref == attrs.effect_ref
    assert proposed.status == "proposed"
    assert proposed.metadata["diagnostic_lane"] == "echo"
    assert proposed.metadata["product_slug"] == "app-kit"

    assert {:ok, %Run{} = run} = Coordinator.propose(command_attrs(attrs))

    assert {:ok, %GovernedEffectDTO{} = readback} =
             EffectSurface.get_effect(context(), attrs.effect_ref,
               effect_surface_adapter: MezzanineBridge,
               effect_runs: %{attrs.effect_ref => run}
             )

    assert readback.effect_ref == proposed.effect_ref
    assert readback.status == "proposed"
    assert readback.metadata["diagnostic_lane"] == "echo"
    assert readback.metadata["product_slug"] == "app-kit"
    assert readback.metadata["trace_summary_hash"]

    assert {:ok, %EffectTimelineDTO{} = timeline} =
             EffectSurface.get_effect_timeline(context(), attrs.effect_ref,
               effect_surface_adapter: MezzanineBridge,
               effect_runs: %{attrs.effect_ref => run}
             )

    assert timeline.effect_ref == attrs.effect_ref
    assert Enum.map(timeline.entries, &Map.fetch!(&1, "status")) == ["proposed"]
  end

  test "Mezzanine, Citadel, Jido, Execution Plane, and AITrace complete a governed effect" do
    attrs = effect_attrs("full-chain")

    assert {:ok, final_run, lower_output, authority_decision, command_envelope, trace} =
             run_allowed_pipeline(attrs)

    lower_receipt = Map.fetch!(lower_output, "lower_effect_receipt")
    diagnostic_result = get_in(lower_receipt, ["lower_facts", "diagnostic_result"])
    projection = Projection.product_safe(final_run)

    assert final_run.effect.status == :completed
    assert AuthorityDecisionV1.governed_effect_decision(authority_decision) == "allow"
    assert lower_receipt["status"] == "success"
    assert diagnostic_result["status"] == "ok"
    assert Map.fetch!(projection, "status") == "completed"
    assert CommandEnvelope.digest(command_envelope) |> sha256_ref?()
    assert trace.trace_id == attrs.trace_ref

    assert Enum.count(trace.spans, &(&1.name == "governed_effect.transition")) == 9

    assert Enum.take(Enum.map(trace.spans, & &1.name), -3) == [
             "governed_effect.authority_decision",
             "governed_effect.lower_execution",
             "governed_effect.receipt_reduction"
           ]
  end

  test "Citadel denial produces no Jido invocation and remains readable through AppKit" do
    attrs = effect_attrs("denial", effect_type: "diagnostic.probe")

    assert {:ok, run} = Coordinator.propose(command_attrs(attrs))

    assert {:ok, authority_decision} =
             GovernedEffectAuthority.authorize(authority_request(attrs),
               allowed_effect_types: ["diagnostic.echo"]
             )

    assert AuthorityDecisionV1.governed_effect_decision(authority_decision) == "deny"
    assert {:ok, denied_run} = Coordinator.deny(run, authority_attrs(attrs, authority_decision))
    refute denied_run.invocation_envelope
    assert denied_run.effect.status == :denied

    assert {:ok, %GovernedEffectDTO{} = dto} =
             EffectSurface.get_effect(context(), attrs.effect_ref,
               effect_surface_adapter: MezzanineBridge,
               effect_runs: %{attrs.effect_ref => denied_run}
             )

    assert dto.status == "denied"
    assert dto.authority_ref == authority_decision.decision_id
  end

  defp run_allowed_pipeline(attrs) do
    command_envelope = command_envelope!(attrs)

    with {:ok, run} <- Coordinator.propose(command_attrs(attrs)),
         {:ok, authority_decision} <- GovernedEffectAuthority.authorize(authority_request(attrs)),
         {:ok, run} <- Coordinator.authorize(run, authority_attrs(attrs, authority_decision)),
         {:ok, run} <-
           Coordinator.dispatch(run,
             dispatch_adapter: &dispatch_to_jido(&1, attrs, authority_decision)
           ),
         lower_output <- Map.fetch!(run.invocation_envelope, "lower_output"),
         receipt <- lower_output |> Map.fetch!("lower_effect_receipt") |> effect_receipt_attrs(),
         {:ok, run} <- Coordinator.receive_receipt(run, receipt),
         {:ok, run} <- Coordinator.reduce(run),
         {:ok, run} <- Coordinator.project(run),
         {:ok, run} <- Coordinator.complete(run),
         {:ok, trace} <- evidence_trace(run, authority_decision, lower_output) do
      {:ok, run, lower_output, authority_decision, command_envelope, trace}
    end
  end

  defp dispatch_to_jido(envelope, attrs, authority_decision) do
    operation = Map.fetch!(envelope, "operation")
    manifest = DiagnosticLane.manifest()
    operation_spec = Manifest.fetch_operation(manifest, operation)
    capability = Capability.from_operation!(manifest.connector, operation_spec)

    governed_envelope =
      GovernedLowerEnvelope.new!(%{
        lower_request_ref: Map.fetch!(envelope, "invocation_ref"),
        lower_runtime_kind: :direct_connector,
        runtime_profile_ref: "runtime-profile://app-kit/integration/diagnostic/direct",
        runtime_profile_kind: :diagnostic,
        capability_id: capability.id,
        action_id: capability.id,
        tenant_ref: Map.fetch!(envelope, "tenant_ref"),
        run_ref: "run://app-kit/integration/#{attrs.token}",
        trace_id: Map.fetch!(envelope, "trace_ref"),
        idempotency_key: Map.fetch!(attrs, :command_ref),
        authority_ref: authority_decision.decision_id,
        authority_decision_hash: authority_decision.decision_hash,
        allowed_operations: [capability.id],
        connector_ref: DiagnosticLane.connector_ref(),
        connector_manifest_ref: DiagnosticLane.manifest_ref(),
        connector_manifest_hash: DiagnosticLane.manifest_hash(),
        connector_manifest_state: :active,
        side_effect_class: :read,
        idempotency_class: :idempotent,
        runtime_class: :direct,
        effect_ref: Map.fetch!(envelope, "effect_ref"),
        expected_version: Map.fetch!(attrs, :expected_version),
        compensation_posture: :not_required,
        evidence_profile_ref: "evidence-profile://governed-effect",
        redaction_profile_ref: "redaction-profile://standard"
      })

    case DirectRuntime.execute(capability, Map.fetch!(envelope, "payload"), %{
           capability: capability,
           governed_lower_envelope: governed_envelope
         }) do
      {:ok, result} ->
        {:ok,
         envelope
         |> Map.put("dispatch_ref", governed_envelope.lower_request_ref)
         |> Map.put("lower_output", result.output)}

      {:error, reason, result} ->
        {:error, {reason, result.output}}
    end
  end

  defp evidence_trace(run, authority_decision, lower_output) do
    projection = Projection.product_safe(run)
    lower_receipt = Map.fetch!(lower_output, "lower_effect_receipt")

    GovernedEffectEvidence.new(%{
      trace_ref: run.effect.trace_ref,
      effect_ref: run.effect.effect_ref,
      command_ref: run.effect.command_ref,
      authority_ref: run.effect.authority_ref,
      receipt_ref: run.effect.receipt_ref,
      transitions: Map.fetch!(projection, "timeline"),
      authority_decision: %{
        "decision" => AuthorityDecisionV1.governed_effect_decision(authority_decision),
        "decision_hash" => authority_decision.decision_hash,
        "boundary_class" => authority_decision.boundary_class
      },
      lower_execution: Map.fetch!(lower_output, "aitrace_evidence"),
      receipt_reduction: %{
        "receipt_ref" => Map.fetch!(lower_receipt, "receipt_ref"),
        "trace_summary_hash" => Map.fetch!(projection, "trace_summary_hash")
      }
    })
    |> case do
      {:ok, evidence} -> {:ok, GovernedEffectEvidence.to_trace(evidence)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp effect_receipt_attrs(receipt) do
    Map.take(receipt, [
      "receipt_ref",
      "effect_ref",
      "status",
      "lower_receipt_ref",
      "lower_facts",
      "projection_updates",
      "evidence_refs",
      "trace_ref",
      "completed_at"
    ])
  end

  defp command_attrs(attrs) do
    %{
      effect_ref: Map.fetch!(attrs, :effect_ref),
      effect_type: Map.fetch!(attrs, :effect_type),
      command_ref: Map.fetch!(attrs, :command_ref),
      tenant_ref: Map.fetch!(attrs, :tenant_ref),
      actor_ref: Map.fetch!(attrs, :actor_ref),
      installation_ref: Map.fetch!(attrs, :installation_ref),
      trace_ref: Map.fetch!(attrs, :trace_ref),
      expected_version: Map.fetch!(attrs, :expected_version),
      operation: Map.fetch!(attrs, :effect_type),
      payload: diagnostic_payload(attrs),
      metadata: diagnostic_metadata(attrs)
    }
  end

  defp command_envelope!(attrs) do
    CommandEnvelope.new!(%{
      command_ref: Map.fetch!(attrs, :command_ref),
      tenant_ref: Map.fetch!(attrs, :tenant_ref),
      actor_ref: Map.fetch!(attrs, :actor_ref),
      installation_ref: Map.fetch!(attrs, :installation_ref),
      schema_ref: "schema://gaop/command-envelope/diagnostic/v1",
      idempotency_key: Map.fetch!(attrs, :command_ref),
      trace_ref: Map.fetch!(attrs, :trace_ref),
      operation_type: Map.fetch!(attrs, :effect_type),
      payload: diagnostic_payload(attrs),
      expected_version: Map.fetch!(attrs, :expected_version),
      resource_scopes: [%{"scope_ref" => "diagnostic://app-kit", "access" => "read"}],
      intent: %{"product_slug" => "app-kit", "reason" => "phase13_integration"},
      created_at: "2026-05-20T00:00:00Z",
      effect_class: "observe"
    })
  end

  defp authority_request(attrs) do
    %{
      request_ref: "authority-request://app-kit/integration/#{attrs.token}",
      tenant_ref: Map.fetch!(attrs, :tenant_ref),
      actor_ref: Map.fetch!(attrs, :actor_ref),
      installation_ref: Map.fetch!(attrs, :installation_ref),
      effect_ref: Map.fetch!(attrs, :effect_ref),
      effect_type: Map.fetch!(attrs, :effect_type),
      operation_type: Map.fetch!(attrs, :effect_type),
      resource_class: "diagnostic_lane",
      side_effect_class: "read",
      target_refs: ["diagnostic://app-kit"],
      budget_refs: ["budget://app-kit/diagnostic"]
    }
  end

  defp authority_attrs(attrs, authority_decision) do
    %{
      authority_ref: authority_decision.decision_id,
      decision: AuthorityDecisionV1.governed_effect_decision(authority_decision),
      tenant_ref: Map.fetch!(attrs, :tenant_ref),
      actor_ref: Map.fetch!(attrs, :actor_ref),
      command_ref: Map.fetch!(attrs, :command_ref),
      trace_ref: Map.fetch!(attrs, :trace_ref),
      decision_hash: authority_decision.decision_hash,
      boundary_class: authority_decision.boundary_class,
      posture: authority_decision.approval_profile
    }
  end

  defp diagnostic_payload(attrs), do: %{"message" => "AppKit #{attrs.token} integration"}

  defp diagnostic_metadata(attrs) do
    %{
      "diagnostic_lane" => "echo",
      "product_slug" => "app-kit",
      "run_ref" => "run://app-kit/integration/#{attrs.token}"
    }
  end

  defp effect_attrs(token, opts \\ []) do
    effect_type = Keyword.get(opts, :effect_type, "diagnostic.echo")

    %{
      token: token,
      effect_ref: "effect://app-kit/integration/#{token}",
      effect_type: effect_type,
      command_ref: "command://app-kit/integration/#{token}",
      tenant_ref: "tenant://app-kit/integration",
      actor_ref: "actor://app-kit/operator",
      installation_ref: "installation://app-kit/default",
      status: "proposed",
      trace_ref: "trace:app-kit-integration-#{token}",
      expected_version: 1,
      metadata: diagnostic_metadata(%{token: token})
    }
  end

  defp context do
    {:ok, context} =
      RequestContext.new(
        trace_id: "13131313131313131313131313131313",
        tenant_ref: %{id: "tenant://app-kit/integration"},
        actor_ref: %{id: "actor://app-kit/operator", kind: "human"},
        installation_ref: %{
          id: "installation://app-kit/default",
          pack_slug: "app-kit-integration",
          status: :active
        }
      )

    context
  end

  defp sha256_ref?("sha256:" <> rest), do: rest != ""
  defp sha256_ref?(_value), do: false
end
