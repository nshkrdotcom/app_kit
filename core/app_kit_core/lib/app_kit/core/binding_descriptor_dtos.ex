defmodule AppKit.Core.BindingEnvelope do
  @moduledoc """
  Stable operational envelope for an external binding descriptor.
  """

  alias AppKit.Core.Support

  @staleness_classes [
    :substrate_authoritative,
    :lower_authoritative_unreconciled,
    :diagnostic_only
  ]
  @trace_propagation_modes [:required]
  @tenant_scopes [:installation_scoped, :tenant_scoped]
  @blast_radii [:local_request, :installation, :tenant, :cross_tenant]

  @enforce_keys [
    :staleness_class,
    :trace_propagation,
    :tenant_scope,
    :blast_radius,
    :runbook_ref
  ]
  defstruct [
    :staleness_class,
    :trace_propagation,
    :tenant_scope,
    :blast_radius,
    :runbook_ref,
    timeout_ms: nil
  ]

  @type t :: %__MODULE__{
          staleness_class:
            :substrate_authoritative | :lower_authoritative_unreconciled | :diagnostic_only,
          trace_propagation: :required,
          tenant_scope: :installation_scoped | :tenant_scoped,
          blast_radius: :local_request | :installation | :tenant | :cross_tenant,
          timeout_ms: pos_integer() | nil,
          runbook_ref: String.t()
        }

  @spec new(map() | keyword()) :: {:ok, t()} | {:error, :invalid_binding_envelope}
  def new(attrs) do
    with {:ok, attrs} <- Support.normalize_attrs(attrs),
         staleness_class <- Map.get(attrs, :staleness_class),
         true <- Support.enum?(staleness_class, @staleness_classes),
         trace_propagation <- Map.get(attrs, :trace_propagation),
         true <- Support.enum?(trace_propagation, @trace_propagation_modes),
         tenant_scope <- Map.get(attrs, :tenant_scope),
         true <- Support.enum?(tenant_scope, @tenant_scopes),
         blast_radius <- Map.get(attrs, :blast_radius),
         true <- Support.enum?(blast_radius, @blast_radii),
         timeout_ms <- Map.get(attrs, :timeout_ms),
         true <- is_nil(timeout_ms) or Support.positive_integer?(timeout_ms),
         runbook_ref <- Map.get(attrs, :runbook_ref),
         true <- Support.present_binary?(runbook_ref) do
      {:ok,
       %__MODULE__{
         staleness_class: staleness_class,
         trace_propagation: trace_propagation,
         tenant_scope: tenant_scope,
         blast_radius: blast_radius,
         timeout_ms: timeout_ms,
         runbook_ref: runbook_ref
       }}
    else
      _ -> {:error, :invalid_binding_envelope}
    end
  end
end

defmodule AppKit.Core.BindingFailurePosture do
  @moduledoc """
  Stable failure posture for an external binding descriptor.
  """

  alias AppKit.Core.Support

  @unavailable_postures [
    :proceed_without,
    :retry_background,
    :fail_execution,
    :fail_installation_health
  ]
  @timeout_postures [:proceed_without, :retry_background, :fail_execution]

  @enforce_keys [:on_unavailable, :on_timeout]
  defstruct [:on_unavailable, :on_timeout]

  @type t :: %__MODULE__{
          on_unavailable:
            :proceed_without | :retry_background | :fail_execution | :fail_installation_health,
          on_timeout: :proceed_without | :retry_background | :fail_execution
        }

  @spec new(map() | keyword()) :: {:ok, t()} | {:error, :invalid_binding_failure_posture}
  def new(attrs) do
    with {:ok, attrs} <- Support.normalize_attrs(attrs),
         on_unavailable <- Map.get(attrs, :on_unavailable),
         true <- Support.enum?(on_unavailable, @unavailable_postures),
         on_timeout <- Map.get(attrs, :on_timeout),
         true <- Support.enum?(on_timeout, @timeout_postures) do
      {:ok, %__MODULE__{on_unavailable: on_unavailable, on_timeout: on_timeout}}
    else
      _ -> {:error, :invalid_binding_failure_posture}
    end
  end
end

defmodule AppKit.Core.BindingOwnership do
  @moduledoc """
  Stable ownership envelope for an external binding descriptor.
  """

  alias AppKit.Core.Support

  @enforce_keys [:external_system, :external_system_ref]
  defstruct [:external_system, :external_system_ref, operator_owner: nil]

  @type t :: %__MODULE__{
          external_system: String.t(),
          external_system_ref: String.t(),
          operator_owner: String.t() | nil
        }

  @spec new(map() | keyword()) :: {:ok, t()} | {:error, :invalid_binding_ownership}
  def new(attrs) do
    with {:ok, attrs} <- Support.normalize_attrs(attrs),
         external_system <- Map.get(attrs, :external_system),
         true <- Support.present_binary?(external_system),
         external_system_ref <- Map.get(attrs, :external_system_ref),
         true <- Support.present_binary?(external_system_ref),
         operator_owner <- Map.get(attrs, :operator_owner),
         true <- Support.optional_binary?(operator_owner) do
      {:ok,
       %__MODULE__{
         external_system: external_system,
         external_system_ref: external_system_ref,
         operator_owner: operator_owner
       }}
    else
      _ -> {:error, :invalid_binding_ownership}
    end
  end
end

defmodule AppKit.Core.BindingDescriptor do
  @moduledoc """
  Stable binding descriptor for routing external systems through one seam.
  """

  alias AppKit.Core.{BindingEnvelope, BindingFailurePosture, BindingOwnership, Support}

  @attachments [
    "outer_brain.context_adapter",
    "mezzanine.execution_recipe",
    "mezzanine.subject_kind",
    "jido_integration.audit_subscriber"
  ]
  @contracts [:advisory, :contributing, :authoritative]

  @enforce_keys [:attachment, :contract, :envelope, :failure, :ownership]
  defstruct [:attachment, :contract, :envelope, :failure, :ownership]

  @type attachment :: String.t()

  @type contract :: :advisory | :contributing | :authoritative

  @type t :: %__MODULE__{
          attachment: attachment(),
          contract: contract(),
          envelope: BindingEnvelope.t(),
          failure: BindingFailurePosture.t(),
          ownership: BindingOwnership.t()
        }

  @spec new(map() | keyword()) :: {:ok, t()} | {:error, :invalid_binding_descriptor}
  def new(attrs) do
    with {:ok, attrs} <- Support.normalize_attrs(attrs),
         attachment <- Map.get(attrs, :attachment),
         true <- attachment in @attachments,
         contract <- Map.get(attrs, :contract),
         true <- Support.enum?(contract, @contracts),
         {:ok, envelope} <- Support.nested_struct(Map.get(attrs, :envelope), BindingEnvelope),
         false <- is_nil(envelope),
         {:ok, failure} <-
           Support.nested_struct(Map.get(attrs, :failure), BindingFailurePosture),
         false <- is_nil(failure),
         {:ok, ownership} <- Support.nested_struct(Map.get(attrs, :ownership), BindingOwnership),
         false <- is_nil(ownership) do
      {:ok,
       %__MODULE__{
         attachment: attachment,
         contract: contract,
         envelope: envelope,
         failure: failure,
         ownership: ownership
       }}
    else
      _ -> {:error, :invalid_binding_descriptor}
    end
  end
end
