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

    assert request.manifest.prompt_ref == "prompt://phase-g/app-kit"

    assert request.manifest.capability_bindings |> hd() |> Map.fetch!(:capability_ref) ==
             "capability://phase-g/app-kit"
  end

  test "invocation request validates all gate refs before provider readiness" do
    assert {:ok, request} =
             SkillSurface.invocation_request(%{
               request_ref: "request://phase-g/invoke",
               operator_ref: "operator://phase-g",
               intent: valid_intent()
             })

    assert request.intent.lease_ref == "lease://phase-g"
    assert request.intent.target_ref == "target://phase-g"
  end

  test "projection and trace projection expose refs only" do
    assert {:ok, projection} = SkillSurface.projection(valid_manifest())
    assert {:ok, trace_projection} = SkillSurface.trace_projection(valid_manifest())

    assert projection.redaction_posture == "refs_only"
    assert trace_projection.redaction_posture == "private_state_redacted"
    refute Map.has_key?(projection, :private_state)
    refute Map.has_key?(trace_projection, :provider_payload)
  end

  test "surface rejects raw prompt and private state fields" do
    attrs =
      valid_manifest()
      |> Map.put(:private_state, %{value: "hidden"})

    assert {:error, {:raw_skill_surface_field_forbidden, [:private_state]}} =
             SkillSurface.projection(attrs)
  end

  defp valid_manifest do
    %{
      skill_ref: "skill://phase-g/app-kit",
      version_ref: %{
        skill_ref: "skill://phase-g/app-kit",
        version_ref: "skill-version://phase-g/app-kit/1",
        revision: 1,
        release_manifest_ref: "release://phase-g"
      },
      tenant_ref: "tenant://phase-g",
      authority_ref: "authority://phase-g",
      installation_ref: "installation://phase-g",
      idempotency_key: "idem-phase-g-app-kit",
      trace_ref: "trace://phase-g/app-kit",
      persistence_profile_ref: "persistence://memory/default",
      release_manifest_ref: "release://phase-g",
      prompt_ref: "prompt://phase-g/app-kit",
      tool_refs: ["tool://phase-g/app-kit"],
      memory_profile_ref: "memory://phase-g/default",
      guard_policy_ref: "guard://phase-g/default",
      eval_suite_ref: "eval://phase-g/default",
      budget_profile_ref: "budget://phase-g/default",
      conformance_ref: "conformance://phase-g/app-kit",
      capability_bindings: [
        %{
          binding_ref: "binding://phase-g/app-kit",
          capability_ref: "capability://phase-g/app-kit",
          connector_ref: "connector://phase-g/app-kit",
          capability_id: "app-kit.invoke",
          tenant_ref: "tenant://phase-g",
          scope_ref: "scope://phase-g/app-kit",
          contract_version: "connector-sdk.v1"
        }
      ]
    }
  end

  defp valid_intent do
    %{
      invocation_ref: "skill-invocation://phase-g/app-kit",
      skill_ref: "skill://phase-g/app-kit",
      tenant_ref: "tenant://phase-g",
      authority_ref: "authority://phase-g",
      installation_ref: "installation://phase-g",
      lease_ref: "lease://phase-g",
      target_ref: "target://phase-g",
      prompt_ref: "prompt://phase-g/app-kit",
      memory_profile_ref: "memory://phase-g/default",
      guard_policy_ref: "guard://phase-g/default",
      eval_suite_ref: "eval://phase-g/default",
      budget_profile_ref: "budget://phase-g/default",
      connector_capability_refs: ["capability://phase-g/app-kit"],
      trace_ref: "trace://phase-g/app-kit/invoke",
      idempotency_key: "idem-phase-g-app-kit-invoke",
      release_manifest_ref: "release://phase-g"
    }
  end
end
