defmodule AppKit.Bridges.MezzanineBridgeEffectAdapterTest do
  use ExUnit.Case, async: true

  alias AppKit.Bridges.MezzanineBridge.EffectAdapter
  alias AppKit.Core.{EffectTimelineDTO, GovernedEffectDTO, RequestContext}

  test "effect adapter delegates proposal to Mezzanine governed-effect coordinator" do
    assert {:ok, %GovernedEffectDTO{} = dto} =
             EffectAdapter.propose_effect(context!(), effect_attrs(), [])

    assert dto.effect_ref == "effect://tenant-1/effects/1"
    assert dto.status == "proposed"
    assert dto.trace_ref == "trace://tenant-1/effects/1"
  end

  test "effect adapter readback delegates projection through Mezzanine run data" do
    assert {:ok, run} =
             Mezzanine.Core.GovernedEffects.Coordinator.propose(effect_attrs())

    opts = [effect_runs: %{run.effect.effect_ref => run}]

    assert {:ok, %GovernedEffectDTO{effect_ref: "effect://tenant-1/effects/1"}} =
             EffectAdapter.get_effect(context!(), "effect://tenant-1/effects/1", opts)

    assert {:ok, [%GovernedEffectDTO{effect_ref: "effect://tenant-1/effects/1"}]} =
             EffectAdapter.list_effects(context!(), "run://tenant-1/runs/1", opts)

    assert {:ok, %EffectTimelineDTO{entries: [%{"event_kind" => "effect_transition"}]}} =
             EffectAdapter.get_effect_timeline(context!(), "effect://tenant-1/effects/1", opts)
  end

  defp context! do
    {:ok, context} =
      RequestContext.new(%{
        trace_id: "0123456789abcdef0123456789abcdef",
        actor_ref: %{
          id: "actor://tenant-1/operator",
          kind: "operator",
          roles: ["developer"]
        },
        tenant_ref: %{id: "tenant://tenant-1", slug: "tenant-1"},
        installation_ref: %{
          id: "installation://tenant-1/synapse",
          pack_slug: "synapse"
        },
        request_id: "request-1",
        idempotency_key: "idempotency://tenant-1/request-1"
      })

    context
  end

  defp effect_attrs do
    %{
      effect_ref: "effect://tenant-1/effects/1",
      effect_type: "diagnostic.echo",
      command_ref: "command://tenant-1/commands/1",
      tenant_ref: "tenant://tenant-1",
      actor_ref: "actor://tenant-1/operator",
      installation_ref: "installation://tenant-1/synapse",
      trace_ref: "trace://tenant-1/effects/1",
      expected_version: 1,
      payload: %{"message_ref" => "payload://tenant-1/messages/1"}
    }
  end
end
