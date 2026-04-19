defmodule AppKit.Core.EnterprisePrecutSupport do
  @moduledoc false

  @type build_error :: {:missing_required_fields, [atom()]} | atom()

  @spec normalize_attrs(map() | keyword()) :: {:ok, map()} | {:error, :invalid_attrs}
  def normalize_attrs(attrs) when is_list(attrs), do: {:ok, Map.new(attrs)}

  def normalize_attrs(attrs) when is_map(attrs) do
    if Map.has_key?(attrs, :__struct__) do
      {:ok, Map.from_struct(attrs)}
    else
      {:ok, attrs}
    end
  end

  def normalize_attrs(_attrs), do: {:error, :invalid_attrs}

  @spec build(module(), String.t(), [atom()], [atom()], map() | keyword(), keyword()) ::
          {:ok, struct()} | {:error, build_error()}
  def build(module, contract_name, fields, required_fields, attrs, opts \\ []) do
    with {:ok, attrs} <- normalize_attrs(attrs),
         [] <- missing_required_fields(attrs, required_fields, opts),
         :ok <- validate_maps(attrs, Keyword.get(opts, :map_fields, [])),
         :ok <- validate_lists(attrs, Keyword.get(opts, :list_fields, [])) do
      {:ok, struct(module, attrs |> Map.take(fields) |> Map.put(:contract_name, contract_name))}
    else
      fields when is_list(fields) -> {:error, {:missing_required_fields, fields}}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec missing_required_fields(map(), [atom()], keyword()) :: [atom()]
  def missing_required_fields(attrs, required_fields, opts) do
    required_fields
    |> Enum.reject(&present?(Map.get(attrs, &1)))
    |> maybe_require_actor(attrs, Keyword.get(opts, :require_actor?, false))
  end

  defp maybe_require_actor(missing, attrs, true) do
    if present?(Map.get(attrs, :principal_ref)) or present?(Map.get(attrs, :system_actor_ref)) do
      missing
    else
      missing ++ [:principal_ref_or_system_actor_ref]
    end
  end

  defp maybe_require_actor(missing, _attrs, _require_actor?), do: missing

  defp validate_maps(attrs, fields) do
    if Enum.all?(fields, &is_map(Map.get(attrs, &1, %{}))) do
      :ok
    else
      {:error, :invalid_map_field}
    end
  end

  defp validate_lists(attrs, fields) do
    if Enum.all?(fields, &is_list(Map.get(attrs, &1, []))) do
      :ok
    else
      {:error, :invalid_list_field}
    end
  end

  defp present?(value) when is_binary(value), do: String.trim(value) != ""
  defp present?(value) when is_map(value), do: map_size(value) > 0
  defp present?(value), do: not is_nil(value)
end

defmodule AppKit.Core.WorkspaceRef do
  @moduledoc "Tenant-scoped workspace reference for Phase 4 public DTOs."

  alias AppKit.Core.EnterprisePrecutSupport

  @fields [:contract_name, :id, :tenant_id, :revision, :display_label]
  defstruct @fields

  @type t :: %__MODULE__{}

  def new(attrs),
    do:
      EnterprisePrecutSupport.build(
        __MODULE__,
        "AppKit.WorkspaceRef.v1",
        @fields,
        [:id, :tenant_id],
        attrs
      )
end

defmodule AppKit.Core.ProjectRef do
  @moduledoc "Tenant-scoped project reference for Phase 4 public DTOs."

  alias AppKit.Core.EnterprisePrecutSupport

  @fields [:contract_name, :id, :tenant_id, :revision, :display_label]
  defstruct @fields

  @type t :: %__MODULE__{}

  def new(attrs),
    do:
      EnterprisePrecutSupport.build(
        __MODULE__,
        "AppKit.ProjectRef.v1",
        @fields,
        [:id, :tenant_id],
        attrs
      )
end

defmodule AppKit.Core.EnvironmentRef do
  @moduledoc "Tenant-scoped runtime/config environment reference."

  alias AppKit.Core.EnterprisePrecutSupport

  @fields [:contract_name, :id, :tenant_id, :revision, :display_label]
  defstruct @fields

  @type t :: %__MODULE__{}

  def new(attrs),
    do:
      EnterprisePrecutSupport.build(
        __MODULE__,
        "AppKit.EnvironmentRef.v1",
        @fields,
        [:id, :tenant_id],
        attrs
      )
end

defmodule AppKit.Core.PrincipalRef do
  @moduledoc "Public-safe human/service/operator principal reference."

  alias AppKit.Core.EnterprisePrecutSupport

  @fields [:contract_name, :id, :tenant_id, :kind, :display_label, :auth_subject_ref]
  defstruct @fields

  @type t :: %__MODULE__{}

  def new(attrs),
    do:
      EnterprisePrecutSupport.build(
        __MODULE__,
        "AppKit.PrincipalRef.v1",
        @fields,
        [:id, :tenant_id, :kind],
        attrs
      )
end

defmodule AppKit.Core.SystemActorRef do
  @moduledoc "Public-safe platform-generated actor reference."

  alias AppKit.Core.EnterprisePrecutSupport

  @fields [
    :contract_name,
    :id,
    :tenant_id,
    :actor_kind,
    :owning_repo,
    :causal_command_id,
    :workflow_ref
  ]
  defstruct @fields

  @type t :: %__MODULE__{}

  def new(attrs),
    do:
      EnterprisePrecutSupport.build(
        __MODULE__,
        "AppKit.SystemActorRef.v1",
        @fields,
        [:id, :tenant_id, :actor_kind, :owning_repo],
        attrs
      )
end

defmodule AppKit.Core.ResourceRef do
  @moduledoc "Tenant-scoped governed resource reference."

  alias AppKit.Core.EnterprisePrecutSupport

  @fields [:contract_name, :id, :tenant_id, :resource_kind, :owning_repo, :resource_revision]
  defstruct @fields

  @type t :: %__MODULE__{}

  def new(attrs),
    do:
      EnterprisePrecutSupport.build(
        __MODULE__,
        "AppKit.ResourceRef.v1",
        @fields,
        [:id, :tenant_id, :resource_kind, :owning_repo],
        attrs
      )
end

defmodule AppKit.Core.ResourcePath do
  @moduledoc "Hierarchical tenant/resource path used by authority and trace joins."

  alias AppKit.Core.EnterprisePrecutSupport

  @fields [:contract_name, :tenant_id, :segments, :resource_kind_path, :terminal_resource_id]
  defstruct @fields

  @type t :: %__MODULE__{}

  def new(attrs),
    do:
      EnterprisePrecutSupport.build(
        __MODULE__,
        "AppKit.ResourcePath.v1",
        @fields,
        [:tenant_id, :terminal_resource_id],
        attrs,
        list_fields: [:segments, :resource_kind_path]
      )
end

defmodule AppKit.Core.CommandEnvelope do
  @moduledoc "Enterprise pre-cut command envelope for every AppKit mutation."

  alias AppKit.Core.EnterprisePrecutSupport

  @fields [
    :contract_name,
    :command_id,
    :command_name,
    :command_version,
    :tenant_ref,
    :installation_ref,
    :workspace_ref,
    :project_ref,
    :environment_ref,
    :principal_ref,
    :system_actor_ref,
    :resource_ref,
    :resource_path,
    :request_id,
    :trace_id,
    :correlation_id,
    :causation_id,
    :idempotency_key,
    :dedupe_scope,
    :authority_packet_ref,
    :expected_revision,
    :lease_ref,
    :epoch_ref,
    :redaction_posture,
    :error_namespace,
    :retry_posture,
    :payload_ref,
    :payload,
    :payload_hash
  ]
  defstruct @fields

  @type t :: %__MODULE__{}

  def new(attrs),
    do:
      EnterprisePrecutSupport.build(
        __MODULE__,
        "AppKit.CommandEnvelope.v1",
        @fields,
        [
          :command_id,
          :command_name,
          :command_version,
          :tenant_ref,
          :resource_ref,
          :trace_id,
          :idempotency_key,
          :authority_packet_ref
        ],
        attrs,
        require_actor?: true
      )
end

defmodule AppKit.Core.CommandResult do
  @moduledoc "Public-safe AppKit command outcome DTO."

  alias AppKit.Core.EnterprisePrecutSupport

  @fields [
    :contract_name,
    :command_id,
    :status,
    :accepted_event_ref,
    :permission_decision_ref,
    :workflow_ref,
    :projection_ref,
    :rejection,
    :trace_id,
    :release_manifest_version
  ]
  defstruct @fields

  @type t :: %__MODULE__{}

  def new(attrs),
    do:
      EnterprisePrecutSupport.build(
        __MODULE__,
        "AppKit.CommandResult.v1",
        @fields,
        [:command_id, :status, :trace_id, :release_manifest_version],
        attrs
      )
end

defmodule AppKit.Core.WorkflowRef do
  @moduledoc "Product/operator-safe workflow identity reference."

  alias AppKit.Core.EnterprisePrecutSupport

  @fields [
    :contract_name,
    :workflow_type,
    :workflow_id,
    :workflow_run_id,
    :workflow_version,
    :parent_workflow_ref,
    :tenant_ref,
    :resource_ref,
    :subject_ref,
    :starter_command_id,
    :trace_id,
    :search_attributes,
    :release_manifest_version
  ]
  defstruct @fields

  @type t :: %__MODULE__{}

  def new(attrs),
    do:
      EnterprisePrecutSupport.build(
        __MODULE__,
        "AppKit.WorkflowRef.v1",
        @fields,
        [
          :workflow_type,
          :workflow_id,
          :workflow_version,
          :tenant_ref,
          :resource_ref,
          :subject_ref,
          :starter_command_id,
          :trace_id,
          :release_manifest_version
        ],
        attrs,
        map_fields: [:search_attributes]
      )
end

defmodule AppKit.Core.WorkflowStartRequest do
  @moduledoc "Workflow start request consumed by Mezzanine.WorkflowRuntime."

  alias AppKit.Core.EnterprisePrecutSupport

  @fields [
    :contract_name,
    :command_envelope,
    :permission_decision_ref,
    :workflow_type,
    :workflow_id,
    :workflow_input_version,
    :search_attributes,
    :starter_outbox_ref
  ]
  defstruct @fields

  @type t :: %__MODULE__{}

  def new(attrs),
    do:
      EnterprisePrecutSupport.build(
        __MODULE__,
        "AppKit.WorkflowStartRequest.v1",
        @fields,
        [
          :command_envelope,
          :permission_decision_ref,
          :workflow_type,
          :workflow_id,
          :workflow_input_version,
          :starter_outbox_ref
        ],
        attrs,
        map_fields: [:search_attributes]
      )
end

defmodule AppKit.Core.WorkflowSignalRequest do
  @moduledoc "Authorized workflow signal request DTO."

  alias AppKit.Core.EnterprisePrecutSupport

  @fields [
    :contract_name,
    :command_envelope,
    :permission_decision_ref,
    :workflow_ref,
    :signal_name,
    :signal_version,
    :signal_id,
    :signal_payload_ref,
    :signal_payload,
    :signal_payload_hash
  ]
  defstruct @fields

  @type t :: %__MODULE__{}

  def new(attrs),
    do:
      EnterprisePrecutSupport.build(
        __MODULE__,
        "AppKit.WorkflowSignalRequest.v1",
        @fields,
        [
          :command_envelope,
          :permission_decision_ref,
          :workflow_ref,
          :signal_name,
          :signal_version,
          :signal_id
        ],
        attrs
      )
end

defmodule AppKit.Core.WorkflowQueryRequest do
  @moduledoc "Public-safe workflow query DTO."

  alias AppKit.Core.EnterprisePrecutSupport

  @fields [
    :contract_name,
    :tenant_ref,
    :principal_ref,
    :system_actor_ref,
    :resource_ref,
    :workflow_ref,
    :query_name,
    :query_version,
    :authority_packet_ref,
    :trace_id,
    :redaction_posture
  ]
  defstruct @fields

  @type t :: %__MODULE__{}

  def new(attrs),
    do:
      EnterprisePrecutSupport.build(
        __MODULE__,
        "AppKit.WorkflowQueryRequest.v1",
        @fields,
        [:tenant_ref, :resource_ref, :workflow_ref, :query_name, :query_version, :trace_id],
        attrs,
        require_actor?: true
      )
end

defmodule AppKit.Core.LowerScopeRef do
  @moduledoc "Tenant/authority scope for lower execution, reads, artifacts, and streams."

  alias AppKit.Core.EnterprisePrecutSupport

  @fields [
    :contract_name,
    :tenant_ref,
    :principal_ref,
    :system_actor_ref,
    :resource_ref,
    :lower_run_ref,
    :attempt_ref,
    :artifact_ref,
    :target_ref,
    :stream_ref,
    :authority_packet_ref,
    :permission_decision_ref,
    :lease_ref,
    :epoch_ref,
    :attach_grant_ref,
    :trace_id,
    :redaction_posture
  ]
  defstruct @fields

  @type t :: %__MODULE__{}

  def new(attrs),
    do:
      EnterprisePrecutSupport.build(
        __MODULE__,
        "AppKit.LowerScopeRef.v1",
        @fields,
        [:tenant_ref, :resource_ref, :trace_id],
        attrs,
        require_actor?: true
      )
end

defmodule AppKit.Core.AttachGrantRef do
  @moduledoc "Public-safe, lease-bound attach grant reference."

  alias AppKit.Core.EnterprisePrecutSupport

  @fields [
    :contract_name,
    :attach_grant_id,
    :tenant_ref,
    :principal_ref,
    :resource_ref,
    :stream_ref,
    :lease_ref,
    :expires_at,
    :revocation_state,
    :trace_id
  ]
  defstruct @fields

  @type t :: %__MODULE__{}

  def new(attrs),
    do:
      EnterprisePrecutSupport.build(
        __MODULE__,
        "AppKit.AttachGrantRef.v1",
        @fields,
        [
          :attach_grant_id,
          :tenant_ref,
          :principal_ref,
          :resource_ref,
          :stream_ref,
          :lease_ref,
          :expires_at,
          :revocation_state,
          :trace_id
        ],
        attrs
      )
end

defmodule AppKit.Core.ReviewTaskRef do
  @moduledoc "Public-safe human/operator review task reference."

  alias AppKit.Core.EnterprisePrecutSupport

  @fields [
    :contract_name,
    :review_task_id,
    :tenant_ref,
    :resource_ref,
    :workflow_ref,
    :requested_by_ref,
    :required_action,
    :authority_context_ref,
    :status,
    :trace_id
  ]
  defstruct @fields

  @type t :: %__MODULE__{}

  def new(attrs),
    do:
      EnterprisePrecutSupport.build(
        __MODULE__,
        "AppKit.ReviewTaskRef.v1",
        @fields,
        [
          :review_task_id,
          :tenant_ref,
          :resource_ref,
          :requested_by_ref,
          :required_action,
          :authority_context_ref,
          :status,
          :trace_id
        ],
        attrs
      )
end

defmodule AppKit.Core.Rejection do
  @moduledoc "Public-safe command rejection envelope."

  alias AppKit.Core.EnterprisePrecutSupport

  @fields [
    :contract_name,
    :rejection_id,
    :rejection_class,
    :public_message_code,
    :retry_posture,
    :decision_ref,
    :trace_id,
    :redaction_posture
  ]
  defstruct @fields

  @type t :: %__MODULE__{}

  def new(attrs),
    do:
      EnterprisePrecutSupport.build(
        __MODULE__,
        "AppKit.Rejection.v1",
        @fields,
        [
          :rejection_id,
          :rejection_class,
          :public_message_code,
          :retry_posture,
          :decision_ref,
          :trace_id,
          :redaction_posture
        ],
        attrs
      )
end
