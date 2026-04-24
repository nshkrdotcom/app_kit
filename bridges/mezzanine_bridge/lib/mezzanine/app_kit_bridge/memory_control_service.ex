defmodule Mezzanine.AppKitBridge.MemoryControlService do
  @moduledoc """
  Memory-control facade for the AppKit bridge.

  The facade keeps AppKit pointed at Mezzanine/OuterBrain-owned memory services
  and avoids direct lower memory-store reads from northbound surfaces.
  """

  alias Mezzanine.Audit.MemoryProofTokenStore

  @share_up_client Module.concat(["OuterBrain", "Memory", "ShareUpClient"])
  @promotion_coordinator Module.concat(["Mezzanine", "Memory", "PromotionCoordinator"])
  @invalidation_coordinator Module.concat(["Mezzanine", "Memory", "InvalidationCoordinator"])

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
    lower = Keyword.get(opts, :share_up_client, @share_up_client)

    with {:ok, result} <-
           call_lower(lower, :share_up, [attrs, Keyword.get(opts, :share_up_callbacks, [])]) do
      {:ok, action_result(result, attrs, :fragment_ref, "share_up", "Share-up requested")}
    end
  end

  @spec request_promotion(map(), keyword()) :: {:ok, map()} | {:error, term()}
  def request_promotion(attrs, opts \\ []) when is_map(attrs) and is_list(opts) do
    lower = Keyword.get(opts, :promotion_coordinator, @promotion_coordinator)

    with {:ok, result} <-
           call_lower(lower, :propose_candidate, [
             attrs,
             Keyword.get(opts, :promotion_callbacks, [])
           ]) do
      {:ok, action_result(result, attrs, :shared_fragment_ref, "promote", "Promotion requested")}
    end
  end

  @spec request_invalidation(map(), keyword()) :: {:ok, map()} | {:error, term()}
  def request_invalidation(attrs, opts \\ []) when is_map(attrs) and is_list(opts) do
    lower = Keyword.get(opts, :invalidation_coordinator, @invalidation_coordinator)

    with {:ok, result} <-
           call_lower(lower, :invalidate, [
             invalidation_request_attrs(attrs),
             Keyword.get(opts, :invalidation_callbacks, [])
           ]) do
      {:ok,
       action_result(result, attrs, :root_fragment_ref, "invalidate", "Invalidation requested")}
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

  defp call_lower(fun, _function, args) when is_function(fun, length(args)), do: apply(fun, args)

  defp call_lower(module, function, args) when is_atom(module) do
    call_module(module, function, args, {:missing_lower_service, module, function})
  end

  defp call_lower(_lower, function, _args), do: {:error, {:invalid_lower_service, function}}

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
      proof_hash: value(token, :proof_hash)
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

  defp action_result(result, attrs, fragment_key, action_kind, message) when is_map(result) do
    result
    |> normalize_value()
    |> Map.merge(%{
      status: value(result, :status) || :accepted,
      action_ref:
        value(result, :action_ref) ||
          %{
            id: "#{value(attrs, fragment_key)}:#{action_kind}",
            action_kind: action_kind
          },
      message: value(result, :message) || message,
      metadata:
        Map.merge(
          %{fragment_ref: value(attrs, fragment_key)},
          value(result, :metadata) || %{}
        )
    })
  end

  defp action_result(result, attrs, fragment_key, action_kind, message) do
    %{
      status: :accepted,
      action_ref: %{id: "#{value(attrs, fragment_key)}:#{action_kind}", action_kind: action_kind},
      message: message,
      metadata: %{fragment_ref: value(attrs, fragment_key), lower_result: result}
    }
  end

  defp invalidation_request_attrs(attrs) do
    attrs
    |> Map.new()
    |> Map.put_new(:root_fragment_id, value(attrs, :root_fragment_ref))
    |> Map.put_new(:effective_at, value(attrs, :effective_at) || DateTime.utc_now())
    |> Map.put_new(
      :effective_at_epoch,
      value(attrs, :effective_at_epoch) || value(attrs, :current_epoch)
    )
    |> Map.put_new(:authority_ref, value(attrs, :authority_ref))
    |> Map.put_new(:evidence_refs, value(attrs, :evidence_refs) || [])
  end

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

  defp normalize_value(%DateTime{} = value), do: value
  defp normalize_value(%NaiveDateTime{} = value), do: value
  defp normalize_value(%_{} = value), do: value |> Map.from_struct() |> normalize_value()

  defp normalize_value(value) when is_map(value) do
    Map.new(value, fn {key, nested_value} -> {key, normalize_value(nested_value)} end)
  end

  defp normalize_value(value) when is_list(value), do: Enum.map(value, &normalize_value/1)
  defp normalize_value(value), do: value
end
