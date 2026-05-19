defmodule AppKit.Core.ReadLease do
  @moduledoc """
  Stable northbound leased direct-read envelope.
  """

  alias AppKit.Core.{ReadLeaseRef, Support, TraceIdentity}

  @enforce_keys [:lease_ref, :trace_id, :expires_at, :lease_token]
  defstruct [
    :lease_ref,
    :trace_id,
    :expires_at,
    :lease_token,
    allowed_operations: [],
    authorization_scope: %{},
    scope: %{},
    lineage_anchor: %{},
    invalidation_cursor: 0,
    invalidation_channel: nil
  ]

  @type t :: %__MODULE__{
          lease_ref: ReadLeaseRef.t(),
          trace_id: String.t(),
          expires_at: DateTime.t(),
          lease_token: String.t(),
          allowed_operations: [String.t() | atom()],
          authorization_scope: map(),
          scope: map(),
          lineage_anchor: map(),
          invalidation_cursor: non_neg_integer(),
          invalidation_channel: String.t() | nil
        }

  @spec new(map() | keyword()) :: {:ok, t()} | {:error, :invalid_read_lease}
  def new(attrs) do
    with {:ok, attrs} <- Support.normalize_attrs(attrs),
         {:ok, lease_ref} <- Support.nested_struct(Map.get(attrs, :lease_ref), ReadLeaseRef),
         false <- is_nil(lease_ref),
         {:ok, trace_id} <- TraceIdentity.ensure(Map.get(attrs, :trace_id)),
         expires_at <- Map.get(attrs, :expires_at),
         true <- Support.optional_datetime?(expires_at),
         false <- is_nil(expires_at),
         lease_token <- Map.get(attrs, :lease_token),
         true <- Support.present_binary?(lease_token),
         allowed_operations <- Map.get(attrs, :allowed_operations, []),
         true <- Support.list_of?(allowed_operations, &Support.atom_or_binary?/1),
         authorization_scope <- Map.get(attrs, :authorization_scope, %{}),
         true <- is_map(authorization_scope),
         scope <- Map.get(attrs, :scope, %{}),
         true <- is_map(scope),
         lineage_anchor <- Map.get(attrs, :lineage_anchor, %{}),
         true <- is_map(lineage_anchor),
         invalidation_cursor <- Map.get(attrs, :invalidation_cursor, 0),
         true <- Support.optional_non_neg_integer?(invalidation_cursor),
         invalidation_channel <- Map.get(attrs, :invalidation_channel),
         true <- Support.optional_binary?(invalidation_channel) do
      {:ok,
       %__MODULE__{
         lease_ref: lease_ref,
         trace_id: trace_id,
         expires_at: expires_at,
         lease_token: lease_token,
         allowed_operations: allowed_operations,
         authorization_scope: authorization_scope,
         scope: scope,
         lineage_anchor: lineage_anchor,
         invalidation_cursor: invalidation_cursor,
         invalidation_channel: invalidation_channel
       }}
    else
      _ -> {:error, :invalid_read_lease}
    end
  end
end

defmodule AppKit.Core.StreamAttachLease do
  @moduledoc """
  Stable northbound stream-attach lease envelope.
  """

  alias AppKit.Core.{StreamAttachLeaseRef, Support, TraceIdentity}

  @enforce_keys [:lease_ref, :trace_id, :expires_at, :attach_token]
  defstruct [
    :lease_ref,
    :trace_id,
    :expires_at,
    :attach_token,
    authorization_scope: %{},
    scope: %{},
    lineage_anchor: %{},
    reconnect_cursor: 0,
    invalidation_channel: nil,
    poll_interval_ms: 2_000
  ]

  @type t :: %__MODULE__{
          lease_ref: StreamAttachLeaseRef.t(),
          trace_id: String.t(),
          expires_at: DateTime.t(),
          attach_token: String.t(),
          authorization_scope: map(),
          scope: map(),
          lineage_anchor: map(),
          reconnect_cursor: non_neg_integer(),
          invalidation_channel: String.t() | nil,
          poll_interval_ms: pos_integer()
        }

  @spec new(map() | keyword()) :: {:ok, t()} | {:error, :invalid_stream_attach_lease}
  def new(attrs) do
    with {:ok, attrs} <- Support.normalize_attrs(attrs),
         {:ok, lease_ref} <-
           Support.nested_struct(Map.get(attrs, :lease_ref), StreamAttachLeaseRef),
         false <- is_nil(lease_ref),
         {:ok, trace_id} <- TraceIdentity.ensure(Map.get(attrs, :trace_id)),
         expires_at <- Map.get(attrs, :expires_at),
         true <- Support.optional_datetime?(expires_at),
         false <- is_nil(expires_at),
         attach_token <- Map.get(attrs, :attach_token),
         true <- Support.present_binary?(attach_token),
         authorization_scope <- Map.get(attrs, :authorization_scope, %{}),
         true <- is_map(authorization_scope),
         scope <- Map.get(attrs, :scope, %{}),
         true <- is_map(scope),
         lineage_anchor <- Map.get(attrs, :lineage_anchor, %{}),
         true <- is_map(lineage_anchor),
         reconnect_cursor <- Map.get(attrs, :reconnect_cursor, 0),
         true <- Support.optional_non_neg_integer?(reconnect_cursor),
         invalidation_channel <- Map.get(attrs, :invalidation_channel),
         true <- Support.optional_binary?(invalidation_channel),
         poll_interval_ms <- Map.get(attrs, :poll_interval_ms, 2_000),
         true <- Support.positive_integer?(poll_interval_ms),
         true <- poll_interval_ms <= 2_000 do
      {:ok,
       %__MODULE__{
         lease_ref: lease_ref,
         trace_id: trace_id,
         expires_at: expires_at,
         attach_token: attach_token,
         authorization_scope: authorization_scope,
         scope: scope,
         lineage_anchor: lineage_anchor,
         reconnect_cursor: reconnect_cursor,
         invalidation_channel: invalidation_channel,
         poll_interval_ms: poll_interval_ms
       }}
    else
      _ -> {:error, :invalid_stream_attach_lease}
    end
  end
end
