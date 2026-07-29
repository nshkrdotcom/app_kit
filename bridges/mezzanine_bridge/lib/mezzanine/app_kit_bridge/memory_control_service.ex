defmodule Mezzanine.AppKitBridge.MemoryControlService do
  @moduledoc """
  Memory-control facade for the AppKit bridge.

  The facade keeps AppKit pointed at Mezzanine/OuterBrain-owned memory services
  and avoids direct lower memory-store reads from northbound surfaces.
  """

  alias Mezzanine.Audit.MemoryProofTokenStore

  @spec list_fragments_by_proof_token(map(), keyword()) :: {:ok, [map()]} | {:error, term()}
  def list_fragments_by_proof_token(attrs, opts \\ []) when is_map(attrs) and is_list(opts) do
    with {:ok, proof_token_ref} <- fetch_string(attrs, :proof_token_ref),
         {:ok, token} <- fetch_proof_token(proof_token_ref, opts),
         :ok <- authorize_token(token, attrs),
         :ok <- reject_stale_token(token, attrs),
         {:ok, rows} <- memory_read_query(opts, token, attrs) do
      {:ok, Enum.map(rows, &fragment_projection_attrs(&1, token, attrs))}
    end
  end

  @spec lookup_fragment_by_proof_token(map(), keyword()) :: {:ok, map()} | {:error, term()}
  def lookup_fragment_by_proof_token(attrs, opts \\ []) when is_map(attrs) and is_list(opts) do
    with {:ok, rows} <- list_fragments_by_proof_token(attrs, opts) do
      case rows do
        [row | _rows] -> {:ok, row}
        [] -> {:error, :bridge_not_found}
      end
    end
  end

  @spec fragment_provenance(map(), keyword()) :: {:ok, map()} | {:error, term()}
  def fragment_provenance(attrs, opts \\ []) when is_map(attrs) and is_list(opts) do
    case Keyword.get(opts, :memory_provenance_query) do
      fun when is_function(fun, 2) ->
        fun.(attrs, opts)

      module when is_atom(module) ->
        call_module(module, :fragment_provenance, [attrs, opts], :missing_memory_provenance_query)

      nil ->
        {:error, :missing_memory_provenance_query}
    end
  end

  @spec request_share_up(map(), keyword()) :: {:ok, map()} | {:error, term()}
  def request_share_up(attrs, opts \\ []) when is_map(attrs) and is_list(opts) do
    with {:ok, result} <-
           call_memory_command_owner(
             opts,
             :share_up_command_service,
             :request_share_up,
             attrs,
             :memory_share_up_owner_not_configured
           ),
         {:ok, action_result} <- owner_action_result(result, "share_up") do
      {:ok, action_result}
    end
  end

  @spec request_promotion(map(), keyword()) :: {:ok, map()} | {:error, term()}
  def request_promotion(attrs, opts \\ []) when is_map(attrs) and is_list(opts) do
    with {:ok, result} <-
           call_memory_command_owner(
             opts,
             :promotion_command_service,
             :request_promotion,
             attrs,
             :memory_promotion_owner_not_configured
           ),
         {:ok, action_result} <- owner_action_result(result, "promote") do
      {:ok, action_result}
    end
  end

  @spec request_invalidation(map(), keyword()) :: {:ok, map()} | {:error, term()}
  def request_invalidation(attrs, opts \\ []) when is_map(attrs) and is_list(opts) do
    with {:ok, result} <-
           call_memory_command_owner(
             opts,
             :invalidation_command_service,
             :request_invalidation,
             attrs,
             :memory_invalidation_owner_not_configured
           ),
         {:ok, action_result} <- owner_action_result(result, "invalidate") do
      {:ok, action_result}
    end
  end

  defp proof_token_store(opts), do: Keyword.get(opts, :proof_token_store, MemoryProofTokenStore)

  defp fetch_proof_token(proof_token_ref, opts) do
    proof_token_store(opts)
    |> call_module(:fetch, [proof_token_ref], :missing_proof_token_store)
  end

  defp memory_read_query(opts, token, attrs) do
    case Keyword.get(opts, :memory_read_query) do
      fun when is_function(fun, 3) ->
        fun.(token, attrs, opts)

      module when is_atom(module) ->
        call_module(
          module,
          :list_fragments_by_proof_token,
          [token, attrs, opts],
          :missing_memory_read_query
        )

      nil ->
        {:error, :missing_memory_read_query}
    end
  end

  defp call_module(module, function, args, missing_reason) do
    if Code.ensure_loaded?(module) and function_exported?(module, function, length(args)) do
      apply(module, function, args)
    else
      {:error, missing_reason}
    end
  end

  defp fragment_projection_attrs(row, token, attrs) when is_map(row) do
    row
    |> strip_memory_raw_payload()
    |> Map.merge(fragment_identity_attrs(row, token))
    |> Map.merge(fragment_ordering_attrs(row, token))
    |> Map.merge(fragment_governance_attrs(row, token, attrs))
    |> reject_nil_values()
  end

  defp fragment_projection_attrs(_row, _token, _attrs), do: %{}

  defp fragment_identity_attrs(row, token) do
    %{
      fragment_ref: first_value(row, [:fragment_ref, :fragment_id]),
      tenant_ref: preferred([value(row, :tenant_ref), value(token, :tenant_ref)]),
      installation_ref:
        preferred([value(row, :installation_ref), value(token, :installation_id)]),
      tier: normalize_string(preferred([value(row, :tier), "unknown"])),
      proof_token_ref: value(token, :proof_id),
      proof_hash: public_proof_hash(value(token, :proof_hash))
    }
  end

  defp fragment_ordering_attrs(row, token) do
    %{
      source_node_ref: preferred([value(row, :source_node_ref), value(token, :source_node_ref)]),
      snapshot_epoch:
        preferred([value(row, :snapshot_epoch), value(row, :t_epoch), value(token, :epoch_used)]),
      commit_lsn: preferred([value(row, :commit_lsn), value(token, :commit_lsn)]),
      commit_hlc: preferred([value(row, :commit_hlc), value(token, :commit_hlc)])
    }
  end

  defp fragment_governance_attrs(row, token, attrs) do
    %{
      provenance_refs: preferred([value(row, :provenance_refs), provenance_refs(token, attrs)]),
      evidence_refs: preferred([value(row, :evidence_refs), value(token, :evidence_refs)]),
      governance_refs:
        preferred([
          value(row, :governance_refs),
          governance_refs(value(token, :governance_decision_ref))
        ]),
      cluster_invalidation_status:
        preferred([
          value(row, :cluster_invalidation_status),
          value(attrs, :cluster_invalidation_status),
          "unknown"
        ]),
      staleness_class:
        preferred([value(row, :staleness_class), value(attrs, :staleness_class), "unknown"]),
      redaction_posture: preferred([value(row, :redaction_posture), "operator_safe"]),
      metadata: preferred([value(row, :metadata), %{}])
    }
  end

  defp call_memory_command_owner(opts, option, function, attrs, missing_reason) do
    case Keyword.get(opts, option) do
      fun when is_function(fun, 2) ->
        fun.(attrs, opts)

      module when is_atom(module) ->
        call_module(module, function, [attrs, opts], missing_reason)

      nil ->
        {:error, missing_reason}

      _other ->
        {:error, {:invalid_memory_command_owner, option}}
    end
  end

  @owner_action_statuses %{
    :accepted => :accepted,
    "accepted" => :accepted,
    :completed => :completed,
    "completed" => :completed,
    :rejected => :rejected,
    "rejected" => :rejected,
    :failed => :failed,
    "failed" => :failed
  }

  defp owner_action_result(result, action_kind) when is_map(result) do
    operation_ref = value(result, :operation_ref)
    receipt_ref = value(result, :receipt_ref)
    metadata = value(result, :metadata)

    with operation_ref when is_binary(operation_ref) and operation_ref != "" <- operation_ref,
         {:ok, status} <- Map.fetch(@owner_action_statuses, value(result, :status)),
         true <- is_nil(receipt_ref) or is_binary(receipt_ref),
         true <- is_nil(metadata) or is_map(metadata),
         message <- value(result, :message),
         true <- is_nil(message) or is_binary(message) do
      {:ok,
       %{
         status: status,
         action_ref: %{id: operation_ref, action_kind: action_kind},
         message: message,
         metadata: maybe_put(Map.new(metadata || %{}), :receipt_ref, receipt_ref)
       }}
    else
      _other -> {:error, :invalid_memory_owner_receipt}
    end
  end

  defp owner_action_result(_result, _action_kind),
    do: {:error, :invalid_memory_owner_receipt}

  defp authorize_token(token, attrs) do
    expected_tenant = value(attrs, :expected_tenant_ref)
    context_tenant = value(attrs, :tenant_ref)

    cond do
      is_binary(expected_tenant) and token.tenant_ref != expected_tenant ->
        {:error, :unauthorized_lower_read}

      is_binary(context_tenant) and token.tenant_ref != context_tenant ->
        {:error, :unauthorized_lower_read}

      true ->
        :ok
    end
  end

  defp reject_stale_token(token, attrs) do
    if value(attrs, :reject_stale?) == true and stale_token?(token, value(attrs, :current_epoch)) do
      {:error, :stale_proof_token}
    else
      :ok
    end
  end

  defp stale_token?(token, current_epoch) when is_integer(current_epoch) and current_epoch > 0,
    do: token.epoch_used < current_epoch

  defp stale_token?(_token, _current_epoch), do: false

  defp fetch_string(attrs, key) do
    case value(attrs, key) do
      value when is_binary(value) and value != "" -> {:ok, value}
      _other -> {:error, {:missing_required_field, key}}
    end
  end

  defp provenance_refs(token, attrs) do
    value(attrs, :provenance_refs) ||
      [
        "memory-proof-token://#{token.proof_id}"
      ]
  end

  defp governance_refs(nil), do: [%{ref: "governance://memory/proof-token"}]
  defp governance_refs(value) when is_list(value), do: value
  defp governance_refs(value) when is_map(value), do: [value]
  defp governance_refs(value), do: [%{ref: inspect(value)}]

  defp strip_memory_raw_payload(row) when is_map(row) do
    Map.drop(row, [
      :payload,
      "payload",
      :raw_payload,
      "raw_payload",
      :content,
      "content",
      :fragment_payload,
      "fragment_payload",
      :body,
      "body",
      :raw_fragment,
      "raw_fragment",
      :raw_content,
      "raw_content"
    ])
  end

  defp reject_nil_values(attrs), do: Map.reject(attrs, fn {_key, value} -> is_nil(value) end)

  defp first_value(row, keys) when is_map(row) and is_list(keys),
    do: keys |> Enum.map(&value(row, &1)) |> preferred()

  defp preferred(values) when is_list(values), do: Enum.find(values, &present_value?/1)

  defp present_value?(nil), do: false
  defp present_value?(""), do: false
  defp present_value?(_value), do: true

  defp value(map_or_struct, key) when is_map(map_or_struct) do
    map = if is_struct(map_or_struct), do: Map.from_struct(map_or_struct), else: map_or_struct
    Map.get(map, key) || Map.get(map, Atom.to_string(key))
  end

  defp value(_map_or_struct, _key), do: nil

  defp normalize_string(nil), do: nil
  defp normalize_string(value) when is_atom(value), do: Atom.to_string(value)
  defp normalize_string(value), do: value

  defp public_proof_hash(<<"sha256:", digest::binary-size(64)>> = proof_hash)
       when is_binary(digest),
       do: proof_hash

  defp public_proof_hash(proof_hash) when is_binary(proof_hash) and byte_size(proof_hash) == 64,
    do: "sha256:" <> proof_hash

  defp public_proof_hash(proof_hash), do: proof_hash

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
