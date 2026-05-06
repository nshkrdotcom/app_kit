defmodule AppKit.PolicyAuthoring do
  @moduledoc """
  DTO-only policy authoring view models.
  """

  alias AppKit.Web.Components

  defmodule PolicyDiff do
    @moduledoc "Bounded policy diff projection."
    @type t :: %__MODULE__{
            diff_ref: String.t(),
            tenant_ref: String.t(),
            from_policy_ref: String.t(),
            to_policy_ref: String.t(),
            change_refs: [String.t()]
          }

    @enforce_keys [:diff_ref, :tenant_ref, :from_policy_ref, :to_policy_ref, :change_refs]
    defstruct @enforce_keys
  end

  defmodule PromotionRequest do
    @moduledoc "Human-approved policy promotion request."
    @type t :: %__MODULE__{
            request_ref: String.t(),
            tenant_ref: String.t(),
            prompt_ref: String.t(),
            guard_chain_ref: String.t(),
            budget_policy_ref: String.t(),
            connector_policy_ref: String.t(),
            decision_evidence_ref: String.t()
          }

    @enforce_keys [
      :request_ref,
      :tenant_ref,
      :prompt_ref,
      :guard_chain_ref,
      :budget_policy_ref,
      :connector_policy_ref,
      :decision_evidence_ref
    ]
    defstruct @enforce_keys
  end

  defmodule RollbackRequest do
    @moduledoc "Forward-only rollback request."
    @type t :: %__MODULE__{
            request_ref: String.t(),
            tenant_ref: String.t(),
            policy_ref: String.t(),
            target_revision: pos_integer(),
            new_revision: pos_integer(),
            decision_evidence_ref: String.t()
          }

    @enforce_keys [
      :request_ref,
      :tenant_ref,
      :policy_ref,
      :target_revision,
      :new_revision,
      :decision_evidence_ref
    ]
    defstruct @enforce_keys
  end

  @raw_keys [
    :body,
    :raw_body,
    :payload,
    :raw_payload,
    :prompt_body,
    :guard_payload,
    :connector_secret,
    :budget_amount,
    "body",
    "raw_body",
    "payload",
    "raw_payload",
    "prompt_body",
    "guard_payload",
    "connector_secret",
    "budget_amount"
  ]

  @spec diff(map()) :: {:ok, PolicyDiff.t()} | {:error, term()}
  def diff(attrs) when is_map(attrs) do
    with :ok <- reject_raw(attrs),
         :ok <- Components.reject_raw_assigns(attrs),
         {:ok, diff_ref} <- required_string(attrs, :diff_ref),
         {:ok, tenant_ref} <- required_string(attrs, :tenant_ref),
         {:ok, from_policy_ref} <- required_string(attrs, :from_policy_ref),
         {:ok, to_policy_ref} <- required_string(attrs, :to_policy_ref),
         {:ok, change_refs} <- string_list(attrs, :change_refs) do
      {:ok,
       %PolicyDiff{
         diff_ref: diff_ref,
         tenant_ref: tenant_ref,
         from_policy_ref: from_policy_ref,
         to_policy_ref: to_policy_ref,
         change_refs: change_refs
       }}
    end
  end

  def diff(_attrs), do: {:error, :invalid_policy_diff}

  @spec promote(map()) :: {:ok, PromotionRequest.t()} | {:error, term()}
  def promote(attrs) when is_map(attrs) do
    with :ok <- reject_raw(attrs),
         :ok <- Components.reject_raw_assigns(attrs),
         :ok <-
           required_strings(attrs, [
             :request_ref,
             :tenant_ref,
             :prompt_ref,
             :guard_chain_ref,
             :budget_policy_ref,
             :connector_policy_ref,
             :decision_evidence_ref
           ]) do
      {:ok,
       %PromotionRequest{
         request_ref: fetch!(attrs, :request_ref),
         tenant_ref: fetch!(attrs, :tenant_ref),
         prompt_ref: fetch!(attrs, :prompt_ref),
         guard_chain_ref: fetch!(attrs, :guard_chain_ref),
         budget_policy_ref: fetch!(attrs, :budget_policy_ref),
         connector_policy_ref: fetch!(attrs, :connector_policy_ref),
         decision_evidence_ref: fetch!(attrs, :decision_evidence_ref)
       }}
    end
  end

  def promote(_attrs), do: {:error, :invalid_policy_promotion}

  @spec rollback(map()) :: {:ok, RollbackRequest.t()} | {:error, term()}
  def rollback(attrs) when is_map(attrs) do
    with :ok <- reject_raw(attrs),
         :ok <- Components.reject_raw_assigns(attrs),
         :ok <-
           required_strings(attrs, [
             :request_ref,
             :tenant_ref,
             :policy_ref,
             :decision_evidence_ref
           ]),
         {:ok, target_revision} <- positive_integer(attrs, :target_revision),
         {:ok, new_revision} <- positive_integer(attrs, :new_revision),
         :ok <- forward_revision(target_revision, new_revision) do
      {:ok,
       %RollbackRequest{
         request_ref: fetch!(attrs, :request_ref),
         tenant_ref: fetch!(attrs, :tenant_ref),
         policy_ref: fetch!(attrs, :policy_ref),
         target_revision: target_revision,
         new_revision: new_revision,
         decision_evidence_ref: fetch!(attrs, :decision_evidence_ref)
       }}
    end
  end

  def rollback(_attrs), do: {:error, :invalid_policy_rollback}

  defp forward_revision(target_revision, new_revision) do
    if new_revision > target_revision do
      :ok
    else
      {:error, :policy_rollback_must_create_forward_revision}
    end
  end

  defp reject_raw(attrs) do
    case Enum.find(@raw_keys, &Map.has_key?(attrs, &1)) do
      nil -> :ok
      key -> {:error, {:raw_policy_authoring_payload_forbidden, key}}
    end
  end

  defp string_list(attrs, field) do
    case fetch(attrs, field) do
      values when is_list(values) -> strings_if_safe(values, field)
      _values -> {:error, {:invalid_policy_authoring_refs, field}}
    end
  end

  defp strings_if_safe(values, field) do
    if Enum.all?(values, &present_string?/1) do
      {:ok, values}
    else
      {:error, {:invalid_policy_authoring_refs, field}}
    end
  end

  defp required_strings(attrs, fields) do
    case Enum.find(fields, &(not present_string?(fetch(attrs, &1)))) do
      nil -> :ok
      field -> {:error, {:missing_policy_authoring_ref, field}}
    end
  end

  defp required_string(attrs, field) do
    case fetch(attrs, field) do
      value when is_binary(value) and value != "" -> {:ok, value}
      _value -> {:error, {:missing_policy_authoring_ref, field}}
    end
  end

  defp positive_integer(attrs, field) do
    case fetch(attrs, field) do
      value when is_integer(value) and value > 0 -> {:ok, value}
      _value -> {:error, {:invalid_policy_revision, field}}
    end
  end

  defp present_string?(value), do: is_binary(value) and String.trim(value) != ""
  defp fetch!(attrs, field), do: fetch(attrs, field)
  defp fetch(attrs, field), do: Map.get(attrs, field) || Map.get(attrs, Atom.to_string(field))
end
