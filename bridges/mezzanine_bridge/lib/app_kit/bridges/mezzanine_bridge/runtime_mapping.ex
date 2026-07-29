defmodule AppKit.Bridges.MezzanineBridge.RuntimeMapping do
  @moduledoc false

  alias AppKit.Bridges.MezzanineBridge.Common
  alias AppKit.Core.RequestContext
  alias AppKit.Core.RuntimeSurface.RuntimeProfileApplyResult
  alias AppKit.Core.SubjectRef

  def runtime_profile_apply_result_from_bridge(bridge_result, tenant_id)
      when is_map(bridge_result) do
    bridge_result
    |> Map.new()
    |> Map.put_new(:tenant_ref, tenant_id)
    |> RuntimeProfileApplyResult.new()
  end

  def runtime_profile_apply_result_from_bridge(_bridge_result, _tenant_id),
    do: {:error, :invalid_runtime_profile_apply_result}

  def runtime_program_id(%RequestContext{} = context, request, opts) do
    case Common.fetch_value(request, :program_id) || Common.fetch_value(request, :program_ref) ||
           Keyword.get(opts, :program_id) || Keyword.get(opts, :program_ref) ||
           context_metadata(context, :program_id) || context_metadata(context, :program_ref) do
      value when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, :missing_program_id}
    end
  end

  def runtime_subject_id(request) do
    case Common.fetch_value(request, :subject_id) ||
           subject_id_from_runtime_ref(Common.fetch_value(request, :subject_ref)) ||
           Common.fetch_value(request, :work_object_id) do
      value when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, :missing_subject_id}
    end
  end

  def runtime_binding(request, opts) do
    params = Common.fetch_value(request, :params) || %{}

    Keyword.get(opts, :runtime_binding) ||
      Common.fetch_value(params, :runtime_binding) ||
      Common.fetch_value(params, "runtime_binding")
  end

  def runtime_role_ref(request, opts) do
    params = Common.fetch_value(request, :params) || %{}

    Keyword.get(opts, :runtime_role_ref) ||
      Common.fetch_value(params, :runtime_role_ref) ||
      :coding_agent_runtime
  end

  def operation_role_ref(request, opts) do
    params = Common.fetch_value(request, :params) || %{}

    Keyword.get(opts, :operation_role_ref) ||
      Common.fetch_value(params, :operation_role_ref) ||
      :session_turn
  end

  def context_metadata(%RequestContext{metadata: metadata}, key) do
    Map.get(metadata, key) || Map.get(metadata, Atom.to_string(key))
  end

  defp subject_id_from_runtime_ref(%SubjectRef{id: subject_id}), do: subject_id
  defp subject_id_from_runtime_ref(%{id: subject_id}) when is_binary(subject_id), do: subject_id

  defp subject_id_from_runtime_ref(%{"id" => subject_id}) when is_binary(subject_id),
    do: subject_id

  defp subject_id_from_runtime_ref(subject_id) when is_binary(subject_id), do: subject_id
  defp subject_id_from_runtime_ref(_subject_ref), do: nil
end
