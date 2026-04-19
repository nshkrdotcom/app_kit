defmodule Mezzanine.AppKitBridge.LeaseService do
  @moduledoc """
  Explicit leased lower-read and stream-attach issuance for the AppKit bridge.
  """

  require Ash.Query

  alias Mezzanine.Execution
  alias Mezzanine.Execution.ExecutionRecord
  alias Mezzanine.Leasing

  @default_lower_operations [
    :fetch_run,
    :events,
    :attempts,
    :run_artifacts
  ]

  @spec issue_read_lease(map(), keyword()) :: {:ok, map()} | {:error, term()}
  def issue_read_lease(attrs, opts \\ []) when is_map(attrs) and is_list(opts) do
    attrs = Map.new(attrs)

    with {:ok, execution} <- fetch_execution_record(Map.fetch!(attrs, :execution_id)),
         :ok <- authorize_execution_access(execution, attrs),
         {:ok, lease} <-
           Leasing.issue_read_lease(
             %{
               trace_id: Map.get(attrs, :trace_id, execution.trace_id),
               tenant_id: execution.tenant_id,
               installation_id: execution.installation_id,
               installation_revision: required_non_neg_integer!(attrs, :installation_revision),
               activation_epoch: required_non_neg_integer!(attrs, :activation_epoch),
               lease_epoch: required_non_neg_integer!(attrs, :lease_epoch),
               subject_id: execution.subject_id,
               execution_id: execution.id,
               lineage_anchor: lineage_anchor(execution),
               allowed_family: Map.get(attrs, :allowed_family, "unified_trace"),
               allowed_operations: Map.get(attrs, :allowed_operations, @default_lower_operations),
               scope: Map.get(attrs, :scope, %{})
             },
             repo: lease_repo(opts)
           ) do
      {:ok, read_lease_payload(lease, execution)}
    end
  end

  @spec issue_stream_attach_lease(map(), keyword()) :: {:ok, map()} | {:error, term()}
  def issue_stream_attach_lease(attrs, opts \\ []) when is_map(attrs) and is_list(opts) do
    attrs = Map.new(attrs)

    with {:ok, execution} <- fetch_execution_record(Map.fetch!(attrs, :execution_id)),
         :ok <- authorize_execution_access(execution, attrs),
         {:ok, lease} <-
           Leasing.issue_stream_attach_lease(
             %{
               trace_id: Map.get(attrs, :trace_id, execution.trace_id),
               tenant_id: execution.tenant_id,
               installation_id: execution.installation_id,
               installation_revision: required_non_neg_integer!(attrs, :installation_revision),
               activation_epoch: required_non_neg_integer!(attrs, :activation_epoch),
               lease_epoch: required_non_neg_integer!(attrs, :lease_epoch),
               subject_id: execution.subject_id,
               execution_id: execution.id,
               lineage_anchor: lineage_anchor(execution),
               allowed_family: Map.get(attrs, :allowed_family, "runtime_stream"),
               scope: Map.get(attrs, :scope, %{})
             },
             repo: lease_repo(opts)
           ) do
      {:ok, stream_attach_lease_payload(lease, execution, opts)}
    end
  end

  defp fetch_execution_record(execution_id) do
    ExecutionRecord
    |> Ash.Query.filter(id == ^execution_id)
    |> Ash.read_one(authorize?: false, domain: Execution)
  end

  defp authorize_execution_access(nil, _attrs), do: {:error, :bridge_not_found}

  defp authorize_execution_access(execution, attrs) do
    cond do
      Map.get(attrs, :tenant_id) not in [nil, execution.tenant_id] ->
        {:error, :unauthorized_lower_read}

      Map.get(attrs, :installation_id) not in [nil, execution.installation_id] ->
        {:error, :unauthorized_lower_read}

      true ->
        :ok
    end
  end

  defp lineage_anchor(execution) do
    %{
      "submission_ref" => execution.submission_ref,
      "submission_dedupe_key" => execution.submission_dedupe_key,
      "route_id" => map_value(execution.lower_receipt, :route_id),
      "boundary_session_id" => map_value(execution.lower_receipt, :boundary_session_id),
      "lower_run_id" => map_value(execution.lower_receipt, :run_id)
    }
    |> Map.reject(fn {_key, value} -> is_nil(value) end)
  end

  defp read_lease_payload(lease, execution) do
    %{
      lease_ref: %{
        id: lease.lease_id,
        allowed_family: lease.allowed_family,
        execution_ref: %{id: execution.id}
      },
      trace_id: lease.trace_id,
      expires_at: lease.expires_at,
      lease_token: lease.lease_token,
      allowed_operations: lease.allowed_operations,
      authorization_scope: authorization_scope(lease, execution),
      scope: lease.scope,
      lineage_anchor: lease.lineage_anchor,
      invalidation_cursor: lease.issued_invalidation_cursor,
      invalidation_channel: lease.invalidation_channel
    }
  end

  defp stream_attach_lease_payload(lease, execution, opts) do
    %{
      lease_ref: %{
        id: lease.lease_id,
        allowed_family: lease.allowed_family,
        execution_ref: %{id: execution.id}
      },
      trace_id: lease.trace_id,
      expires_at: lease.expires_at,
      attach_token: lease.attach_token,
      authorization_scope: authorization_scope(lease, execution),
      scope: lease.scope,
      lineage_anchor: lease.lineage_anchor,
      reconnect_cursor: lease.last_invalidation_cursor,
      invalidation_channel: lease.invalidation_channel,
      poll_interval_ms: Keyword.get(opts, :poll_interval_ms, 2_000)
    }
  end

  defp lease_repo(opts), do: Keyword.get(opts, :lease_repo, Mezzanine.Execution.Repo)

  defp authorization_scope(lease, execution) do
    %{
      tenant_id: lease.tenant_id,
      installation_id: lease.installation_id,
      installation_revision: lease.installation_revision,
      activation_epoch: lease.activation_epoch,
      lease_epoch: lease.lease_epoch,
      subject_id: execution.subject_id,
      execution_id: execution.id,
      trace_id: lease.trace_id,
      authorized_at: DateTime.utc_now()
    }
    |> Map.reject(fn {_key, value} -> is_nil(value) end)
  end

  defp map_value(map, key) when is_map(map) do
    Map.get(map, key) || Map.get(map, Atom.to_string(key))
  end

  defp map_value(_map, _key), do: nil

  defp required_non_neg_integer!(attrs, key) do
    case Map.get(attrs, key) || Map.get(attrs, Atom.to_string(key)) do
      value when is_integer(value) and value >= 0 ->
        value

      value when is_binary(value) ->
        case Integer.parse(value) do
          {parsed, ""} when parsed >= 0 -> parsed
          _ -> raise ArgumentError, "#{key} must be a non-negative integer"
        end

      _value ->
        raise ArgumentError, "#{key} must be a non-negative integer"
    end
  end
end
