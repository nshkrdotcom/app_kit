defmodule Mezzanine.AppKitBridge.EffectReadbackService do
  @moduledoc false

  alias Mezzanine.Core.GovernedEffects.Coordinator.Run

  @spec get_effect(String.t(), keyword()) :: {:ok, Run.t()} | {:error, term()}
  def get_effect(effect_ref, opts) when is_binary(effect_ref) and is_list(opts) do
    case run_for(effect_ref, opts) do
      %Run{} = run -> {:ok, run}
      nil -> {:error, :effect_projection_not_configured}
    end
  end

  @spec list_effects(String.t(), keyword()) :: {:ok, [Run.t()]} | {:error, term()}
  def list_effects(_run_ref, opts) when is_list(opts) do
    runs =
      opts
      |> Keyword.get(:effect_runs, %{})
      |> Map.values()

    {:ok, Enum.filter(runs, &match?(%Run{}, &1))}
  end

  defp run_for(effect_ref, opts) do
    case Keyword.get(opts, :effect_runs, %{}) do
      runs when is_map(runs) -> Map.get(runs, effect_ref)
      _other -> nil
    end
  end
end
