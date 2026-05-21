defmodule AppKit.SkillSurfaceTest do
  use ExUnit.Case, async: true

  alias AppKit.SkillSurface

  test "admission request validates a skill manifest through ref-only contracts" do
    assert {:ok, request} =
             SkillSurface.admission_request(%{
               request_ref: "request://phase-g/admit",
               operator_ref: "operator://phase-g",
               manifest: valid_manifest()
             })

    assert request.manifest.package_name == "app-kit"
    assert request.manifest.policy_refs == ["policy://phase-g/app-kit"]
    assert request.manifest.manifest_hash == manifest_hash(valid_manifest())
  end

  test "invocation request validates all gate refs before provider readiness" do
    assert {:ok, request} =
             SkillSurface.invocation_request(%{
               request_ref: "request://phase-g/invoke",
               operator_ref: "operator://phase-g",
               intent: valid_intent()
             })

    assert request.intent.credential_lease_ref == "credential-lease://phase-g/app-kit"
    assert request.intent.target_ref == "target://phase-g"
  end

  test "projection and trace projection expose refs only" do
    assert {:ok, projection} = SkillSurface.projection(valid_manifest())
    assert {:ok, trace_projection} = SkillSurface.trace_projection(valid_manifest())

    assert projection.redaction_posture == "refs_only"
    assert projection.admission_status == :admitted
    assert projection.pending_approval_refs == []
    assert trace_projection.redaction_posture == "refs_only"
    refute Map.has_key?(projection, :private_state)
    refute Map.has_key?(trace_projection, :provider_payload)
  end

  test "computes canonical manifest hashes without exposing lower contract modules" do
    attrs = Map.delete(valid_manifest(), :manifest_hash)

    assert SkillSurface.canonical_manifest_hash(attrs) == manifest_hash(attrs)
  end

  test "surface rejects raw prompt and private state fields" do
    attrs =
      valid_manifest()
      |> Map.put(:private_state, %{value: "hidden"})

    assert {:error, {:raw_skill_surface_field_forbidden, [:private_state]}} =
             SkillSurface.projection(attrs)
  end

  defp valid_manifest do
    attrs = %{
      skill_ref: "skill://phase-g/app-kit",
      package_name: "app-kit",
      version: "1.0.0",
      description: "AppKit skill fixture.",
      entrypoints: [
        %{
          name: "invoke",
          kind: :jido_action,
          schema_ref: "schema://phase-g/app-kit/input",
          capability_ref: "capability://phase-g/app-kit"
        }
      ],
      allowed_artifact_posture: :claim_checked,
      credential_posture: :lease_required,
      allowed_runtime_families: [:direct, :process],
      policy_refs: ["policy://phase-g/app-kit"],
      docs_ref: "doc://phase-g/app-kit",
      tenant_ref: "tenant://phase-g",
      installation_ref: "installation://phase-g",
      capability_refs: ["capability://phase-g/app-kit"],
      trace_ref: "trace://phase-g/app-kit",
      release_manifest_ref: "release://phase-g",
      redaction_posture: :refs_only
    }

    Map.put(attrs, :manifest_hash, manifest_hash(attrs))
  end

  defp valid_intent do
    %{
      invocation_ref: "skill-invocation://phase-g/app-kit",
      skill_ref: "skill://phase-g/app-kit",
      tenant_ref: "tenant://phase-g",
      authority_ref: "authority://phase-g",
      credential_lease_ref: "credential-lease://phase-g/app-kit",
      target_ref: "target://phase-g",
      entrypoint_name: "invoke",
      trace_ref: "trace://phase-g/app-kit/invoke",
      idempotency_key: "idem-phase-g-app-kit-invoke",
      input_ref: "payload://phase-g/app-kit/input"
    }
  end

  defp manifest_hash(attrs), do: SkillSurface.canonical_manifest_hash(attrs)
end
