defmodule Mezzanine.AppKitBridge.SemanticFailureRecoveryService do
  @moduledoc """
  Bridge-owned deterministic recovery for post-acceptance semantic failures.
  """

  alias Mezzanine.AppKitBridge.ReviewDecisionLedger
  alias Mezzanine.Reviews

  @spec recover_execution(String.t(), Mezzanine.Execution.ExecutionRecord.t() | Ecto.UUID.t()) ::
          {:ok, map()} | {:error, term()}
  def recover_execution(tenant_id, execution_or_id)
      when is_binary(tenant_id) do
    recover_execution(tenant_id, execution_or_id, [])
  end

  @spec recover_execution(
          String.t(),
          Mezzanine.Execution.ExecutionRecord.t() | Ecto.UUID.t(),
          keyword()
        ) ::
          {:ok, map()} | {:error, term()}
  def recover_execution(tenant_id, execution_or_id, opts)
      when is_binary(tenant_id) and is_list(opts) do
    with {:ok, recovery} <- Reviews.recover_execution(tenant_id, execution_or_id, opts),
         {:ok, decision_record} <-
           ReviewDecisionLedger.ensure_pending_for_recovery(
             recovery,
             actor_ref: %{kind: "system", ref: "semantic_failure_recovery"}
           ) do
      {:ok, Map.put(recovery, :decision_record, decision_record)}
    end
  end
end
