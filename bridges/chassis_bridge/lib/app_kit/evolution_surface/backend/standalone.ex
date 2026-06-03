defmodule AppKit.EvolutionSurface.Backend.Standalone do
  @moduledoc "Standalone product-safe Chassis Evolution surface fallback."

  @behaviour AppKit.EvolutionSurface.Backend

  alias AppKit.Core.Evolution.DTO.{
    CandidateSummary,
    EvolutionBatchPage,
    EvolutionBatchSummary,
    EvolutionStatus,
    OperatorConsentResult,
    PromotionRequestResult,
    RedactedDiffRef,
    SwapStatus,
    TrialSummary
  }

  alias AppKit.Core.Evolution.SurfaceError
  alias AppKit.Core.RequestContext

  @consent_signal "mezzanine.signal.chassis.evolution.consent.v1"
  @allowed_decisions [:approved, :rejected, :stopped]

  @impl true
  def list_evolution_batches(%RequestContext{} = context, request, opts) do
    limit = bounded_limit(request)

    batches =
      opts
      |> Keyword.get(:batch_store, default_batch_store(context))
      |> map_values()
      |> Enum.take(limit)

    EvolutionBatchPage.new(%{batches: batches, limit: limit, next_cursor: nil})
  end

  @impl true
  def get_evolution_batch(%RequestContext{} = context, batch_ref, opts)
      when is_binary(batch_ref) do
    store = Keyword.get(opts, :batch_store, default_batch_store(context))

    case fetch_record(store, batch_ref) do
      {:ok, record} -> EvolutionBatchSummary.new(record)
      :error -> not_found(:batch_not_found, "Evolution batch not found", %{batch_ref: batch_ref})
    end
  end

  @impl true
  def get_evolution_status(%RequestContext{} = context, evolution_ref, opts)
      when is_binary(evolution_ref) do
    store = Keyword.get(opts, :evolution_store, default_evolution_store(context))

    case fetch_record(store, evolution_ref) do
      {:ok, record} ->
        EvolutionStatus.new(record)

      :error ->
        not_found(:evolution_not_found, "Evolution status not found", %{
          evolution_ref: evolution_ref
        })
    end
  end

  @impl true
  def get_candidate_summary(%RequestContext{} = context, candidate_ref, opts)
      when is_binary(candidate_ref) do
    with :ok <- authorize_lower_read(context, candidate_ref, opts),
         {:ok, record} <- candidate_record(context, candidate_ref, opts),
         {:ok, record} <- redacted_candidate_record(record, opts) do
      CandidateSummary.new(record)
    end
  end

  @impl true
  def get_trial_summary(%RequestContext{} = context, trial_ref, opts) when is_binary(trial_ref) do
    store = Keyword.get(opts, :trial_store, default_trial_store(context))

    case fetch_record(store, trial_ref) do
      {:ok, record} -> TrialSummary.new(record)
      :error -> not_found(:trial_not_found, "Trial summary not found", %{trial_ref: trial_ref})
    end
  end

  @impl true
  def request_candidate_promotion(%RequestContext{} = context, candidate_ref, request, opts)
      when is_binary(candidate_ref) and is_map(request) do
    with {:ok, _record} <- candidate_record(context, candidate_ref, opts) do
      PromotionRequestResult.new(%{
        candidate_ref: candidate_ref,
        status: :accepted,
        workflow_ref:
          Map.get(request, :workflow_ref) || Map.get(request, "workflow_ref") ||
            "workflow:evolution:promotion:#{short_digest("#{context.trace_id}:#{candidate_ref}")}",
        receipt_refs: [
          "receipt:evolution:promotion:#{short_digest("#{context.trace_id}:#{candidate_ref}")}"
        ]
      })
    end
  end

  @impl true
  def record_operator_consent(%RequestContext{} = context, candidate_ref, decision, opts)
      when is_binary(candidate_ref) and is_map(decision) do
    with :ok <- require_human_operator(context, candidate_ref),
         {:ok, normalized_decision} <- normalize_decision(decision),
         {:ok, signal_ref} <-
           emit_consent_signal(context, candidate_ref, normalized_decision, opts) do
      OperatorConsentResult.new(%{
        candidate_ref: candidate_ref,
        decision: normalized_decision.decision,
        consent_ref: consent_ref(context, candidate_ref, normalized_decision),
        signal_ref: signal_ref,
        recorded_at: normalized_decision.recorded_at,
        receipt_refs: ["receipt:evolution:consent:#{short_digest(signal_ref)}"]
      })
    end
  end

  @impl true
  def get_swap_status(%RequestContext{} = context, swap_ref, opts) when is_binary(swap_ref) do
    store = Keyword.get(opts, :swap_store, default_swap_store(context))

    case fetch_record(store, swap_ref) do
      {:ok, record} -> SwapStatus.new(record)
      :error -> not_found(:swap_not_found, "Swap status not found", %{swap_ref: swap_ref})
    end
  end

  defp bounded_limit(request) do
    request
    |> value(:limit, 10)
    |> case do
      limit when is_integer(limit) and limit > 0 -> min(limit, 100)
      _ -> 10
    end
  end

  defp candidate_record(context, candidate_ref, opts) do
    store = Keyword.get(opts, :candidate_store, default_candidate_store(context))

    case fetch_record(store, candidate_ref) do
      {:ok, record} ->
        {:ok, record}

      :error ->
        not_found(:candidate_not_found, "Candidate summary not found", %{
          candidate_ref: candidate_ref
        })
    end
  end

  defp authorize_lower_read(%RequestContext{} = context, candidate_ref, opts) do
    lease_ref = Keyword.get(opts, :lower_read_lease_ref)

    if actor_kind(context) in [:agent, "agent"] and is_binary(lease_ref) do
      {:error,
       SurfaceError.new!(%{
         code: :requires_human_operator,
         message: "Raw diff lower-read leases require a human operator context",
         detail: %{candidate_ref: candidate_ref, lower_read_lease_ref: lease_ref}
       })}
    else
      :ok
    end
  end

  defp require_human_operator(%RequestContext{} = context, candidate_ref) do
    if actor_kind(context) in [:agent, "agent"] do
      {:error,
       SurfaceError.new!(%{
         code: :requires_human_operator,
         message: "Operator consent requires a human operator context",
         detail: %{candidate_ref: candidate_ref}
       })}
    else
      :ok
    end
  end

  defp redacted_candidate_record(record, opts) do
    record = normalize_record(record)
    diff_ref = Map.get(record, :diff_ref_redacted) || Map.get(record, :diff_ref)

    with {:ok, redacted_ref} <- redacted_diff_ref(diff_ref, opts) do
      {:ok,
       record
       |> Map.drop([:raw_diff, :private_prompt, :private_transcript, :provider_payload])
       |> Map.put(:diff_ref_redacted, redacted_ref)}
    end
  end

  defp redacted_diff_ref(nil, _opts) do
    {:error,
     SurfaceError.new!(%{
       code: :invalid_dto,
       message: "diff_ref_redacted is required",
       detail: %{field: :diff_ref_redacted}
     })}
  end

  defp redacted_diff_ref(%RedactedDiffRef{} = ref, opts) do
    {:ok, %{ref | lower_read_lease_ref: Keyword.get(opts, :lower_read_lease_ref)}}
  end

  defp redacted_diff_ref(diff_ref, opts)
       when is_binary(diff_ref) or is_map(diff_ref) or is_list(diff_ref) do
    attrs =
      case diff_ref do
        value when is_binary(value) -> %{diff_ref: value}
        value -> Map.new(value)
      end

    attrs
    |> Map.put(:lower_read_lease_ref, Keyword.get(opts, :lower_read_lease_ref))
    |> Map.put(:lease_required?, is_nil(Keyword.get(opts, :lower_read_lease_ref)))
    |> RedactedDiffRef.new()
  end

  defp normalize_decision(decision) do
    decision = normalize_record(decision)
    value = Map.get(decision, :decision)

    with true <- value in @allowed_decisions,
         reason <- Map.get(decision, :reason),
         true <- is_nil(reason) or is_binary(reason) do
      {:ok,
       %{
         decision: value,
         reason: reason,
         recorded_at: Map.get(decision, :recorded_at) || DateTime.to_iso8601(DateTime.utc_now())
       }}
    else
      _ ->
        {:error,
         SurfaceError.new!(%{
           code: :invalid_consent_decision,
           message: "Consent decision must be approved, rejected, or stopped",
           detail: %{allowed_decisions: @allowed_decisions}
         })}
    end
  end

  defp emit_consent_signal(context, candidate_ref, decision, opts) do
    signal = consent_signal(context, candidate_ref, decision, opts)

    case Keyword.get(opts, :signal_fun) do
      fun when is_function(fun, 1) ->
        case fun.(signal) do
          {:ok, %{signal_ref: signal_ref}} when is_binary(signal_ref) ->
            {:ok, signal_ref}

          {:ok, signal_ref} when is_binary(signal_ref) ->
            {:ok, signal_ref}

          {:ok, _other} ->
            {:ok, signal.signal_ref}

          {:error, %SurfaceError{} = error} ->
            {:error, error}

          {:error, reason} ->
            boundary_error(:signal_dispatch_failed, "Consent signal dispatch failed", %{
              reason: reason
            })

          other ->
            boundary_error(
              :signal_dispatch_failed,
              "Consent signal dispatch returned an invalid result",
              %{result: other}
            )
        end

      _missing ->
        {:ok, signal.signal_ref}
    end
  end

  defp consent_signal(context, candidate_ref, decision, opts) do
    signal_ref =
      Keyword.get(opts, :signal_ref) ||
        "signal:evolution:consent:#{short_digest("#{context.trace_id}:#{candidate_ref}:#{decision.decision}")}"

    %{
      signal_name: @consent_signal,
      signal_ref: signal_ref,
      trace_id: context.trace_id,
      tenant_ref: context.tenant_ref.id,
      installation_ref: installation_id(context),
      actor_ref: context.actor_ref.id,
      candidate_ref: candidate_ref,
      decision: decision.decision,
      reason: decision.reason,
      recorded_at: Keyword.get(opts, :now, decision.recorded_at),
      idempotency_key:
        Keyword.get(opts, :idempotency_key) ||
          "idem:evolution:consent:#{short_digest("#{context.trace_id}:#{candidate_ref}:#{decision.decision}")}"
    }
  end

  defp consent_ref(context, candidate_ref, decision) do
    "consent:evolution:#{short_digest("#{context.trace_id}:#{candidate_ref}:#{decision.decision}")}"
  end

  defp default_batch_store(%RequestContext{} = context) do
    %{
      "failure-batch:smoke" => %{
        batch_ref: "failure-batch:smoke",
        tenant_ref: context.tenant_ref.id,
        summary: "No unsafe lower-plane material exposed",
        candidate_count: 1,
        receipt_refs: ["receipt:evolution:batch:smoke"],
        redaction_posture: :redacted
      }
    }
  end

  defp default_evolution_store(%RequestContext{} = context) do
    %{
      "evolution:smoke" => %{
        evolution_ref: "evolution:smoke",
        state: :candidate_scored,
        candidate_refs: ["candidate:smoke"],
        receipt_refs: ["receipt:evolution:status:smoke"],
        trace_refs: [context.trace_id]
      }
    }
  end

  defp default_candidate_store(%RequestContext{} = context) do
    %{
      "candidate:smoke" => %{
        candidate_ref: "candidate:smoke",
        evolution_ref: "evolution:smoke",
        state: :scored,
        diff_ref: "diff:candidate:smoke",
        score_summary: %{overall_score: 0.8, dimensions: %{smoke: 1.0}},
        receipt_refs: ["receipt:evolution:candidate:smoke"],
        trace_refs: [context.trace_id],
        operator_action_hints: [:request_promotion]
      }
    }
  end

  defp default_trial_store(%RequestContext{} = context) do
    %{
      "trial:smoke" => %{
        trial_ref: "trial:smoke",
        candidate_ref: "candidate:smoke",
        state: :passed,
        score_summary: %{overall_score: 0.8},
        receipt_refs: ["receipt:evolution:trial:smoke"],
        trace_refs: [context.trace_id]
      }
    }
  end

  defp default_swap_store(_context) do
    %{
      "swap:smoke" => %{
        swap_ref: "swap:smoke",
        state: :committed,
        health_status: :healthy,
        receipt_refs: ["receipt:evolution:swap:smoke"]
      }
    }
  end

  defp fetch_record(%{} = store, ref),
    do: if(Map.has_key?(store, ref), do: {:ok, Map.fetch!(store, ref)}, else: :error)

  defp fetch_record(fun, ref) when is_function(fun, 1) do
    case fun.(ref) do
      {:ok, record} -> {:ok, record}
      nil -> :error
      :error -> :error
      record when is_map(record) -> {:ok, record}
    end
  end

  defp fetch_record(_store, _ref), do: :error

  defp map_values(%{} = store), do: Map.values(store)
  defp map_values(values) when is_list(values), do: values
  defp map_values(_values), do: []

  defp normalize_record(record) when is_map(record) do
    Map.new(record, fn {key, value} -> {normalize_key(key), value} end)
  end

  defp normalize_key(key) when is_atom(key), do: key

  defp normalize_key(key) when is_binary(key) do
    String.to_existing_atom(key)
  rescue
    ArgumentError -> key
  end

  defp value(map, key, default) when is_map(map),
    do: Map.get(map, key) || Map.get(map, Atom.to_string(key), default)

  defp value(_map, _key, default), do: default

  defp actor_kind(%RequestContext{actor_ref: actor_ref}), do: actor_ref.kind

  defp installation_id(%RequestContext{installation_ref: nil}), do: nil

  defp installation_id(%RequestContext{installation_ref: installation_ref}),
    do: installation_ref.id

  defp not_found(code, message, detail),
    do: {:error, SurfaceError.new!(%{code: code, message: message, detail: detail})}

  defp boundary_error(code, message, detail),
    do: {:error, SurfaceError.new!(%{code: code, message: message, detail: detail})}

  defp short_digest(value) do
    :crypto.hash(:sha256, value)
    |> Base.encode16(case: :lower)
    |> binary_part(0, 16)
  end
end
