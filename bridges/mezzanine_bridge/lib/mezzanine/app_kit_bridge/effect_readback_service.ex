defmodule Mezzanine.AppKitBridge.EffectReadbackService do
  @moduledoc false

  alias Mezzanine.AppKitBridge.GovernedEffectService
  alias Mezzanine.Execution.LifecycleContinuation

  @spec get_effect(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def get_effect(owner_execution_ref, opts)
      when is_binary(owner_execution_ref) and is_list(opts) do
    service(opts).fetch(owner_execution_ref)
  end

  @spec get_effect_by_idempotency(String.t(), String.t(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def get_effect_by_idempotency(installation_id, idempotency_key, opts)
      when is_binary(installation_id) and is_binary(idempotency_key) and is_list(opts) do
    service(opts).fetch_by_idempotency(installation_id, idempotency_key)
  end

  @spec get_continuation(LifecycleContinuation.t() | String.t(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def get_continuation(continuation_or_ref, opts)

  def get_continuation(%LifecycleContinuation{} = continuation, _opts),
    do: project_continuation(continuation)

  def get_continuation("continuation://" <> continuation_id, opts),
    do: get_continuation(continuation_id, opts)

  def get_continuation(continuation_id, opts)
      when is_binary(continuation_id) and is_list(opts) do
    continuation_service =
      Keyword.get(opts, :continuation_service, LifecycleContinuation)

    with {:ok, continuation} <- continuation_service.fetch(continuation_id) do
      project_continuation(continuation)
    end
  end

  defp service(opts),
    do: Keyword.get(opts, :governed_effect_service, GovernedEffectService)

  defp project_continuation(continuation) do
    with {:ok, target} <- LifecycleContinuation.dispatch_target(continuation) do
      {:ok,
       %{
         continuation_ref: "continuation://#{continuation.continuation_id}",
         status: to_string(continuation.status),
         target_kind: target["kind"],
         target_owner: target["owner"],
         target_operation: target["command"] || target["signal"],
         idempotency_key: target["idempotency_key"],
         attempt_count: continuation.attempt_count
       }}
    end
  end
end
