defmodule AppKit.Core.ErrorTaxonomyProjection do
  @moduledoc """
  Northbound operator DTO for platform error taxonomy evidence.

  Contract: `Platform.ErrorTaxonomy.v1`.
  """

  alias AppKit.Core.RevisionEpochSupport

  @contract_name "Platform.ErrorTaxonomy.v1"
  @error_classes [
    "auth_error",
    "validation_error",
    "policy_error",
    "tenant_scope_error",
    "semantic_failure",
    "runtime_error",
    "resource_pressure"
  ]
  @retry_postures [
    "never",
    "safe_idempotent",
    "after_input_change",
    "after_operator_action",
    "after_backoff",
    "after_redecision",
    "manual_operator"
  ]
  @redaction_classes [
    "public_safe",
    "operator_summary",
    "operator_full",
    "tenant_sensitive",
    "secret"
  ]
  @required_binary_fields RevisionEpochSupport.base_binary_fields() ++
                            [
                              :error_taxonomy_id,
                              :owner_repo,
                              :producer_ref,
                              :consumer_ref,
                              :error_code,
                              :operator_safe_action,
                              :safe_action_code,
                              :runbook_path
                            ]
  @optional_binary_fields RevisionEpochSupport.optional_actor_fields() ++ [:operator_message_ref]

  defstruct [
    :contract_name,
    :tenant_ref,
    :installation_ref,
    :workspace_ref,
    :project_ref,
    :environment_ref,
    :principal_ref,
    :system_actor_ref,
    :resource_ref,
    :authority_packet_ref,
    :permission_decision_ref,
    :idempotency_key,
    :trace_id,
    :correlation_id,
    :release_manifest_ref,
    :error_taxonomy_id,
    :owner_repo,
    :producer_ref,
    :consumer_ref,
    :error_code,
    :error_class,
    :retry_posture,
    :operator_safe_action,
    :safe_action_code,
    :redaction_class,
    :runbook_path,
    :operator_message_ref
  ]

  @type t :: %__MODULE__{}

  @spec contract_name() :: String.t()
  def contract_name, do: @contract_name

  @spec new(map() | keyword()) ::
          {:ok, t()}
          | {:error, {:missing_required_fields, [atom()]}}
          | {:error, :invalid_error_taxonomy_projection}
  def new(attrs) do
    with {:ok, attrs} <- RevisionEpochSupport.normalize_attrs(attrs),
         [] <-
           RevisionEpochSupport.missing_required_fields(
             attrs,
             @required_binary_fields,
             []
           ),
         true <- RevisionEpochSupport.optional_binary_fields?(attrs, @optional_binary_fields),
         {:ok, error_class} <-
           RevisionEpochSupport.enum_string(Map.get(attrs, :error_class), @error_classes),
         {:ok, retry_posture} <-
           RevisionEpochSupport.enum_string(Map.get(attrs, :retry_posture), @retry_postures),
         {:ok, redaction_class} <-
           RevisionEpochSupport.enum_string(Map.get(attrs, :redaction_class), @redaction_classes),
         :ok <- validate_safe_action_match(attrs) do
      {:ok, build(attrs, error_class, retry_posture, redaction_class)}
    else
      fields when is_list(fields) -> {:error, {:missing_required_fields, fields}}
      _error -> {:error, :invalid_error_taxonomy_projection}
    end
  end

  defp build(attrs, error_class, retry_posture, redaction_class) do
    struct!(
      __MODULE__,
      Map.merge(attrs, %{
        contract_name: @contract_name,
        error_class: error_class,
        retry_posture: retry_posture,
        redaction_class: redaction_class
      })
    )
  end

  defp validate_safe_action_match(attrs) do
    if Map.fetch!(attrs, :operator_safe_action) == Map.fetch!(attrs, :safe_action_code) do
      :ok
    else
      :error
    end
  end
end
