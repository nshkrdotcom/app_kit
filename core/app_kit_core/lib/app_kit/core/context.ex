defmodule AppKit.Core.Context do
  @moduledoc """
  Shared base context for governed AppKit calls.
  """

  alias AppKit.Core.{
    ActorRef,
    AuthorityContextExt,
    GenericBuilder,
    InstallationRef,
    SemanticContextExt,
    Support,
    TenantRef,
    WorkflowContextExt
  }

  @enforce_keys [
    :actor_ref,
    :tenant_ref,
    :installation_ref,
    :trace_ref,
    :request_ref,
    :idempotency_key
  ]

  defstruct @enforce_keys ++
              [
                :causation_ref,
                :authority_ref,
                :release_manifest_ref,
                workflow: nil,
                authority: nil,
                semantic: nil,
                metadata: %{}
              ]

  @type t :: %__MODULE__{}

  @spec new(map() | keyword()) :: {:ok, t()} | {:error, term()}
  def new(attrs) do
    with {:ok, attrs} <- Support.normalize_attrs(attrs),
         :ok <- GenericBuilder.reject_forbidden_fields(attrs),
         {:ok, actor_ref} <- Support.nested_struct(Map.get(attrs, :actor_ref), ActorRef),
         false <- is_nil(actor_ref),
         {:ok, tenant_ref} <- Support.nested_struct(Map.get(attrs, :tenant_ref), TenantRef),
         false <- is_nil(tenant_ref),
         {:ok, installation_ref} <-
           Support.nested_struct(Map.get(attrs, :installation_ref), InstallationRef),
         false <- is_nil(installation_ref),
         {:ok, workflow} <- Support.nested_struct(Map.get(attrs, :workflow), WorkflowContextExt),
         {:ok, authority} <-
           Support.nested_struct(Map.get(attrs, :authority), AuthorityContextExt),
         {:ok, semantic} <- Support.nested_struct(Map.get(attrs, :semantic), SemanticContextExt),
         :ok <- require_base_strings(attrs),
         :ok <- validate_optional_strings(attrs),
         metadata <- Map.get(attrs, :metadata, %{}),
         true <- is_map(metadata) do
      {:ok,
       %__MODULE__{
         actor_ref: actor_ref,
         tenant_ref: tenant_ref,
         installation_ref: installation_ref,
         trace_ref: Map.fetch!(attrs, :trace_ref),
         request_ref: Map.fetch!(attrs, :request_ref),
         idempotency_key: Map.fetch!(attrs, :idempotency_key),
         causation_ref: Map.get(attrs, :causation_ref),
         authority_ref: Map.get(attrs, :authority_ref),
         release_manifest_ref: Map.get(attrs, :release_manifest_ref),
         workflow: workflow,
         authority: authority,
         semantic: semantic,
         metadata: metadata
       }}
    else
      _error -> {:error, :invalid_app_kit_context}
    end
  end

  defp require_base_strings(attrs) do
    required = [:trace_ref, :request_ref, :idempotency_key]

    if Enum.all?(required, &(attrs |> Map.get(&1) |> Support.present_binary?())) do
      :ok
    else
      {:error, :invalid_base_context_ref}
    end
  end

  defp validate_optional_strings(attrs) do
    optional = [:causation_ref, :authority_ref, :release_manifest_ref]

    if Enum.all?(optional, &(attrs |> Map.get(&1) |> Support.optional_binary?())) do
      :ok
    else
      {:error, :invalid_optional_context_ref}
    end
  end
end

defmodule AppKit.Core.WorkflowContextExt do
  @moduledoc "Workflow-specific context extension."
  use AppKit.Core.GenericStruct,
    required: [:workflow_ref, :subject_ref, :work_item_ref],
    optional: [metadata: %{}]
end

defmodule AppKit.Core.SemanticContextExt do
  @moduledoc "Semantic-runtime context extension."
  use AppKit.Core.GenericStruct,
    required: [:semantic_ref],
    optional: [
      :prompt_ref,
      :memory_scope_ref,
      :context_budget_ref,
      :token_budget_ref,
      metadata: %{}
    ]
end

defmodule AppKit.Core.AuthorityContextExt do
  @moduledoc "Authority context extension after governed authorization."
  use AppKit.Core.GenericStruct,
    required: [:authority_packet_ref, :operation_class, :operation_ref],
    optional: [
      :resolved_operation_plan_ref,
      :credential_lease_ref,
      :policy_hash,
      :expires_at,
      metadata: %{}
    ]
end
