defmodule AppKit.Bridges.MezzanineBridge.RuntimeMapping do
  @moduledoc false

  alias AppKit.BackendConfig
  alias AppKit.Bridges.MezzanineBridge.Common
  alias AppKit.Core.AgentIntake.AgentRunRequest
  alias AppKit.Core.RequestContext
  alias AppKit.Core.RuntimeSurface.RuntimeProfileApplyResult
  alias AppKit.Core.SubjectRef

  def agent_run_spec_attrs(%RequestContext{} = context, %AgentRunRequest{} = request) do
    params = request.params || %{}
    profile_bundle = request.profile_bundle
    initial_input = map_param(params, :initial_input)
    continuation_policy = map_param(params, :continuation_policy)
    continuation_input = map_param(params, :continuation_input)

    run_ref =
      param(params, :run_ref, "run://agent-loop/#{ref_suffix(request.submission_dedupe_key)}")

    {:ok,
     %{
       tenant_ref: request.tenant_ref,
       installation_ref: request.installation_ref,
       profile_ref: param(params, :profile_ref, "profile://app-kit/agent-loop"),
       subject_ref: request.subject_ref,
       run_ref: run_ref,
       session_ref: param(params, :session_ref, "session://agent-loop/#{ref_suffix(run_ref)}"),
       workspace_ref:
         param(params, :workspace_ref, "workspace://agent-loop/#{ref_suffix(run_ref)}"),
       worker_ref:
         param(params, :worker_ref, "worker://agent-loop/#{ref_suffix(run_ref)}/fixture"),
       trace_id: request.trace_id,
       idempotency_key: request.idempotency_key,
       objective: request.initial_input_ref,
       initial_input_body: Common.fetch_value(initial_input, :body),
       initial_input_ref:
         Common.fetch_value(initial_input, :input_ref) || request.initial_input_ref,
       initial_input_hash: Common.fetch_value(initial_input, :content_hash),
       initial_input_source_ref: Common.fetch_value(initial_input, :source_ref),
       initial_input_rendered?: Common.fetch_value(initial_input, :rendered?),
       initial_input_body_redacted?: Common.fetch_value(initial_input, :body_redacted?),
       continuation_policy: continuation_policy,
       continuation_input_body: Common.fetch_value(continuation_input, :body),
       continuation_input_ref: Common.fetch_value(continuation_input, :input_ref),
       continuation_input_hash: Common.fetch_value(continuation_input, :content_hash),
       continuation_input_source_ref: Common.fetch_value(continuation_input, :source_ref),
       continuation_input_rendered?: Common.fetch_value(continuation_input, :rendered?),
       continuation_input_body_redacted?: Common.fetch_value(continuation_input, :body_redacted?),
       runtime_profile_ref: profile_bundle.runtime_profile_ref,
       tool_catalog_ref: request.tool_catalog_ref,
       authority_context_ref:
         param(
           params,
           :authority_context_ref,
           "authority-context://agent-loop/#{ref_suffix(run_ref)}"
         ),
       memory_profile_ref: profile_bundle.memory_profile_ref,
       artifact_policy_ref:
         param(params, :artifact_policy_ref, "artifact-policy://app-kit/agent-loop"),
       max_turns: param(params, :max_turns, 1),
       timeout_policy: timeout_policy(params),
       profile_bundle: Map.from_struct(profile_bundle),
       effect_governance_mode: request.effect_governance_mode,
       diagnostic_lane: request.diagnostic_lane,
       governed_effect_refs: request.governed_effect_refs,
       fixture_script: param(params, :fixture_script, "success_first_try"),
       continue_as_new_turn_threshold: param(params, :continue_as_new_turn_threshold, 50),
       source_ref: "actor://#{context.actor_ref.id}"
     }}
  end

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

  def governed_effect_refs(projection, %AgentRunRequest{} = request) do
    case Common.fetch_value(projection, :governed_effect_refs) do
      refs when is_map(refs) and map_size(refs) > 0 -> refs
      _missing -> request.governed_effect_refs || %{}
    end
  end

  def runtime_available?(runtime) when is_atom(runtime),
    do: Code.ensure_loaded?(runtime) and function_exported?(runtime, :run, 1)

  def runtime_available?(_runtime), do: false

  def agent_runtime(opts),
    do:
      BackendConfig.resolve_optional(opts, :agent_loop_runtime, :agent_runtime) ||
        Keyword.get(opts, :runtime_adapter)

  def ref_suffix(ref) when is_binary(ref) do
    ref
    |> ascii_alnum_dash()
    |> String.trim("-")
  end

  def ref_suffix(ref), do: ref |> to_string() |> ref_suffix()

  def context_metadata(%RequestContext{metadata: metadata}, key) do
    Map.get(metadata, key) || Map.get(metadata, Atom.to_string(key))
  end

  defp subject_id_from_runtime_ref(%SubjectRef{id: subject_id}), do: subject_id
  defp subject_id_from_runtime_ref(%{id: subject_id}) when is_binary(subject_id), do: subject_id

  defp subject_id_from_runtime_ref(%{"id" => subject_id}) when is_binary(subject_id),
    do: subject_id

  defp subject_id_from_runtime_ref(subject_id) when is_binary(subject_id), do: subject_id
  defp subject_id_from_runtime_ref(_subject_ref), do: nil

  defp map_param(params, key) do
    case Common.fetch_value(params, key) do
      %{} = value -> value
      _missing -> %{}
    end
  end

  defp timeout_policy(params),
    do:
      param(params, :timeout_policy, %{turn_timeout_ms: param(params, :turn_timeout_ms, 30_000)})

  defp param(params, key, default) do
    case Common.fetch_value(params, key) do
      nil -> default
      value -> value
    end
  end

  defp ascii_alnum_dash(value) do
    value
    |> :binary.bin_to_list()
    |> Enum.reduce({[], false}, &ascii_alnum_dash_byte/2)
    |> elem(0)
    |> Enum.reverse()
    |> List.to_string()
  end

  defp ascii_alnum_dash_byte(byte, {chars, _previous_dash?}) when byte in ?A..?Z,
    do: {[byte | chars], false}

  defp ascii_alnum_dash_byte(byte, {chars, _previous_dash?}) when byte in ?a..?z,
    do: {[byte | chars], false}

  defp ascii_alnum_dash_byte(byte, {chars, _previous_dash?}) when byte in ?0..?9,
    do: {[byte | chars], false}

  defp ascii_alnum_dash_byte(_byte, {chars, true}), do: {chars, true}
  defp ascii_alnum_dash_byte(_byte, {chars, false}), do: {[?- | chars], true}
end
