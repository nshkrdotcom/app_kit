defmodule AppKit.EffectSurface do
  @moduledoc """
  Product-facing boundary for one reviewed governed file effect.

  The surface exposes durable owner state only. Provider credentials, process
  identity, a workspace root, file contents, and lower-owner structs cannot
  cross this boundary.
  """

  alias AppKit.BackendConfig

  alias AppKit.Core.{
    EffectAcceptanceDTO,
    EffectDispatchCommandDTO,
    EffectReceiptCommandDTO,
    GovernedEffectDTO,
    GovernedEffectProposalDTO,
    RequestContext
  }

  @callback propose_effect(RequestContext.t(), GovernedEffectProposalDTO.t(), keyword()) ::
              {:ok, GovernedEffectDTO.t()} | {:error, term()}
  @callback begin_dispatch(
              RequestContext.t(),
              String.t(),
              EffectDispatchCommandDTO.t(),
              keyword()
            ) ::
              {:ok, GovernedEffectDTO.t()} | {:error, term()}
  @callback record_accepted(
              RequestContext.t(),
              String.t(),
              EffectAcceptanceDTO.t(),
              keyword()
            ) ::
              {:ok, GovernedEffectDTO.t()} | {:error, term()}
  @callback record_receipt(
              RequestContext.t(),
              String.t(),
              EffectReceiptCommandDTO.t(),
              keyword()
            ) ::
              {:ok, GovernedEffectDTO.t()} | {:error, term()}
  @callback get_effect(RequestContext.t(), String.t(), keyword()) ::
              {:ok, GovernedEffectDTO.t()} | {:error, term()}
  @callback get_effect_by_idempotency(RequestContext.t(), String.t(), keyword()) ::
              {:ok, GovernedEffectDTO.t()} | {:error, term()}

  @backend_key :effect_surface_backend
  @explicit_key :effect_surface_adapter
  @default_backend AppKit.Bridges.MezzanineBridge

  @spec propose_effect(RequestContext.t(), GovernedEffectProposalDTO.t() | map(), keyword()) ::
          {:ok, GovernedEffectDTO.t()} | {:error, term()}
  def propose_effect(%RequestContext{} = context, proposal, opts \\ []) when is_list(opts) do
    with {:ok, proposal} <- GovernedEffectProposalDTO.new(proposal) do
      backend(opts).propose_effect(context, proposal, opts)
    end
  end

  @spec begin_dispatch(
          RequestContext.t(),
          String.t(),
          EffectDispatchCommandDTO.t() | map(),
          keyword()
        ) :: {:ok, GovernedEffectDTO.t()} | {:error, term()}
  def begin_dispatch(%RequestContext{} = context, owner_execution_ref, command, opts \\ [])
      when is_list(opts) do
    with :ok <- validate_owner_execution_ref(owner_execution_ref),
         {:ok, command} <- EffectDispatchCommandDTO.new(command) do
      backend(opts).begin_dispatch(context, owner_execution_ref, command, opts)
    end
  end

  @spec record_accepted(
          RequestContext.t(),
          String.t(),
          EffectAcceptanceDTO.t() | map(),
          keyword()
        ) :: {:ok, GovernedEffectDTO.t()} | {:error, term()}
  def record_accepted(%RequestContext{} = context, owner_execution_ref, acceptance, opts \\ [])
      when is_list(opts) do
    with :ok <- validate_owner_execution_ref(owner_execution_ref),
         {:ok, acceptance} <- EffectAcceptanceDTO.new(acceptance) do
      backend(opts).record_accepted(context, owner_execution_ref, acceptance, opts)
    end
  end

  @spec record_receipt(
          RequestContext.t(),
          String.t(),
          EffectReceiptCommandDTO.t() | map(),
          keyword()
        ) :: {:ok, GovernedEffectDTO.t()} | {:error, term()}
  def record_receipt(%RequestContext{} = context, owner_execution_ref, receipt, opts \\ [])
      when is_list(opts) do
    with :ok <- validate_owner_execution_ref(owner_execution_ref),
         {:ok, receipt} <- EffectReceiptCommandDTO.new(receipt) do
      backend(opts).record_receipt(context, owner_execution_ref, receipt, opts)
    end
  end

  @spec get_effect(RequestContext.t(), String.t(), keyword()) ::
          {:ok, GovernedEffectDTO.t()} | {:error, term()}
  def get_effect(%RequestContext{} = context, owner_execution_ref, opts \\ [])
      when is_list(opts) do
    with :ok <- validate_owner_execution_ref(owner_execution_ref) do
      backend(opts).get_effect(context, owner_execution_ref, opts)
    end
  end

  @spec get_effect_by_idempotency(RequestContext.t(), String.t(), keyword()) ::
          {:ok, GovernedEffectDTO.t()} | {:error, term()}
  def get_effect_by_idempotency(%RequestContext{} = context, idempotency_key, opts \\ [])
      when is_list(opts) do
    with :ok <- validate_idempotency_key(idempotency_key) do
      backend(opts).get_effect_by_idempotency(context, idempotency_key, opts)
    end
  end

  defp backend(opts) do
    BackendConfig.resolve(opts, @explicit_key, @backend_key, @default_backend)
  end

  defp validate_owner_execution_ref("effect-execution://" <> id) when id != "", do: :ok
  defp validate_owner_execution_ref(_value), do: {:error, :invalid_effect_execution_ref}

  defp validate_idempotency_key(value) when is_binary(value) and value != "", do: :ok
  defp validate_idempotency_key(_value), do: {:error, :invalid_effect_idempotency_key}
end
