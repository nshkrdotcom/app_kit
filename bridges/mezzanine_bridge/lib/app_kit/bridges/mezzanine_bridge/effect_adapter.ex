defmodule AppKit.Bridges.MezzanineBridge.EffectAdapter do
  @moduledoc false

  @behaviour AppKit.EffectSurface

  alias AppKit.Bridges.MezzanineBridge.{Errors, Services}

  alias AppKit.Core.{
    EffectTimelineDTO,
    GovernedEffectDTO,
    RequestContext
  }

  alias Mezzanine.Core.GovernedEffects.Coordinator
  alias Mezzanine.Core.GovernedEffects.Coordinator.Run
  alias Mezzanine.Core.GovernedEffects.Projection

  @impl true
  def propose_effect(%RequestContext{}, %GovernedEffectDTO{} = effect, opts)
      when is_list(opts) do
    effect
    |> GovernedEffectDTO.dump()
    |> propose_effect_from_attrs(opts)
  end

  def propose_effect(%RequestContext{}, effect_params, opts)
      when is_map(effect_params) and is_list(opts) do
    propose_effect_from_attrs(effect_params, opts)
  end

  @impl true
  def get_effect(%RequestContext{}, effect_ref, opts)
      when is_binary(effect_ref) and is_list(opts) do
    case Services.effect_readback(opts).get_effect(effect_ref, opts) do
      {:ok, %Run{} = run} -> dto_from_run(run)
      {:error, reason} -> Errors.normalize(reason)
    end
  end

  @impl true
  def list_effects(%RequestContext{}, run_ref, opts) when is_binary(run_ref) and is_list(opts) do
    case Services.effect_readback(opts).list_effects(run_ref, opts) do
      {:ok, runs} -> collect_dtos(runs)
      {:error, reason} -> Errors.normalize(reason)
    end
  end

  @impl true
  def get_effect_timeline(%RequestContext{}, effect_ref, opts)
      when is_binary(effect_ref) and is_list(opts) do
    with {:ok, %Run{} = run} <- Services.effect_readback(opts).get_effect(effect_ref, opts),
         projection <- Projection.product_safe(run) do
      EffectTimelineDTO.new(%{
        effect_ref: effect_ref,
        trace_summary_hash: Map.get(projection, "trace_summary_hash"),
        entries: Map.get(projection, "timeline", [])
      })
    else
      {:error, reason} -> Errors.normalize(reason)
    end
  end

  defp propose_effect_from_attrs(attrs, opts) do
    case Coordinator.propose(attrs, opts) do
      {:ok, run} -> dto_from_run(run)
      {:error, reason} -> Errors.normalize(reason)
    end
  end

  defp collect_dtos(runs) do
    Enum.reduce_while(runs, {:ok, []}, fn
      %Run{} = run, {:ok, acc} ->
        case dto_from_run(run) do
          {:ok, dto} -> {:cont, {:ok, [dto | acc]}}
          {:error, reason} -> {:halt, {:error, reason}}
        end

      _other, _acc ->
        {:halt, Errors.normalize(:invalid_effect_projection)}
    end)
    |> case do
      {:ok, dtos} -> {:ok, Enum.reverse(dtos)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp dto_from_run(%Run{} = run) do
    projection = Projection.product_safe(run)

    GovernedEffectDTO.new(%{
      effect_ref: run.effect.effect_ref,
      effect_type: run.effect.effect_type,
      command_ref: command_value(run.command, :command_ref),
      tenant_ref: run.effect.tenant_ref,
      actor_ref: run.effect.actor_ref,
      installation_ref: run.effect.installation_ref,
      status: Map.get(projection, "status"),
      trace_ref: run.effect.trace_ref,
      authority_ref: run.effect.authority_ref,
      receipt_ref: run.effect.receipt_ref,
      dispatch_ref: run.effect.dispatch_ref,
      expected_version: run.effect.expected_version,
      metadata: %{
        "trace_summary_hash" => Map.get(projection, "trace_summary_hash")
      }
    })
  end

  defp command_value(command, key), do: Map.get(command, key, Map.get(command, to_string(key)))
end
