defmodule AppKit.Bridges.OuterBrainBridge do
  @moduledoc """
  App-facing bridge for semantic-turn submission above the outer brain.
  """

  alias AppKit.Core.{Telemetry, TraceIdentity}
  alias AppKit.MemorySurface
  alias AppKit.ScopeObjects.HostScope
  alias OuterBrain.Bridges.DomainSubmission
  alias OuterBrain.Contracts.SemanticFailure
  alias OuterBrain.Core.SemanticFrame
  alias OuterBrain.Prompting.ContextPack

  @spec submit_turn(HostScope.t(), String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def submit_turn(%HostScope{} = scope, text, opts \\ []) when is_binary(text) do
    trimmed = String.trim(text)

    with :ok <- validate_turn(trimmed),
         {:ok, idempotency_key} <- required_string(opts, :idempotency_key),
         {:ok, domain_module} <- required_atom(opts, :domain_module),
         {:ok, route_sources} <- required_route_sources(opts),
         runtime_ref <- Keyword.get(opts, :semantic_runtime, {DomainSubmission, []}),
         {:ok, runtime_module, runtime_opts} <- normalize_runtime_ref(runtime_ref),
         {:ok, resolution} <- resolve_trace(scope, opts) do
      emit_trace_resolution(scope.tenant_id, :outer_brain_bridge, resolution)

      runtime_module
      |> submit_runtime_turn(
        trimmed,
        runtime_opts ++
          [
            session_id: scope.session_id,
            tenant_id: scope.tenant_id,
            actor_id: scope.actor_id,
            environment: scope.environment,
            scope_id: scope.scope_id,
            workspace_id: Keyword.get(opts, :workspace_id, scope.scope_id),
            workspace_root: workspace_root(scope, opts),
            idempotency_key: idempotency_key,
            trace_id: resolution.trace_id,
            domain_module: domain_module,
            route_sources: route_sources,
            route: Keyword.get(opts, :route),
            context: context(scope, opts, resolution.trace_id),
            metadata: metadata(scope, opts, resolution.client_trace_id),
            kernel_runtime: Keyword.get(opts, :kernel_runtime),
            external_integration: Keyword.get(opts, :external_integration)
          ]
      )
      |> normalize_runtime_result(scope, idempotency_key, resolution.trace_id)
    else
      {:error, :invalid_trace_id} = error ->
        Telemetry.trace_rejected(%{
          reason: :invalid_format,
          tenant_id: scope.tenant_id,
          source: :request_edge,
          surface: :outer_brain_bridge
        })

        error

      {:error, _reason} = error ->
        error
    end
  end

  @spec build_context_pack(HostScope.t(), map(), keyword()) :: {:ok, map()} | {:error, term()}
  def build_context_pack(%HostScope{} = scope, attrs, opts \\ [])
      when is_map(attrs) and is_list(opts) do
    with {:ok, memory_query} <- memory_query_request(attrs),
         {:ok, resolution} <- resolve_trace(scope, opts) do
      frame = semantic_frame(scope, attrs)

      pack =
        ContextPack.build(
          frame,
          list_value(attrs, :refs),
          mode: map_value(attrs, :mode) || :run_context,
          trace_id: resolution.trace_id,
          context_sources: list_value(attrs, :context_sources),
          context_bindings: map_value(attrs, :context_bindings) || %{},
          context_budget: map_value(attrs, :context_budget),
          adapter_registry: Keyword.get(opts, :adapter_registry, %{}),
          persistence_posture: Keyword.get(opts, :persistence_posture, opts)
        )

      {:ok, context_pack_projection(scope, pack, memory_query, resolution.trace_id)}
    end
  end

  defp validate_turn(""), do: {:error, :blank_turn}
  defp validate_turn(_trimmed), do: :ok

  defp memory_query_request(attrs) do
    case map_value(attrs, :memory_query) do
      nil -> {:ok, nil}
      %MemorySurface.MemoryQueryRequest{} = request -> {:ok, request}
      %{} = request -> MemorySurface.query_request(request)
      other -> {:error, {:invalid_memory_query_request, other}}
    end
  end

  defp semantic_frame(%HostScope{} = scope, attrs) do
    scope.session_id
    |> SemanticFrame.seed(map_value(attrs, :objective) || "build governed runtime context")
    |> record_commitments(list_value(attrs, :commitments))
    |> record_questions(list_value(attrs, :unresolved_questions))
  end

  defp record_commitments(%SemanticFrame{} = frame, commitments) do
    Enum.reduce(commitments, frame, fn
      commitment, acc when is_binary(commitment) ->
        SemanticFrame.record_commitment(acc, commitment)

      _other, acc ->
        acc
    end)
  end

  defp record_questions(%SemanticFrame{} = frame, questions) do
    Enum.reduce(questions, frame, fn
      question, acc when is_binary(question) ->
        SemanticFrame.apply_turn(acc, %{question: question})

      _other, acc ->
        acc
    end)
  end

  defp context_pack_projection(%HostScope{} = scope, pack, memory_query, trace_id) do
    context_hash = stable_hash(pack)

    %{
      context_pack_ref:
        "context-pack://app-kit/#{scope.session_id}/#{hash_segment(context_hash)}",
      context_hash: context_hash,
      trace_id: trace_id,
      fragment_refs: fragment_refs(pack),
      memory_evidence_refs: memory_evidence_refs(pack),
      memory_query_ref: memory_query && memory_query.request_ref,
      memory_budget_ref: memory_query && memory_query.intent.budget_ref.budget_ref,
      redaction_policy_ref:
        memory_query && memory_query.intent.redaction_policy.redaction_policy_ref,
      context_sources: Map.get(pack, :context_sources, []),
      context_pack: pack
    }
    |> compact()
  end

  defp fragment_refs(pack) do
    pack
    |> Map.get(:fragments, [])
    |> Enum.flat_map(fn fragment ->
      fragment |> map_value(:fragment_id) |> List.wrap()
    end)
  end

  defp memory_evidence_refs(pack) do
    pack
    |> Map.get(:fragments, [])
    |> Enum.flat_map(fn fragment ->
      fragment
      |> map_value(:metadata)
      |> case do
        %{} = metadata -> metadata |> map_value(:memory_evidence_ref) |> List.wrap()
        _other -> []
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp stable_hash(value) do
    "sha256:" <>
      (:crypto.hash(:sha256, :erlang.term_to_binary(value)) |> Base.encode16(case: :lower))
  end

  defp hash_segment("sha256:" <> hash), do: binary_part(hash, 0, min(byte_size(hash), 16))
  defp hash_segment(hash), do: binary_part(hash, 0, min(byte_size(hash), 16))

  defp compact(map) do
    map
    |> Enum.reject(fn {_key, value} -> value in [nil, [], %{}] end)
    |> Map.new()
  end

  defp list_value(attrs, key) do
    case map_value(attrs, key) do
      value when is_list(value) -> value
      nil -> []
      value -> [value]
    end
  end

  defp map_value(nil, _key), do: nil

  defp map_value(%{} = attrs, key) do
    case Map.fetch(attrs, key) do
      {:ok, value} -> value
      :error -> Map.get(attrs, Atom.to_string(key))
    end
  end

  defp map_value(_attrs, _key), do: nil

  defp required_string(opts, key) do
    case Keyword.get(opts, key) do
      value when is_binary(value) and value != "" -> {:ok, value}
      _other -> {:error, {:missing_option, key}}
    end
  end

  defp required_atom(opts, key) do
    case Keyword.get(opts, key) do
      value when is_atom(value) -> {:ok, value}
      _other -> {:error, {:missing_option, key}}
    end
  end

  defp required_route_sources(opts) do
    case Keyword.get(opts, :route_sources) do
      value when is_list(value) and value != [] -> {:ok, value}
      _other -> {:error, {:missing_option, :route_sources}}
    end
  end

  defp normalize_runtime_ref({module, runtime_opts})
       when is_atom(module) and is_list(runtime_opts),
       do: {:ok, module, runtime_opts}

  defp normalize_runtime_ref(module) when is_atom(module), do: {:ok, module, []}

  defp normalize_runtime_ref(other),
    do: {:error, {:invalid_semantic_runtime, other}}

  defp submit_runtime_turn(runtime_module, trimmed, opts) do
    runtime_module.submit_turn(trimmed, opts)
  end

  defp normalize_runtime_result({:semantic_failure, payload}, scope, idempotency_key, trace_id) do
    semantic_failure_result(payload, scope, idempotency_key, trace_id)
  end

  defp normalize_runtime_result(
         {:error, {:semantic_failure, payload}},
         scope,
         idempotency_key,
         trace_id
       ) do
    semantic_failure_result(payload, scope, idempotency_key, trace_id)
  end

  defp normalize_runtime_result(other, _scope, _idempotency_key, _trace_id), do: other

  defp semantic_failure_result(payload, scope, idempotency_key, trace_id) do
    defaults = %{
      tenant_id: scope.tenant_id,
      semantic_session_id: scope.session_id,
      causal_unit_id: idempotency_key,
      request_trace_id: trace_id,
      provenance: [%{"surface" => "app_kit.outer_brain_bridge"}],
      operator_message: "Semantic runtime reported a semantic failure."
    }

    case SemanticFailure.new(payload, defaults) do
      {:ok, failure} -> {:error, {:semantic_failure, failure}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp context(%HostScope{} = scope, opts, trace_id) do
    scope.metadata
    |> Map.get(:context, %{})
    |> normalize_optional_map()
    |> Map.merge(%{
      session_id: scope.session_id,
      tenant_id: scope.tenant_id,
      actor_id: scope.actor_id,
      environment: scope.environment,
      trace_id: trace_id
    })
    |> Map.merge(normalize_optional_map(Keyword.get(opts, :context, %{})))
    |> drop_trace_controls()
    |> Map.put(:trace_id, trace_id)
    |> Map.delete("trace_id")
  end

  defp metadata(%HostScope{} = scope, opts, client_trace_id) do
    scope.metadata
    |> Map.delete(:context)
    |> Map.merge(normalize_optional_map(Keyword.get(opts, :metadata, %{})))
    |> sanitize_control_metadata()
    |> maybe_put_client_trace_id(client_trace_id)
  end

  defp workspace_root(%HostScope{} = scope, opts) do
    Keyword.get(opts, :workspace_root, Map.get(scope.metadata, :workspace_root))
  end

  defp resolve_trace(%HostScope{} = scope, opts) do
    TraceIdentity.resolve_edge_trace(
      edge_trace_candidate(opts),
      trust: trace_trust(scope, opts)
    )
  end

  defp edge_trace_candidate(opts) do
    context = normalize_optional_map(Keyword.get(opts, :context, %{}))

    Keyword.get(opts, :trace_id) ||
      Map.get(context, :trace_id) ||
      Map.get(context, "trace_id")
  end

  defp trace_trust(%HostScope{metadata: metadata}, opts) do
    context = normalize_optional_map(Keyword.get(opts, :context, %{}))

    [
      Keyword.get(opts, :trace_trust),
      Map.get(context, :trace_trust),
      Map.get(context, "trace_trust"),
      Map.get(metadata, :trace_trust),
      Map.get(metadata, "trace_trust"),
      Keyword.get(opts, :trusted_trace_id?),
      Map.get(context, :trusted_trace_id?),
      Map.get(context, "trusted_trace_id?"),
      Map.get(metadata, :trusted_trace_id?),
      Map.get(metadata, "trusted_trace_id?")
    ]
    |> Enum.find(fn value -> not is_nil(value) end)
  end

  defp drop_trace_controls(context) do
    context
    |> Map.delete(:trace_trust)
    |> Map.delete("trace_trust")
    |> Map.delete(:trusted_trace_id?)
    |> Map.delete("trusted_trace_id?")
  end

  defp sanitize_control_metadata(metadata) do
    metadata
    |> Map.delete(:trace_trust)
    |> Map.delete("trace_trust")
    |> Map.delete(:trusted_trace_id?)
    |> Map.delete("trusted_trace_id?")
  end

  defp maybe_put_client_trace_id(metadata, nil), do: metadata

  defp maybe_put_client_trace_id(metadata, trace_id),
    do: Map.put(metadata, :client_trace_id, trace_id)

  defp normalize_optional_map(value) when is_map(value), do: value
  defp normalize_optional_map(value) when is_list(value), do: Map.new(value)
  defp normalize_optional_map(_value), do: %{}

  defp emit_trace_resolution(tenant_id, surface, %{disposition: :minted, trace_id: trace_id}) do
    Telemetry.trace_minted(%{
      trace_id: trace_id,
      tenant_id: tenant_id,
      source: :request_edge,
      surface: surface
    })
  end

  defp emit_trace_resolution(tenant_id, surface, %{disposition: :replaced, trace_id: trace_id}) do
    Telemetry.trace_replaced(%{
      trace_id: trace_id,
      tenant_id: tenant_id,
      reason: :untrusted_caller,
      source: :request_edge,
      surface: surface
    })
  end

  defp emit_trace_resolution(_tenant_id, _surface, _resolution), do: :ok
end
