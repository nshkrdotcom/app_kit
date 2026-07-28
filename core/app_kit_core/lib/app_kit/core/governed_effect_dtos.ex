defmodule AppKit.Core.GovernedEffectDTOSupport do
  @moduledoc false

  alias AppKit.Core.Substrate.Dump

  @forbidden_field_fragments ~w[
    access_token api_key authorization base_url callback codex_home
    credential_material environment password private_key provider_payload raw_payload
    raw_secret rollback_callback secret shell_env token workspace_root
  ]
  @forbidden_field_names ~w[content file_content home prompt]

  def normalize(attrs) when is_list(attrs), do: {:ok, Map.new(attrs)}
  def normalize(%_{} = attrs), do: {:ok, Map.from_struct(attrs)}
  def normalize(attrs) when is_map(attrs), do: {:ok, attrs}
  def normalize(_attrs), do: {:error, :invalid_attrs}

  def value(attrs, key) when is_map(attrs),
    do: Map.get(attrs, key, Map.get(attrs, to_string(key)))

  def required_string(attrs, key) do
    case string(attrs, key) do
      value when is_binary(value) -> {:ok, value}
      _missing -> {:error, {:missing_required_string, key}}
    end
  end

  def required_positive_integer(attrs, key) do
    case value(attrs, key) do
      value when is_integer(value) and value > 0 -> {:ok, value}
      _missing -> {:error, {:missing_required_positive_integer, key}}
    end
  end

  def string(attrs, key), do: value(attrs, key) |> string_value()
  def string_value(nil), do: nil
  def string_value(value) when is_atom(value), do: Atom.to_string(value)
  def string_value(value) when is_binary(value) and value != "", do: value
  def string_value(_value), do: nil

  def optional_integer(attrs, key) do
    case value(attrs, key) do
      nil -> nil
      value when is_integer(value) -> value
      _other -> :invalid
    end
  end

  def optional_boolean(attrs, key) do
    case value(attrs, key) do
      nil -> nil
      value when is_boolean(value) -> value
      _other -> :invalid
    end
  end

  def optional_map(attrs, key, default \\ %{}) do
    case value(attrs, key) do
      nil -> default
      %_{} = nested -> nested |> Map.from_struct() |> stringify_keys()
      value when is_map(value) -> stringify_keys(value)
      _other -> :invalid
    end
  end

  def optional_list(attrs, key, default \\ []) do
    case value(attrs, key) do
      nil -> default
      value when is_list(value) -> stringify_keys(value)
      _other -> :invalid
    end
  end

  def only_keys?(attrs, keys) do
    allowed = MapSet.new(Enum.flat_map(keys, &[&1, Atom.to_string(&1)]))
    Enum.all?(Map.keys(attrs), &MapSet.member?(allowed, &1))
  end

  def reject_forbidden_material(attrs) when is_map(attrs) do
    if forbidden_material?(attrs), do: :error, else: :ok
  end

  def serializable?(%DateTime{}), do: true
  def serializable?(%NaiveDateTime{}), do: true
  def serializable?(value) when is_binary(value), do: true
  def serializable?(value) when is_number(value), do: true
  def serializable?(value) when is_boolean(value), do: true
  def serializable?(nil), do: true
  def serializable?(value) when is_atom(value), do: true
  def serializable?(value) when is_list(value), do: Enum.all?(value, &serializable?/1)

  def serializable?(%_{} = value), do: value |> Map.from_struct() |> serializable?()

  def serializable?(value) when is_map(value) do
    Enum.all?(value, fn {key, nested} ->
      (is_atom(key) or is_binary(key) or is_integer(key)) and serializable?(nested)
    end)
  end

  def serializable?(_value), do: false

  def safe_ref?(value) when is_binary(value) do
    value != "" and not String.starts_with?(value, "/") and
      not String.contains?(value, <<0>>)
  end

  def safe_ref?(_value), do: false

  def sha256?("sha256:" <> digest),
    do: byte_size(digest) == 64 and String.match?(digest, ~r/\A[0-9a-f]{64}\z/)

  def sha256?(_value), do: false

  def relative_file?(path) when is_binary(path) do
    segments = Path.split(path)

    path != "" and Path.type(path) == :relative and segments != [] and
      Enum.all?(segments, &(&1 not in [".", "..", ""]))
  end

  def relative_file?(_path), do: false

  def dump(%_{} = dto) do
    dto
    |> Map.from_struct()
    |> Dump.dump_value()
    |> Map.reject(fn {_key, value} -> is_nil(value) end)
  end

  def stringify_keys(%_{} = value), do: value |> Map.from_struct() |> stringify_keys()

  def stringify_keys(%{} = value),
    do: Map.new(value, fn {key, item} -> {to_string(key), stringify_keys(item)} end)

  def stringify_keys(values) when is_list(values), do: Enum.map(values, &stringify_keys/1)
  def stringify_keys(value) when is_atom(value), do: Atom.to_string(value)
  def stringify_keys(value), do: value

  defp forbidden_material?(%_{} = attrs),
    do: attrs |> Map.from_struct() |> forbidden_material?()

  defp forbidden_material?(%{} = attrs) do
    Enum.any?(attrs, fn {key, value} ->
      forbidden_key?(key) or forbidden_material?(value)
    end)
  end

  defp forbidden_material?(values) when is_list(values),
    do: Enum.any?(values, &forbidden_material?/1)

  defp forbidden_material?(_value), do: false

  defp forbidden_key?(key) when is_atom(key), do: key |> Atom.to_string() |> forbidden_key?()

  defp forbidden_key?(key) when is_binary(key) do
    normalized = String.downcase(key)

    normalized in @forbidden_field_names or
      Enum.any?(@forbidden_field_fragments, &String.contains?(normalized, &1))
  end

  defp forbidden_key?(_key), do: false
end

defmodule AppKit.Core.GovernedEffectProposalDTO do
  @moduledoc """
  Product-safe proposal for one reviewed named-file effect.

  The proposal carries immutable owner identities and digests. It intentionally
  cannot carry file contents, a workspace root, credentials, shell environment,
  or provider routing.
  """

  alias AppKit.Core.GovernedEffectDTOSupport, as: Support

  @fields [
    :effect_ref,
    :run_ref,
    :turn_ref,
    :command_ref,
    :decision_ref,
    :grant_ref,
    :review_ref,
    :subject_id,
    :run_id,
    :review_unit_id,
    :target_ref,
    :attempt_ref,
    :capability_id,
    :effect_mode,
    :pinned_tool_manifest,
    :reviewed_operation
  ]
  @enforce_keys @fields
  defstruct @fields

  @type t :: %__MODULE__{}

  def new(%__MODULE__{} = value), do: value |> Map.from_struct() |> new()

  def new(attrs) do
    with {:ok, attrs} <- Support.normalize(attrs),
         true <- Support.only_keys?(attrs, @fields),
         :ok <- Support.reject_forbidden_material(attrs),
         true <- Support.serializable?(attrs),
         {:ok, effect_ref} <- Support.required_string(attrs, :effect_ref),
         {:ok, run_ref} <- Support.required_string(attrs, :run_ref),
         {:ok, turn_ref} <- Support.required_string(attrs, :turn_ref),
         {:ok, command_ref} <- Support.required_string(attrs, :command_ref),
         {:ok, decision_ref} <- Support.required_string(attrs, :decision_ref),
         {:ok, grant_ref} <- Support.required_string(attrs, :grant_ref),
         {:ok, review_ref} <- Support.required_string(attrs, :review_ref),
         {:ok, subject_id} <- Support.required_string(attrs, :subject_id),
         {:ok, run_id} <- Support.required_string(attrs, :run_id),
         {:ok, review_unit_id} <- Support.required_string(attrs, :review_unit_id),
         {:ok, target_ref} <- Support.required_string(attrs, :target_ref),
         {:ok, attempt_ref} <- Support.required_string(attrs, :attempt_ref),
         {:ok, capability_id} <- Support.required_string(attrs, :capability_id),
         {:ok, effect_mode} <- Support.required_string(attrs, :effect_mode),
         manifest when is_map(manifest) <- Support.optional_map(attrs, :pinned_tool_manifest),
         operation when is_map(operation) <- Support.optional_map(attrs, :reviewed_operation) do
      validate(%__MODULE__{
        effect_ref: effect_ref,
        run_ref: run_ref,
        turn_ref: turn_ref,
        command_ref: command_ref,
        decision_ref: decision_ref,
        grant_ref: grant_ref,
        review_ref: review_ref,
        subject_id: subject_id,
        run_id: run_id,
        review_unit_id: review_unit_id,
        target_ref: target_ref,
        attempt_ref: attempt_ref,
        capability_id: capability_id,
        effect_mode: effect_mode,
        pinned_tool_manifest: manifest,
        reviewed_operation: operation
      })
    else
      _other -> {:error, :invalid_governed_effect_proposal}
    end
  end

  def dump(%__MODULE__{} = value), do: Support.dump(value)

  defp validate(%__MODULE__{} = proposal) do
    refs = [
      proposal.effect_ref,
      proposal.run_ref,
      proposal.turn_ref,
      proposal.command_ref,
      proposal.decision_ref,
      proposal.grant_ref,
      proposal.review_ref,
      proposal.target_ref,
      proposal.attempt_ref
    ]

    with true <- Enum.all?(refs, &Support.safe_ref?/1),
         true <- proposal.capability_id == "codex.session.turn",
         true <- proposal.effect_mode == "managed_account_local_effect",
         :ok <- validate_manifest(proposal.pinned_tool_manifest),
         :ok <- validate_operation(proposal.reviewed_operation) do
      {:ok, proposal}
    else
      _other -> {:error, :invalid_governed_effect_proposal}
    end
  end

  defp validate_manifest(manifest) do
    if Support.only_keys?(manifest, [:manifest_ref, :manifest_hash, :action_ids]) and
         Support.safe_ref?(manifest["manifest_ref"]) and
         Support.sha256?(manifest["manifest_hash"]) and
         manifest["action_ids"] == ["create_or_replace_one_named_text_file"] do
      :ok
    else
      {:error, :invalid_pinned_tool_manifest}
    end
  end

  defp validate_operation(operation) do
    if Support.only_keys?(
         operation,
         [:operation, :workspace_ref, :file_ref, :relative_path, :content_digest]
       ) and
         operation["operation"] == "create_or_replace" and
         Support.safe_ref?(operation["workspace_ref"]) and
         Support.safe_ref?(operation["file_ref"]) and
         Support.relative_file?(operation["relative_path"]) and
         Support.sha256?(operation["content_digest"]) do
      :ok
    else
      {:error, :invalid_reviewed_operation}
    end
  end
end

defmodule AppKit.Core.EffectReviewDTO do
  @moduledoc "Product-safe durable review state attached to a governed effect."

  alias AppKit.Core.GovernedEffectDTOSupport, as: Support

  @fields [:review_ref, :review_unit_id, :status, :row_version, :accepted_actor_ref]
  @enforce_keys [:review_ref, :review_unit_id, :status, :row_version]
  defstruct @fields

  @type t :: %__MODULE__{}

  def new(%__MODULE__{} = value), do: value |> Map.from_struct() |> new()

  def new(attrs) do
    with {:ok, attrs} <- Support.normalize(attrs),
         true <- Support.only_keys?(attrs, @fields),
         :ok <- Support.reject_forbidden_material(attrs),
         {:ok, review_ref} <- Support.required_string(attrs, :review_ref),
         {:ok, review_unit_id} <- Support.required_string(attrs, :review_unit_id),
         {:ok, status} <- Support.required_string(attrs, :status),
         {:ok, row_version} <- Support.required_positive_integer(attrs, :row_version),
         true <- status in ~w(pending in_review accepted rejected waived escalated) do
      {:ok,
       %__MODULE__{
         review_ref: review_ref,
         review_unit_id: review_unit_id,
         status: status,
         row_version: row_version,
         accepted_actor_ref: Support.string(attrs, :accepted_actor_ref)
       }}
    else
      _other -> {:error, :invalid_effect_review_dto}
    end
  end

  def dump(%__MODULE__{} = value), do: Support.dump(value)
end

defmodule AppKit.Core.EffectCleanupDTO do
  @moduledoc "Safe cleanup evidence; never contains a materialized path or secret."

  alias AppKit.Core.GovernedEffectDTOSupport, as: Support

  @fields [
    :status,
    :cleanup_ref,
    :managed_session_ref,
    :credential_lease_ref,
    :materialization_ref,
    :session_terminated,
    :materialization_removed,
    :credential_lease_released
  ]
  @enforce_keys [:status]
  defstruct @fields

  @type t :: %__MODULE__{}

  def new(%__MODULE__{} = value), do: value |> Map.from_struct() |> new()

  def new(attrs) do
    with {:ok, attrs} <- Support.normalize(attrs),
         true <- Support.only_keys?(attrs, @fields),
         :ok <- Support.reject_forbidden_material(attrs),
         {:ok, status} <- Support.required_string(attrs, :status),
         true <- status in ~w(completed partial failed),
         session_terminated <- Support.optional_boolean(attrs, :session_terminated),
         true <- session_terminated != :invalid,
         materialization_removed <- Support.optional_boolean(attrs, :materialization_removed),
         true <- materialization_removed != :invalid,
         credential_lease_released <-
           Support.optional_boolean(attrs, :credential_lease_released),
         true <- credential_lease_released != :invalid,
         {:ok, cleanup_ref} <- optional_safe_ref(attrs, :cleanup_ref),
         {:ok, managed_session_ref} <- optional_safe_ref(attrs, :managed_session_ref),
         {:ok, credential_lease_ref} <- optional_safe_ref(attrs, :credential_lease_ref),
         {:ok, materialization_ref} <- optional_safe_ref(attrs, :materialization_ref) do
      {:ok,
       %__MODULE__{
         status: status,
         cleanup_ref: cleanup_ref,
         managed_session_ref: managed_session_ref,
         credential_lease_ref: credential_lease_ref,
         materialization_ref: materialization_ref,
         session_terminated: session_terminated,
         materialization_removed: materialization_removed,
         credential_lease_released: credential_lease_released
       }}
    else
      _other -> {:error, :invalid_effect_cleanup_dto}
    end
  end

  def dump(%__MODULE__{} = value), do: Support.dump(value)

  defp optional_safe_ref(attrs, key) do
    case Support.value(attrs, key) do
      nil ->
        {:ok, nil}

      value ->
        if Support.safe_ref?(value),
          do: {:ok, value},
          else: {:error, {:invalid_cleanup_ref, key}}
    end
  end
end

defmodule AppKit.Core.EffectReceiptDTO do
  @moduledoc "Product-safe durable governed-effect receipt."

  alias AppKit.Core.{EffectCleanupDTO, GovernedEffectDTOSupport}
  alias GovernedEffectDTOSupport, as: Support

  @fields [
    :receipt_ref,
    :effect_ref,
    :status,
    :attempt_ref,
    :runtime_execution_ref,
    :external_ref,
    :result_artifact_ref,
    :cleanup
  ]
  @enforce_keys [:receipt_ref, :effect_ref, :status]
  defstruct @fields

  @type t :: %__MODULE__{}

  def new(%__MODULE__{} = value), do: value |> Map.from_struct() |> new()

  def new(attrs) do
    with {:ok, attrs} <- Support.normalize(attrs),
         true <- Support.only_keys?(attrs, @fields),
         :ok <- Support.reject_forbidden_material(attrs),
         {:ok, receipt_ref} <- Support.required_string(attrs, :receipt_ref),
         {:ok, effect_ref} <- Support.required_string(attrs, :effect_ref),
         {:ok, status} <- Support.required_string(attrs, :status),
         {:ok, cleanup} <- nested(attrs, :cleanup, EffectCleanupDTO) do
      {:ok,
       %__MODULE__{
         receipt_ref: receipt_ref,
         effect_ref: effect_ref,
         status: status,
         attempt_ref: Support.string(attrs, :attempt_ref),
         runtime_execution_ref: Support.string(attrs, :runtime_execution_ref),
         external_ref: Support.string(attrs, :external_ref),
         result_artifact_ref: Support.string(attrs, :result_artifact_ref),
         cleanup: cleanup
       }}
    else
      _other -> {:error, :invalid_effect_receipt_dto}
    end
  end

  def dump(%__MODULE__{} = value), do: Support.dump(value)

  defp nested(attrs, key, module) do
    case Support.value(attrs, key) do
      nil -> {:ok, nil}
      value -> module.new(value)
    end
  end
end

defmodule AppKit.Core.EffectAmbiguityDTO do
  @moduledoc "Reconciliation-only ambiguity state for a governed effect."

  alias AppKit.Core.GovernedEffectDTOSupport, as: Support

  @fields [
    :effect_ref,
    :state,
    :continuation_ref,
    :reconciliation_required,
    :effect_retry_allowed
  ]
  @enforce_keys [:effect_ref, :state, :reconciliation_required, :effect_retry_allowed]
  defstruct @fields

  @type t :: %__MODULE__{}

  def new(%__MODULE__{} = value), do: value |> Map.from_struct() |> new()

  def new(attrs) do
    with {:ok, attrs} <- Support.normalize(attrs),
         true <- Support.only_keys?(attrs, @fields),
         {:ok, effect_ref} <- Support.required_string(attrs, :effect_ref),
         {:ok, state} <- Support.required_string(attrs, :state),
         true <- state in ~w(dispatch_unknown outcome_unknown receipt_missing),
         true <- Support.value(attrs, :reconciliation_required) == true,
         true <- Support.value(attrs, :effect_retry_allowed) == false do
      {:ok,
       %__MODULE__{
         effect_ref: effect_ref,
         state: state,
         continuation_ref: Support.string(attrs, :continuation_ref),
         reconciliation_required: true,
         effect_retry_allowed: false
       }}
    else
      _other -> {:error, :invalid_effect_ambiguity_dto}
    end
  end

  def dump(%__MODULE__{} = value), do: Support.dump(value)
end

defmodule AppKit.Core.EffectContinuationDTO do
  @moduledoc "Product-safe durable continuation state."

  alias AppKit.Core.GovernedEffectDTOSupport, as: Support

  @fields [
    :continuation_ref,
    :status,
    :target_kind,
    :target_owner,
    :target_operation,
    :idempotency_key,
    :attempt_count
  ]
  @enforce_keys [:continuation_ref, :status, :target_kind, :target_operation, :idempotency_key]
  defstruct @fields

  @type t :: %__MODULE__{}

  def new(%__MODULE__{} = value), do: value |> Map.from_struct() |> new()

  def new(attrs) do
    with {:ok, attrs} <- Support.normalize(attrs),
         true <- Support.only_keys?(attrs, @fields),
         :ok <- Support.reject_forbidden_material(attrs),
         {:ok, continuation_ref} <- Support.required_string(attrs, :continuation_ref),
         {:ok, status} <- Support.required_string(attrs, :status),
         {:ok, target_kind} <- Support.required_string(attrs, :target_kind),
         {:ok, target_operation} <- Support.required_string(attrs, :target_operation),
         {:ok, idempotency_key} <- Support.required_string(attrs, :idempotency_key),
         attempt_count <- Support.optional_integer(attrs, :attempt_count),
         true <- attempt_count != :invalid do
      {:ok,
       %__MODULE__{
         continuation_ref: continuation_ref,
         status: status,
         target_kind: target_kind,
         target_owner: Support.string(attrs, :target_owner),
         target_operation: target_operation,
         idempotency_key: idempotency_key,
         attempt_count: attempt_count
       }}
    else
      _other -> {:error, :invalid_effect_continuation_dto}
    end
  end

  def dump(%__MODULE__{} = value), do: Support.dump(value)
end

defmodule AppKit.Core.GovernedEffectDTO do
  @moduledoc "Product-safe projection of the durable governed-effect owner state."

  alias AppKit.Core.{
    EffectAmbiguityDTO,
    EffectContinuationDTO,
    EffectReceiptDTO,
    EffectReviewDTO,
    GovernedEffectDTOSupport
  }

  alias GovernedEffectDTOSupport, as: Support

  @fields [
    :contract_version,
    :effect_ref,
    :run_ref,
    :turn_ref,
    :command_ref,
    :decision_ref,
    :grant_ref,
    :target_ref,
    :owner_execution_ref,
    :status,
    :row_version,
    :attempt_ref,
    :runtime_execution_ref,
    :external_ref,
    :result_artifact_ref,
    :review,
    :receipt,
    :ambiguity,
    :continuation
  ]
  @enforce_keys [
    :contract_version,
    :effect_ref,
    :run_ref,
    :turn_ref,
    :command_ref,
    :decision_ref,
    :grant_ref,
    :target_ref,
    :owner_execution_ref,
    :status,
    :row_version,
    :review
  ]
  defstruct @fields

  @type t :: %__MODULE__{}

  def new(%__MODULE__{} = value), do: value |> Map.from_struct() |> new()

  def new(attrs) do
    with {:ok, attrs} <- Support.normalize(attrs),
         true <- Support.only_keys?(attrs, @fields),
         :ok <- Support.reject_forbidden_material(attrs),
         true <- Support.serializable?(attrs),
         {:ok, contract_version} <- Support.required_positive_integer(attrs, :contract_version),
         {:ok, effect_ref} <- Support.required_string(attrs, :effect_ref),
         {:ok, run_ref} <- Support.required_string(attrs, :run_ref),
         {:ok, turn_ref} <- Support.required_string(attrs, :turn_ref),
         {:ok, command_ref} <- Support.required_string(attrs, :command_ref),
         {:ok, decision_ref} <- Support.required_string(attrs, :decision_ref),
         {:ok, grant_ref} <- Support.required_string(attrs, :grant_ref),
         {:ok, target_ref} <- Support.required_string(attrs, :target_ref),
         {:ok, owner_execution_ref} <- Support.required_string(attrs, :owner_execution_ref),
         {:ok, status} <- Support.required_string(attrs, :status),
         {:ok, row_version} <- Support.required_positive_integer(attrs, :row_version),
         {:ok, review} <- nested(attrs, :review, EffectReviewDTO, true),
         {:ok, receipt} <- nested(attrs, :receipt, EffectReceiptDTO),
         {:ok, ambiguity} <- nested(attrs, :ambiguity, EffectAmbiguityDTO),
         {:ok, continuation} <- nested(attrs, :continuation, EffectContinuationDTO) do
      {:ok,
       %__MODULE__{
         contract_version: contract_version,
         effect_ref: effect_ref,
         run_ref: run_ref,
         turn_ref: turn_ref,
         command_ref: command_ref,
         decision_ref: decision_ref,
         grant_ref: grant_ref,
         target_ref: target_ref,
         owner_execution_ref: owner_execution_ref,
         status: status,
         row_version: row_version,
         attempt_ref: Support.string(attrs, :attempt_ref),
         runtime_execution_ref: Support.string(attrs, :runtime_execution_ref),
         external_ref: Support.string(attrs, :external_ref),
         result_artifact_ref: Support.string(attrs, :result_artifact_ref),
         review: review,
         receipt: receipt,
         ambiguity: ambiguity,
         continuation: continuation
       }}
    else
      _other -> {:error, :invalid_governed_effect_dto}
    end
  end

  def dump(%__MODULE__{} = value), do: Support.dump(value)

  defp nested(attrs, key, module, required \\ false) do
    case Support.value(attrs, key) do
      nil when required -> {:error, {:missing_nested_dto, key}}
      nil -> {:ok, nil}
      value -> module.new(value)
    end
  end
end

defmodule AppKit.Core.EffectDispatchCommandDTO do
  @moduledoc "Optimistic dispatch command for one durable governed effect."

  alias AppKit.Core.GovernedEffectDTOSupport, as: Support

  @enforce_keys [:expected_row_version]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  def new(%__MODULE__{} = value), do: value |> Map.from_struct() |> new()

  def new(attrs) do
    with {:ok, attrs} <- Support.normalize(attrs),
         true <- Support.only_keys?(attrs, [:expected_row_version]),
         {:ok, expected_row_version} <-
           Support.required_positive_integer(attrs, :expected_row_version) do
      {:ok, %__MODULE__{expected_row_version: expected_row_version}}
    else
      _other -> {:error, :invalid_effect_dispatch_command}
    end
  end

  def dump(%__MODULE__{} = value), do: Support.dump(value)
end

defmodule AppKit.Core.EffectAcceptanceDTO do
  @moduledoc "Safe lower-acceptance identity for one governed effect attempt."

  alias AppKit.Core.GovernedEffectDTOSupport, as: Support

  @fields [:expected_row_version, :attempt_ref, :external_ref, :accepted_receipt_ref]
  @enforce_keys [:expected_row_version, :attempt_ref]
  defstruct @fields

  @type t :: %__MODULE__{}

  def new(%__MODULE__{} = value), do: value |> Map.from_struct() |> new()

  def new(attrs) do
    with {:ok, attrs} <- Support.normalize(attrs),
         true <- Support.only_keys?(attrs, @fields),
         :ok <- Support.reject_forbidden_material(attrs),
         {:ok, expected_row_version} <-
           Support.required_positive_integer(attrs, :expected_row_version),
         {:ok, attempt_ref} <- Support.required_string(attrs, :attempt_ref) do
      {:ok,
       %__MODULE__{
         expected_row_version: expected_row_version,
         attempt_ref: attempt_ref,
         external_ref: Support.string(attrs, :external_ref),
         accepted_receipt_ref: Support.string(attrs, :accepted_receipt_ref)
       }}
    else
      _other -> {:error, :invalid_effect_acceptance}
    end
  end

  def dump(%__MODULE__{} = value), do: Support.dump(value)
end

defmodule AppKit.Core.EffectReceiptCommandDTO do
  @moduledoc """
  Safe terminal or ambiguous receipt command.

  Ambiguous outcomes admit only the named owner reconciliation command; this
  DTO has no effect retry representation.
  """

  alias AppKit.Core.{EffectCleanupDTO, GovernedEffectDTOSupport}
  alias GovernedEffectDTOSupport, as: Support

  @fields [
    :expected_row_version,
    :receipt_ref,
    :receipt_state,
    :ambiguity_state,
    :result_artifact_ref,
    :artifact_refs,
    :continuation_target,
    :cleanup
  ]
  @enforce_keys [:expected_row_version, :receipt_ref, :receipt_state, :continuation_target]
  defstruct @fields

  @type t :: %__MODULE__{}

  def new(%__MODULE__{} = value), do: value |> Map.from_struct() |> new()

  def new(attrs) do
    with {:ok, attrs} <- Support.normalize(attrs),
         true <- Support.only_keys?(attrs, @fields),
         :ok <- Support.reject_forbidden_material(attrs),
         {:ok, expected_row_version} <-
           Support.required_positive_integer(attrs, :expected_row_version),
         {:ok, receipt_ref} <- Support.required_string(attrs, :receipt_ref),
         {:ok, receipt_state} <- Support.required_string(attrs, :receipt_state),
         artifact_refs when is_list(artifact_refs) <-
           Support.optional_list(attrs, :artifact_refs, []),
         target when is_map(target) <- Support.optional_map(attrs, :continuation_target),
         {:ok, cleanup} <- nested_cleanup(attrs) do
      validate(%__MODULE__{
        expected_row_version: expected_row_version,
        receipt_ref: receipt_ref,
        receipt_state: receipt_state,
        ambiguity_state: Support.string(attrs, :ambiguity_state),
        result_artifact_ref: Support.string(attrs, :result_artifact_ref),
        artifact_refs: artifact_refs,
        continuation_target: target,
        cleanup: cleanup
      })
    else
      _other -> {:error, :invalid_effect_receipt_command}
    end
  end

  def dump(%__MODULE__{} = value), do: Support.dump(value)

  defp validate(%__MODULE__{} = command) do
    ambiguity =
      command.receipt_state in ~w(ambiguous dispatch_unknown outcome_unknown receipt_missing)

    with true <-
           command.receipt_state in ~w(completed success succeeded failed failure cancelled canceled ambiguous dispatch_unknown outcome_unknown receipt_missing),
         true <- Enum.all?(command.artifact_refs || [], &Support.safe_ref?/1),
         :ok <- validate_completed(command),
         :ok <- validate_ambiguity(command, ambiguity),
         :ok <- validate_target(command.continuation_target) do
      {:ok, command}
    else
      _other -> {:error, :invalid_effect_receipt_command}
    end
  end

  defp validate_completed(%{receipt_state: state, result_artifact_ref: ref})
       when state in ~w(completed success succeeded) do
    if Support.safe_ref?(ref), do: :ok, else: {:error, :missing_result_artifact_ref}
  end

  defp validate_completed(_command), do: :ok

  defp validate_ambiguity(command, true) do
    state =
      if command.receipt_state == "ambiguous",
        do: command.ambiguity_state,
        else: command.receipt_state

    target = command.continuation_target

    if state in ~w(dispatch_unknown outcome_unknown receipt_missing) and
         target["kind"] == "owner_command" and
         target["command"] == "reconcile_effect_outcome" do
      :ok
    else
      {:error, :ambiguous_effect_requires_reconciliation_command}
    end
  end

  defp validate_ambiguity(%{ambiguity_state: nil}, false), do: :ok
  defp validate_ambiguity(_command, false), do: {:error, :unexpected_ambiguity_state}

  defp validate_target(%{"kind" => "owner_command"} = target) do
    if Enum.all?(~w(owner command idempotency_key), &Support.safe_ref?(target[&1])),
      do: :ok,
      else: {:error, :invalid_continuation_target}
  end

  defp validate_target(%{"kind" => "workflow_signal"} = target) do
    if Enum.all?(~w(workflow_id signal idempotency_key), &Support.safe_ref?(target[&1])),
      do: :ok,
      else: {:error, :invalid_continuation_target}
  end

  defp validate_target(_target), do: {:error, :invalid_continuation_target}

  defp nested_cleanup(attrs) do
    case Support.value(attrs, :cleanup) do
      nil -> {:ok, nil}
      value -> EffectCleanupDTO.new(value)
    end
  end
end
