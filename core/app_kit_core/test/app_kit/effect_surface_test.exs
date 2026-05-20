defmodule AppKit.EffectSurfaceTest do
  use ExUnit.Case, async: true

  alias AppKit.Core.{EffectTimelineDTO, GovernedEffectDTO}

  defmodule Backend do
    @behaviour AppKit.EffectSurface

    @impl true
    def propose_effect(_context, effect, _opts), do: GovernedEffectDTO.new(effect)

    @impl true
    def get_effect(_context, effect_ref, _opts) do
      GovernedEffectDTO.new(%{
        effect_ref: effect_ref,
        effect_type: "diagnostic.echo",
        command_ref: "command://tenant-1/commands/1",
        tenant_ref: "tenant://tenant-1",
        status: "proposed",
        trace_ref: "trace://tenant-1/effects/1"
      })
    end

    @impl true
    def list_effects(context, run_ref, opts) do
      with {:ok, effect} <- get_effect(context, "effect://#{run_ref}", opts) do
        {:ok, [effect]}
      end
    end

    @impl true
    def get_effect_timeline(_context, effect_ref, _opts) do
      EffectTimelineDTO.new(%{
        effect_ref: effect_ref,
        entries: [%{"sequence" => 1, "event_kind" => "effect_transition"}]
      })
    end
  end

  test "effect surface delegates through explicit adapter" do
    context = %{}
    attrs = effect_attrs()

    assert {:ok, %GovernedEffectDTO{effect_ref: "effect://tenant-1/effects/1"}} =
             AppKit.EffectSurface.propose_effect(context, attrs, effect_surface_adapter: Backend)

    assert {:ok, %GovernedEffectDTO{effect_ref: "effect://tenant-1/effects/1"}} =
             AppKit.EffectSurface.get_effect(context, "effect://tenant-1/effects/1",
               effect_surface_adapter: Backend
             )

    assert {:ok, [%GovernedEffectDTO{}]} =
             AppKit.EffectSurface.list_effects(context, "run://tenant-1/runs/1",
               effect_surface_adapter: Backend
             )

    assert {:ok, %EffectTimelineDTO{}} =
             AppKit.EffectSurface.get_effect_timeline(context, "effect://tenant-1/effects/1",
               effect_surface_adapter: Backend
             )
  end

  test "fixture backend returns product-safe fixture data" do
    assert {:ok, %GovernedEffectDTO{status: "proposed"}} =
             AppKit.EffectSurface.FixtureBackend.propose_effect(%{}, effect_attrs(), [])

    assert {:ok, %EffectTimelineDTO{entries: [%{"event_kind" => "effect_transition"}]}} =
             AppKit.EffectSurface.FixtureBackend.get_effect_timeline(
               %{},
               "effect://tenant-1/effects/1",
               []
             )
  end

  defp effect_attrs do
    %{
      effect_ref: "effect://tenant-1/effects/1",
      effect_type: "diagnostic.echo",
      command_ref: "command://tenant-1/commands/1",
      tenant_ref: "tenant://tenant-1",
      actor_ref: "actor://tenant-1/operator",
      installation_ref: "installation://tenant-1/synapse",
      status: "proposed",
      trace_ref: "trace://tenant-1/effects/1",
      expected_version: 1,
      metadata: %{"lane" => "diagnostic"}
    }
  end
end
