defmodule AppKit.Bridges.MezzanineBridge.ActionMapping do
  @moduledoc false

  alias AppKit.Bridges.MezzanineBridge.Common
  alias AppKit.Core.{ActionResult, ExecutionRef, OperatorActionRef, SubjectRef}

  def action_result_from_bridge(bridge_result) do
    with {:ok, action_ref} <-
           operator_action_ref_from_map(Common.fetch_value(bridge_result, :action_ref)),
         {:ok, execution_ref} <-
           execution_ref_from_bridge(Common.fetch_value(bridge_result, :execution_ref)) do
      ActionResult.new(%{
        status: Common.fetch_value(bridge_result, :status),
        action_ref: action_ref,
        execution_ref: execution_ref,
        message: Common.fetch_value(bridge_result, :message),
        metadata: Common.fetch_value(bridge_result, :metadata) || %{}
      })
    end
  end

  defp execution_ref_from_bridge(nil), do: {:ok, nil}

  defp execution_ref_from_bridge(raw_execution_ref) when is_map(raw_execution_ref),
    do: ExecutionRef.new(raw_execution_ref)

  defp execution_ref_from_bridge(_raw_execution_ref), do: {:error, :invalid_execution_ref}

  defp operator_action_ref_from_map(nil), do: {:ok, nil}

  defp operator_action_ref_from_map(raw_action_ref) when is_map(raw_action_ref) do
    with {:ok, subject_ref} <- subject_ref_from_action_map(raw_action_ref) do
      OperatorActionRef.new(%{
        id: Common.fetch_value(raw_action_ref, :id),
        action_kind: Common.fetch_value(raw_action_ref, :action_kind),
        subject_ref: subject_ref
      })
    end
  end

  defp operator_action_ref_from_map(_raw_action_ref), do: {:error, :invalid_operator_action_ref}

  defp subject_ref_from_action_map(raw_action_ref) do
    case Common.fetch_value(raw_action_ref, :subject_ref) do
      nil -> {:ok, nil}
      raw_subject_ref when is_map(raw_subject_ref) -> SubjectRef.new(raw_subject_ref)
      _other -> {:error, :invalid_subject_ref}
    end
  end
end
