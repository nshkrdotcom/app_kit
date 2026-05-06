defmodule AppKit.PromptSurface do
  @moduledoc """
  DTO-only prompt surface.
  """

  alias OuterBrain.PromptFabric

  defmodule PromptAuthorRequest do
    @moduledoc "Prompt authoring request DTO."
    @enforce_keys [
      :request_ref,
      :tenant_ref,
      :authority_ref,
      :installation_ref,
      :prompt_id,
      :content_hash
    ]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            request_ref: String.t(),
            tenant_ref: String.t(),
            authority_ref: String.t(),
            installation_ref: String.t(),
            prompt_id: String.t(),
            content_hash: String.t()
          }
  end

  defmodule PromptPromoteRequest do
    @moduledoc "Prompt promotion request DTO."
    @enforce_keys [
      :request_ref,
      :prompt_ref,
      :eval_suite_ref,
      :guard_chain_ref,
      :decision_evidence_ref
    ]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            request_ref: String.t(),
            prompt_ref: PromptFabric.PromptArtifactRef.t(),
            eval_suite_ref: String.t(),
            guard_chain_ref: String.t(),
            decision_evidence_ref: String.t()
          }
  end

  defmodule PromptRollbackRequest do
    @moduledoc "Forward-only prompt rollback request DTO."
    @enforce_keys [:request_ref, :prompt_id, :target_revision, :decision_evidence_ref]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            request_ref: String.t(),
            prompt_id: String.t(),
            target_revision: pos_integer(),
            decision_evidence_ref: String.t()
          }
  end

  defmodule PromptABAssignRequest do
    @moduledoc "Prompt A/B assignment request DTO."
    @enforce_keys [:request_ref, :prompt_id, :variant_revisions, :ab_assignment_key]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            request_ref: String.t(),
            prompt_id: String.t(),
            variant_revisions: [pos_integer()],
            ab_assignment_key: String.t()
          }
  end

  defmodule PromptViewProjection do
    @moduledoc "Redacted prompt view projection DTO."
    @enforce_keys [:prompt_ref, :content_hash, :lineage_ref, :redaction_policy_ref]
    defstruct [:redacted_excerpt | @enforce_keys]

    @type t :: %__MODULE__{
            prompt_ref: PromptFabric.PromptArtifactRef.t(),
            content_hash: String.t(),
            lineage_ref: String.t(),
            redaction_policy_ref: String.t(),
            redacted_excerpt: String.t() | nil
          }
  end

  defmodule PromptLineageProjection do
    @moduledoc "Prompt lineage projection DTO."
    @enforce_keys [
      :lineage_ref,
      :prompt_id,
      :revision,
      :derivation_reason,
      :decision_evidence_ref
    ]
    defstruct [:parent_revision | @enforce_keys]

    @type t :: %__MODULE__{
            lineage_ref: String.t(),
            prompt_id: String.t(),
            revision: pos_integer(),
            derivation_reason: atom(),
            decision_evidence_ref: String.t(),
            parent_revision: pos_integer() | nil
          }
  end

  @raw_keys [
    :body,
    :raw_body,
    :prompt_body,
    :raw_prompt,
    :content,
    :raw_content,
    "body",
    "raw_body",
    "prompt_body",
    "raw_prompt",
    "content",
    "raw_content"
  ]

  @spec author_request(map()) :: {:ok, PromptAuthorRequest.t()} | {:error, term()}
  def author_request(attrs) when is_map(attrs) do
    with :ok <- reject_raw(attrs),
         :ok <-
           required_strings(attrs, [
             :request_ref,
             :tenant_ref,
             :authority_ref,
             :installation_ref,
             :prompt_id,
             :content_hash
           ]) do
      {:ok,
       %PromptAuthorRequest{
         request_ref: fetch!(attrs, :request_ref),
         tenant_ref: fetch!(attrs, :tenant_ref),
         authority_ref: fetch!(attrs, :authority_ref),
         installation_ref: fetch!(attrs, :installation_ref),
         prompt_id: fetch!(attrs, :prompt_id),
         content_hash: fetch!(attrs, :content_hash)
       }}
    end
  end

  @spec promote_request(map()) :: {:ok, PromptPromoteRequest.t()} | {:error, term()}
  def promote_request(attrs) when is_map(attrs) do
    with :ok <- reject_raw(attrs),
         :ok <-
           required_strings(attrs, [
             :request_ref,
             :eval_suite_ref,
             :guard_chain_ref,
             :decision_evidence_ref
           ]),
         {:ok, prompt_ref} <- attrs |> fetch(:prompt_ref) |> PromptFabric.artifact_ref() do
      {:ok,
       %PromptPromoteRequest{
         request_ref: fetch!(attrs, :request_ref),
         prompt_ref: prompt_ref,
         eval_suite_ref: fetch!(attrs, :eval_suite_ref),
         guard_chain_ref: fetch!(attrs, :guard_chain_ref),
         decision_evidence_ref: fetch!(attrs, :decision_evidence_ref)
       }}
    end
  end

  @spec rollback_request(map()) :: {:ok, PromptRollbackRequest.t()} | {:error, term()}
  def rollback_request(attrs) when is_map(attrs) do
    with :ok <- reject_raw(attrs),
         :ok <- required_strings(attrs, [:request_ref, :prompt_id, :decision_evidence_ref]),
         {:ok, target_revision} <- positive_integer(attrs, :target_revision) do
      {:ok,
       %PromptRollbackRequest{
         request_ref: fetch!(attrs, :request_ref),
         prompt_id: fetch!(attrs, :prompt_id),
         target_revision: target_revision,
         decision_evidence_ref: fetch!(attrs, :decision_evidence_ref)
       }}
    end
  end

  @spec ab_assign_request(map()) :: {:ok, PromptABAssignRequest.t()} | {:error, term()}
  def ab_assign_request(attrs) when is_map(attrs) do
    with :ok <- reject_raw(attrs),
         :ok <- required_strings(attrs, [:request_ref, :prompt_id, :ab_assignment_key]),
         revisions when is_list(revisions) and revisions != [] <- fetch(attrs, :variant_revisions) do
      {:ok,
       %PromptABAssignRequest{
         request_ref: fetch!(attrs, :request_ref),
         prompt_id: fetch!(attrs, :prompt_id),
         variant_revisions: revisions,
         ab_assignment_key: fetch!(attrs, :ab_assignment_key)
       }}
    else
      _other -> {:error, :invalid_prompt_ab_assignment}
    end
  end

  @spec view_projection(map()) :: {:ok, PromptViewProjection.t()} | {:error, term()}
  def view_projection(attrs) when is_map(attrs) do
    with :ok <- reject_raw(attrs),
         {:ok, prompt_ref} <- attrs |> fetch(:prompt_ref) |> PromptFabric.artifact_ref(),
         :ok <- required_strings(attrs, [:content_hash, :lineage_ref, :redaction_policy_ref]) do
      {:ok,
       %PromptViewProjection{
         prompt_ref: prompt_ref,
         content_hash: fetch!(attrs, :content_hash),
         lineage_ref: fetch!(attrs, :lineage_ref),
         redaction_policy_ref: fetch!(attrs, :redaction_policy_ref),
         redacted_excerpt: optional_string(attrs, :redacted_excerpt)
       }}
    end
  end

  @spec lineage_projection(map()) :: {:ok, PromptLineageProjection.t()} | {:error, term()}
  def lineage_projection(attrs) when is_map(attrs) do
    with {:ok, lineage} <- PromptFabric.lineage_ref(attrs) do
      {:ok,
       %PromptLineageProjection{
         lineage_ref: lineage.lineage_ref,
         prompt_id: lineage.prompt_id,
         revision: lineage.revision,
         parent_revision: lineage.parent_revision,
         derivation_reason: lineage.derivation_reason,
         decision_evidence_ref: lineage.decision_evidence_ref
       }}
    end
  end

  defp reject_raw(attrs) do
    case Enum.find(@raw_keys, &Map.has_key?(attrs, &1)) do
      nil -> :ok
      key -> {:error, {:raw_prompt_surface_payload_forbidden, key}}
    end
  end

  defp required_strings(attrs, fields) do
    case Enum.find(fields, &(not present_string?(fetch(attrs, &1)))) do
      nil -> :ok
      field -> {:error, {:missing_prompt_surface_ref, field}}
    end
  end

  defp positive_integer(attrs, field) do
    case fetch(attrs, field) do
      value when is_integer(value) and value > 0 -> {:ok, value}
      _value -> {:error, {:invalid_prompt_surface_field, field}}
    end
  end

  defp optional_string(attrs, field) do
    case fetch(attrs, field) do
      value when is_binary(value) and value != "" -> value
      _value -> nil
    end
  end

  defp present_string?(value) when is_binary(value), do: String.trim(value) != ""
  defp present_string?(_value), do: false
  defp fetch!(attrs, field), do: fetch(attrs, field)
  defp fetch(attrs, field), do: Map.get(attrs, field) || Map.get(attrs, Atom.to_string(field))
end
