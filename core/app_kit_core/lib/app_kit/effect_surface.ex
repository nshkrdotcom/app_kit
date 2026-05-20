defmodule AppKit.EffectSurface do
  @moduledoc """
  Product-facing governed-effect lifecycle surface.
  """

  alias AppKit.BackendConfig
  alias AppKit.Core.GovernedEffectDTO

  @callback propose_effect(context :: term(), effect_params :: term(), opts :: keyword()) ::
              {:ok, GovernedEffectDTO.t()} | {:error, term()}
  @callback get_effect(context :: term(), effect_ref :: String.t(), opts :: keyword()) ::
              {:ok, GovernedEffectDTO.t()} | {:error, term()}
  @callback list_effects(context :: term(), run_ref :: String.t(), opts :: keyword()) ::
              {:ok, [GovernedEffectDTO.t()]} | {:error, term()}
  @callback get_effect_timeline(context :: term(), effect_ref :: String.t(), opts :: keyword()) ::
              {:ok, AppKit.Core.EffectTimelineDTO.t()} | {:error, term()}

  @backend_key :effect_surface_backend
  @explicit_key :effect_surface_adapter
  @default_backend AppKit.Bridges.MezzanineBridge

  def propose_effect(context, effect_params, opts \\ []) when is_list(opts) do
    backend(opts).propose_effect(context, effect_params, opts)
  end

  def get_effect(context, effect_ref, opts \\ []) when is_list(opts) do
    with :ok <- validate_ref(effect_ref) do
      backend(opts).get_effect(context, effect_ref, opts)
    end
  end

  def list_effects(context, run_ref, opts \\ []) when is_list(opts) do
    with :ok <- validate_ref(run_ref) do
      backend(opts).list_effects(context, run_ref, opts)
    end
  end

  def get_effect_timeline(context, effect_ref, opts \\ []) when is_list(opts) do
    with :ok <- validate_ref(effect_ref) do
      backend(opts).get_effect_timeline(context, effect_ref, opts)
    end
  end

  defp backend(opts) do
    BackendConfig.resolve(opts, @explicit_key, @backend_key, @default_backend)
  end

  defp validate_ref(value) when is_binary(value) and value != "", do: :ok
  defp validate_ref(_value), do: {:error, :invalid_effect_ref}
end

defmodule AppKit.EffectSurface.FixtureBackend do
  @moduledoc "Fixture governed-effect surface backend for product tests."

  @behaviour AppKit.EffectSurface

  alias AppKit.Core.{EffectTimelineDTO, GovernedEffectDTO}

  @impl true
  def propose_effect(_context, effect_params, _opts) do
    effect_params
    |> normalize_effect_attrs()
    |> GovernedEffectDTO.new()
  end

  @impl true
  def get_effect(_context, effect_ref, _opts) do
    GovernedEffectDTO.new(fixture_effect_attrs(effect_ref))
  end

  @impl true
  def list_effects(_context, _run_ref, _opts) do
    with {:ok, effect} <-
           GovernedEffectDTO.new(fixture_effect_attrs("effect://fixture/diagnostic")) do
      {:ok, [effect]}
    end
  end

  @impl true
  def get_effect_timeline(_context, effect_ref, _opts) do
    EffectTimelineDTO.new(%{
      effect_ref: effect_ref,
      trace_summary_hash: "sha256:fixture-trace",
      entries: [
        %{
          "sequence" => 1,
          "event_kind" => "effect_transition",
          "status" => "proposed",
          "entry_hash" => "sha256:fixture-entry"
        }
      ],
      metadata: %{"source" => "fixture"}
    })
  end

  defp normalize_effect_attrs(%GovernedEffectDTO{} = dto), do: GovernedEffectDTO.dump(dto)

  defp normalize_effect_attrs(attrs) when is_map(attrs) do
    attrs
    |> Map.put_new(:status, "proposed")
    |> Map.put_new(:trace_ref, "trace://fixture/diagnostic")
  end

  defp fixture_effect_attrs(effect_ref) do
    %{
      effect_ref: effect_ref,
      effect_type: "diagnostic.echo",
      command_ref: "command://fixture/diagnostic",
      tenant_ref: "tenant://fixture",
      actor_ref: "actor://fixture/operator",
      installation_ref: "installation://fixture/synapse",
      status: "proposed",
      trace_ref: "trace://fixture/diagnostic",
      expected_version: 1,
      metadata: %{"source" => "fixture"}
    }
  end
end
