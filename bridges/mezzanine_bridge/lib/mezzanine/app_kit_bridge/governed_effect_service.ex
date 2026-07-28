defmodule Mezzanine.AppKitBridge.GovernedEffectService do
  @moduledoc """
  Narrow AppKit bridge service over the durable Mezzanine governed-effect API.
  """

  alias Mezzanine.GovernedEffects

  @spec open(map()) :: {:ok, map()} | {:error, term()}
  def open(attrs) when is_map(attrs), do: GovernedEffects.open(attrs)

  @spec begin_dispatch(String.t(), map()) :: {:ok, map()} | {:error, term()}
  def begin_dispatch(owner_execution_ref, attrs)
      when is_binary(owner_execution_ref) and is_map(attrs) do
    with {:ok, execution_id} <- execution_id(owner_execution_ref) do
      GovernedEffects.begin_dispatch(execution_id, attrs)
    end
  end

  @spec record_accepted(String.t(), map()) :: {:ok, map()} | {:error, term()}
  def record_accepted(owner_execution_ref, attrs)
      when is_binary(owner_execution_ref) and is_map(attrs) do
    with {:ok, execution_id} <- execution_id(owner_execution_ref) do
      GovernedEffects.record_accepted(execution_id, attrs)
    end
  end

  @spec record_receipt(String.t(), map()) :: {:ok, map()} | {:error, term()}
  def record_receipt(owner_execution_ref, attrs)
      when is_binary(owner_execution_ref) and is_map(attrs) do
    with {:ok, execution_id} <- execution_id(owner_execution_ref) do
      GovernedEffects.record_receipt(execution_id, attrs)
    end
  end

  @spec fetch(String.t()) :: {:ok, map()} | {:error, term()}
  def fetch(owner_execution_ref) when is_binary(owner_execution_ref) do
    with {:ok, execution_id} <- execution_id(owner_execution_ref) do
      GovernedEffects.fetch(execution_id)
    end
  end

  @spec fetch_by_idempotency(String.t(), String.t()) :: {:ok, map()} | {:error, term()}
  def fetch_by_idempotency(installation_id, idempotency_key)
      when is_binary(installation_id) and is_binary(idempotency_key) do
    GovernedEffects.fetch_by_idempotency(installation_id, idempotency_key)
  end

  defp execution_id("effect-execution://" <> execution_id) when execution_id != "",
    do: {:ok, execution_id}

  defp execution_id(_value), do: {:error, :invalid_effect_execution_ref}
end
