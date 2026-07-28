defmodule AppKit.Bridges.MezzanineBridge.EffectAdapter do
  @moduledoc false

  @behaviour AppKit.EffectSurface

  alias AppKit.Bridges.MezzanineBridge.{Errors, Services}

  alias AppKit.Core.{
    EffectAcceptanceDTO,
    EffectAmbiguityDTO,
    EffectCleanupDTO,
    EffectContinuationDTO,
    EffectDispatchCommandDTO,
    EffectReceiptCommandDTO,
    EffectReceiptDTO,
    EffectReviewDTO,
    GovernedEffectDTO,
    GovernedEffectProposalDTO,
    RequestContext
  }

  @impl true
  def propose_effect(
        %RequestContext{} = context,
        %GovernedEffectProposalDTO{} = proposal,
        opts
      )
      when is_list(opts) do
    with {:ok, command} <- open_command(context, proposal),
         {:ok, result} <- Services.governed_effect(opts).open(command),
         {:ok, dto} <- dto_from_result(result, opts) do
      {:ok, dto}
    else
      {:error, reason} -> Errors.normalize(reason)
    end
  end

  @impl true
  def begin_dispatch(
        %RequestContext{} = context,
        owner_execution_ref,
        %EffectDispatchCommandDTO{} = command,
        opts
      )
      when is_binary(owner_execution_ref) and is_list(opts) do
    attrs =
      command
      |> EffectDispatchCommandDTO.dump()
      |> command_context(context)

    call_and_map(
      Services.governed_effect(opts),
      :begin_dispatch,
      [owner_execution_ref, attrs],
      opts
    )
  end

  @impl true
  def record_accepted(
        %RequestContext{} = context,
        owner_execution_ref,
        %EffectAcceptanceDTO{} = acceptance,
        opts
      )
      when is_binary(owner_execution_ref) and is_list(opts) do
    attrs =
      %{
        expected_row_version: acceptance.expected_row_version,
        submission_ref:
          compact(%{
            "attempt_ref" => acceptance.attempt_ref,
            "external_ref" => acceptance.external_ref
          }),
        lower_receipt:
          compact(%{
            "accepted_receipt_ref" => acceptance.accepted_receipt_ref
          })
      }
      |> command_context(context)

    call_and_map(
      Services.governed_effect(opts),
      :record_accepted,
      [owner_execution_ref, attrs],
      opts
    )
  end

  @impl true
  def record_receipt(
        %RequestContext{} = context,
        owner_execution_ref,
        %EffectReceiptCommandDTO{} = receipt,
        opts
      )
      when is_binary(owner_execution_ref) and is_list(opts) do
    attrs =
      receipt
      |> receipt_command()
      |> command_context(context)

    call_and_map(
      Services.governed_effect(opts),
      :record_receipt,
      [owner_execution_ref, attrs],
      opts
    )
  end

  @impl true
  def get_effect(%RequestContext{}, owner_execution_ref, opts)
      when is_binary(owner_execution_ref) and is_list(opts) do
    case Services.effect_readback(opts).get_effect(owner_execution_ref, opts) do
      {:ok, result} -> dto_from_result(result, opts)
      {:error, reason} -> Errors.normalize(reason)
    end
  end

  @impl true
  def get_effect_by_idempotency(%RequestContext{} = context, idempotency_key, opts)
      when is_binary(idempotency_key) and is_list(opts) do
    with {:ok, installation_id} <- installation_id(context),
         {:ok, result} <-
           Services.effect_readback(opts).get_effect_by_idempotency(
             installation_id,
             idempotency_key,
             opts
           ),
         {:ok, dto} <- dto_from_result(result, opts) do
      {:ok, dto}
    else
      {:error, reason} -> Errors.normalize(reason)
    end
  end

  defp call_and_map(service, function, args, opts) do
    case apply(service, function, args) do
      {:ok, result} -> dto_from_result(result, opts)
      {:error, reason} -> Errors.normalize(reason)
    end
  end

  defp open_command(context, proposal) do
    with {:ok, installation_id} <- installation_id(context),
         {:ok, idempotency_key} <- idempotency_key(context) do
      attrs = GovernedEffectProposalDTO.dump(proposal)

      {:ok,
       %{
         tenant_id: context.tenant_ref.id,
         installation_id: installation_id,
         subject_id: proposal.subject_id,
         run_id: proposal.run_id,
         review_unit_id: proposal.review_unit_id,
         effect_ref: proposal.effect_ref,
         run_ref: proposal.run_ref,
         turn_ref: proposal.turn_ref,
         command_ref: proposal.command_ref,
         decision_ref: proposal.decision_ref,
         grant_ref: proposal.grant_ref,
         review_ref: proposal.review_ref,
         idempotency_key: idempotency_key,
         target_ref: proposal.target_ref,
         trace_id: context.trace_id,
         causation_id: causation_id(context),
         attempt_ref: proposal.attempt_ref,
         pinned_tool_manifest: attrs["pinned_tool_manifest"],
         reviewed_operation: attrs["reviewed_operation"],
         actor_ref: actor_ref(context),
         compiled_pack_revision: context.installation_ref.compiled_pack_revision || 1
       }}
    end
  end

  defp receipt_command(receipt) do
    %{
      expected_row_version: receipt.expected_row_version,
      receipt_ref: receipt.receipt_ref,
      receipt_state: receipt.receipt_state,
      ambiguity_state: receipt.ambiguity_state,
      result_artifact_ref: receipt.result_artifact_ref,
      artifact_refs: receipt.artifact_refs || [],
      continuation_target: receipt.continuation_target,
      lower_receipt: cleanup_receipt(receipt.cleanup)
    }
    |> compact()
  end

  defp cleanup_receipt(nil), do: %{}

  defp cleanup_receipt(%EffectCleanupDTO{} = cleanup),
    do: %{"cleanup" => EffectCleanupDTO.dump(cleanup)}

  defp command_context(attrs, context) do
    Map.merge(attrs, %{
      trace_id: context.trace_id,
      causation_id: causation_id(context),
      actor_ref: actor_ref(context)
    })
  end

  defp dto_from_result(result, opts) when is_map(result) do
    record = value(result, :effect_record)
    execution = value(result, :execution)
    continuation = value(result, :continuation)
    dispatch_envelope = value(execution, :dispatch_envelope)

    with true <- is_map(record) and is_map(execution) and is_map(dispatch_envelope),
         {:ok, review} <- review_dto(record, execution, opts),
         {:ok, receipt} <- receipt_dto(record, execution),
         {:ok, continuation} <- continuation_dto(continuation, execution, opts),
         {:ok, ambiguity} <- ambiguity_dto(record, continuation) do
      GovernedEffectDTO.new(%{
        contract_version: value(record, :contract_version),
        effect_ref: value(record, :effect_ref),
        run_ref: value(record, :run_ref),
        turn_ref: value(record, :turn_ref),
        command_ref: value(record, :command_ref),
        decision_ref: value(record, :decision_ref),
        grant_ref: value(record, :grant_ref),
        target_ref: value(record, :target_ref),
        owner_execution_ref: "effect-execution://#{value(execution, :id)}",
        status: value(record, :status),
        row_version: value(record, :row_version),
        attempt_ref: value(record, :attempt_ref),
        runtime_execution_ref: value(record, :execution_ref),
        external_ref: value(record, :external_ref),
        result_artifact_ref: value(record, :result_artifact_ref),
        pinned_tool_manifest: value(dispatch_envelope, :pinned_tool_manifest),
        reviewed_operation: value(dispatch_envelope, :reviewed_operation),
        review: review,
        receipt: receipt,
        ambiguity: ambiguity,
        continuation: continuation
      })
    else
      false -> {:error, :invalid_effect_owner_projection}
      {:error, _reason} = error -> error
    end
  end

  defp dto_from_result(_result, _opts), do: {:error, :invalid_effect_owner_projection}

  defp review_dto(record, execution, opts) do
    tenant_id = value(execution, :tenant_id)
    review_unit_id = execution |> value(:intent_snapshot) |> value(:review_unit_id)

    with {:ok, projection} <-
           Services.review_query(opts).get_effect_review(tenant_id, review_unit_id) do
      EffectReviewDTO.new(%{
        review_ref: value(record, :review_ref),
        review_unit_id: review_unit_id,
        status: value(projection, :status),
        row_version: value(projection, :row_version),
        accepted_actor_ref: value(projection, :accepted_actor_ref)
      })
    end
  end

  defp receipt_dto(record, execution) do
    case value(record, :receipt_ref) do
      nil ->
        {:ok, nil}

      receipt_ref ->
        EffectReceiptDTO.new(%{
          receipt_ref: receipt_ref,
          effect_ref: value(record, :effect_ref),
          status: value(record, :status),
          attempt_ref: value(record, :attempt_ref),
          runtime_execution_ref: value(record, :execution_ref),
          external_ref: value(record, :external_ref),
          result_artifact_ref: value(record, :result_artifact_ref),
          cleanup: execution |> value(:lower_receipt) |> value(:cleanup)
        })
    end
  end

  defp continuation_dto(nil, execution, opts) do
    continuation_ref =
      execution
      |> value(:lower_receipt)
      |> value(:continuation_ref)

    case continuation_ref do
      nil -> {:ok, nil}
      ref -> continuation_from_readback(ref, opts)
    end
  end

  defp continuation_dto(continuation, _execution, opts),
    do: continuation_from_readback(continuation, opts)

  defp continuation_from_readback(continuation_or_ref, opts) do
    with {:ok, projection} <-
           Services.effect_readback(opts).get_continuation(continuation_or_ref, opts) do
      EffectContinuationDTO.new(projection)
    end
  end

  defp ambiguity_dto(record, continuation) do
    case value(record, :ambiguity_state) do
      nil ->
        {:ok, nil}

      state ->
        EffectAmbiguityDTO.new(%{
          effect_ref: value(record, :effect_ref),
          state: state,
          continuation_ref: continuation && continuation.continuation_ref,
          reconciliation_required: true,
          effect_retry_allowed: false
        })
    end
  end

  defp installation_id(%RequestContext{installation_ref: %{id: id}})
       when is_binary(id) and id != "",
       do: {:ok, id}

  defp installation_id(_context), do: {:error, :missing_effect_installation_ref}

  defp idempotency_key(%RequestContext{idempotency_key: key})
       when is_binary(key) and key != "",
       do: {:ok, key}

  defp idempotency_key(_context), do: {:error, :missing_effect_idempotency_key}

  defp causation_id(context),
    do: context.causation_id || context.request_id || context.idempotency_key || context.trace_id

  defp actor_ref(context) do
    %{
      "kind" => to_string(context.actor_ref.kind),
      "ref" => context.actor_ref.id,
      "tenant_id" => context.tenant_ref.id
    }
  end

  defp compact(map), do: Map.reject(map, fn {_key, nested} -> is_nil(nested) end)

  defp value(nil, _key), do: nil

  defp value(map_or_struct, key) when is_map(map_or_struct) do
    map = if is_struct(map_or_struct), do: Map.from_struct(map_or_struct), else: map_or_struct
    Map.get(map, key, Map.get(map, to_string(key)))
  end
end
