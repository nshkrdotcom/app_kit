defmodule AppKit.Core.ActorRef do
  @moduledoc """
  Stable northbound actor identity envelope.
  """

  alias AppKit.Core.Support

  @enforce_keys [:id, :kind]
  defstruct [:id, :kind, roles: [], display_name: nil, metadata: %{}]

  @type t :: %__MODULE__{
          id: String.t(),
          kind: atom() | String.t(),
          roles: [String.t()],
          display_name: String.t() | nil,
          metadata: map()
        }

  @spec new(map() | keyword()) :: {:ok, t()} | {:error, :invalid_actor_ref}
  def new(attrs) do
    with {:ok, attrs} <- Support.normalize_attrs(attrs),
         id <- Map.get(attrs, :id),
         true <- Support.present_binary?(id),
         kind <- Map.get(attrs, :kind),
         true <- Support.atom_or_binary?(kind),
         roles <- Map.get(attrs, :roles, []),
         true <- Support.list_of?(roles, &is_binary/1),
         display_name <- Map.get(attrs, :display_name),
         true <- Support.optional_binary?(display_name),
         metadata <- Map.get(attrs, :metadata, %{}),
         true <- is_map(metadata) do
      {:ok,
       %__MODULE__{
         id: id,
         kind: kind,
         roles: roles,
         display_name: display_name,
         metadata: metadata
       }}
    else
      _ -> {:error, :invalid_actor_ref}
    end
  end
end

defmodule AppKit.Core.TenantRef do
  @moduledoc """
  Stable northbound tenant identity envelope.
  """

  alias AppKit.Core.Support

  @enforce_keys [:id]
  defstruct [:id, slug: nil, metadata: %{}]

  @type t :: %__MODULE__{
          id: String.t(),
          slug: String.t() | nil,
          metadata: map()
        }

  @spec new(map() | keyword()) :: {:ok, t()} | {:error, :invalid_tenant_ref}
  def new(attrs) do
    with {:ok, attrs} <- Support.normalize_attrs(attrs),
         id <- Map.get(attrs, :id),
         true <- Support.present_binary?(id),
         slug <- Map.get(attrs, :slug),
         true <- Support.optional_binary?(slug),
         metadata <- Map.get(attrs, :metadata, %{}),
         true <- is_map(metadata) do
      {:ok, %__MODULE__{id: id, slug: slug, metadata: metadata}}
    else
      _ -> {:error, :invalid_tenant_ref}
    end
  end
end

defmodule AppKit.Core.InstallationRef do
  @moduledoc """
  Stable northbound installation reference.
  """

  alias AppKit.Core.Support

  @statuses [:inactive, :active, :suspended, :degraded]

  @enforce_keys [:id, :pack_slug]
  defstruct [
    :id,
    :pack_slug,
    pack_version: nil,
    compiled_pack_revision: nil,
    status: nil
  ]

  @type status :: :inactive | :active | :suspended | :degraded

  @type t :: %__MODULE__{
          id: String.t(),
          pack_slug: String.t(),
          pack_version: String.t() | nil,
          compiled_pack_revision: non_neg_integer() | nil,
          status: status() | nil
        }

  @spec new(map() | keyword()) :: {:ok, t()} | {:error, :invalid_installation_ref}
  def new(attrs) do
    with {:ok, attrs} <- Support.normalize_attrs(attrs),
         id <- Map.get(attrs, :id),
         true <- Support.present_binary?(id),
         pack_slug <- Map.get(attrs, :pack_slug),
         true <- Support.present_binary?(pack_slug),
         pack_version <- Map.get(attrs, :pack_version),
         true <- Support.optional_binary?(pack_version),
         compiled_pack_revision <- Map.get(attrs, :compiled_pack_revision),
         true <- Support.optional_non_neg_integer?(compiled_pack_revision),
         status <- Map.get(attrs, :status),
         true <- Support.optional_enum?(status, @statuses) do
      {:ok,
       %__MODULE__{
         id: id,
         pack_slug: pack_slug,
         pack_version: pack_version,
         compiled_pack_revision: compiled_pack_revision,
         status: status
       }}
    else
      _ -> {:error, :invalid_installation_ref}
    end
  end
end

defmodule AppKit.Core.RequestContext do
  @moduledoc """
  Stable request envelope shared by northbound AppKit surfaces.
  """

  alias AppKit.Core.{ActorRef, InstallationRef, Support, TenantRef}

  @enforce_keys [:trace_id, :actor_ref, :tenant_ref]
  defstruct [
    :trace_id,
    :actor_ref,
    :tenant_ref,
    installation_ref: nil,
    causation_id: nil,
    request_id: nil,
    idempotency_key: nil,
    feature_flags: %{},
    metadata: %{}
  ]

  @type t :: %__MODULE__{
          trace_id: String.t(),
          actor_ref: ActorRef.t(),
          tenant_ref: TenantRef.t(),
          installation_ref: InstallationRef.t() | nil,
          causation_id: String.t() | nil,
          request_id: String.t() | nil,
          idempotency_key: String.t() | nil,
          feature_flags: %{optional(String.t()) => boolean()},
          metadata: map()
        }

  @spec new(map() | keyword()) :: {:ok, t()} | {:error, :invalid_request_context}
  def new(attrs) do
    with {:ok, attrs} <- Support.normalize_attrs(attrs),
         trace_id <- Map.get(attrs, :trace_id),
         true <- Support.present_binary?(trace_id),
         {:ok, actor_ref} <- Support.nested_struct(Map.get(attrs, :actor_ref), ActorRef),
         false <- is_nil(actor_ref),
         {:ok, tenant_ref} <- Support.nested_struct(Map.get(attrs, :tenant_ref), TenantRef),
         false <- is_nil(tenant_ref),
         {:ok, installation_ref} <-
           Support.nested_struct(Map.get(attrs, :installation_ref), InstallationRef),
         causation_id <- Map.get(attrs, :causation_id),
         true <- Support.optional_binary?(causation_id),
         request_id <- Map.get(attrs, :request_id),
         true <- Support.optional_binary?(request_id),
         idempotency_key <- Map.get(attrs, :idempotency_key),
         true <- Support.optional_binary?(idempotency_key),
         feature_flags <- Map.get(attrs, :feature_flags, %{}),
         true <- Support.string_key_boolean_map?(feature_flags),
         metadata <- Map.get(attrs, :metadata, %{}),
         true <- is_map(metadata) do
      {:ok,
       %__MODULE__{
         trace_id: trace_id,
         actor_ref: actor_ref,
         tenant_ref: tenant_ref,
         installation_ref: installation_ref,
         causation_id: causation_id,
         request_id: request_id,
         idempotency_key: idempotency_key,
         feature_flags: feature_flags,
         metadata: metadata
       }}
    else
      _ -> {:error, :invalid_request_context}
    end
  end
end
