defmodule AppKit.EvolutionSurfaceTest do
  use ExUnit.Case, async: false

  alias AppKit.Core.Evolution.DTO.{
    CandidateSummary,
    EvolutionBatchPage,
    OperatorConsentResult,
    RedactedDiffRef
  }

  alias AppKit.Core.Evolution.SurfaceError
  alias AppKit.Core.RequestContext
  alias AppKit.EvolutionSurface

  defmodule InjectedEvolutionBackend do
    @behaviour AppKit.EvolutionSurface.Backend

    alias AppKit.Core.Evolution.DTO.EvolutionBatchPage

    @impl true
    def list_evolution_batches(context, request, opts) do
      send(
        Keyword.fetch!(opts, :test_pid),
        {:injected_evolution_backend, context.trace_id, request}
      )

      EvolutionBatchPage.new(%{
        batches: [
          %{
            batch_ref: "failure-batch:injected",
            tenant_ref: context.tenant_ref.id,
            summary: "injected backend page",
            redaction_posture: :redacted
          }
        ],
        next_cursor: nil,
        limit: Map.fetch!(request, :limit)
      })
    end

    @impl true
    def get_evolution_batch(_context, _batch_ref, _opts), do: {:error, :unexpected_call}

    @impl true
    def get_evolution_status(_context, _evolution_ref, _opts), do: {:error, :unexpected_call}

    @impl true
    def get_candidate_summary(_context, _candidate_ref, _opts), do: {:error, :unexpected_call}

    @impl true
    def get_trial_summary(_context, _trial_ref, _opts), do: {:error, :unexpected_call}

    @impl true
    def request_candidate_promotion(_context, _candidate_ref, _request, _opts),
      do: {:error, :unexpected_call}

    @impl true
    def record_operator_consent(_context, _candidate_ref, _decision, _opts),
      do: {:error, :unexpected_call}

    @impl true
    def get_swap_status(_context, _swap_ref, _opts), do: {:error, :unexpected_call}
  end

  test "explicit backend option is resolved through AppKit.BackendConfig.resolve/4" do
    assert {:ok, %EvolutionBatchPage{limit: 2, batches: [batch]}} =
             EvolutionSurface.list_evolution_batches(ctx(:operator), %{limit: 2},
               evolution_surface_backend: InjectedEvolutionBackend,
               test_pid: self()
             )

    assert batch.batch_ref == "failure-batch:injected"
    assert_receive {:injected_evolution_backend, "11111111111111111111111111111111", %{limit: 2}}
  end

  test "candidate summaries expose only a redacted diff ref when no lower-read lease is present" do
    assert {:ok, %CandidateSummary{} = summary} =
             EvolutionSurface.get_candidate_summary(ctx(:operator), "candidate:repair:1",
               evolution_surface_backend: EvolutionSurface.Backend.Standalone,
               candidate_store: candidate_store()
             )

    assert %RedactedDiffRef{diff_ref: "diff:candidate:repair:1", lease_required?: true} =
             summary.diff_ref_redacted

    refute Map.has_key?(Map.from_struct(summary), :raw_diff)
    refute inspect(summary) =~ "raw private patch"
    refute inspect(summary) =~ "secret transcript"
  end

  test "agent contexts receive no raw diffs even when a lower-read lease is supplied" do
    assert {:error,
            %SurfaceError{
              code: :requires_human_operator,
              detail: %{candidate_ref: "candidate:repair:1", lower_read_lease_ref: "lease:diff:1"}
            }} =
             EvolutionSurface.get_candidate_summary(ctx(:agent), "candidate:repair:1",
               evolution_surface_backend: EvolutionSurface.Backend.Standalone,
               candidate_store: candidate_store(),
               lower_read_lease_ref: "lease:diff:1"
             )

    refute_receive {:raw_diff, _}
  end

  test "recording operator consent emits the Mezzanine consent signal" do
    signal_fun = fn signal ->
      send(self(), {:mezzanine_signal, signal})
      {:ok, %{signal_ref: "signal:consent:1"}}
    end

    assert {:ok, %OperatorConsentResult{} = result} =
             EvolutionSurface.record_operator_consent(
               ctx(:operator),
               "candidate:repair:1",
               %{decision: :approved, reason: "trial receipts accepted"},
               evolution_surface_backend: EvolutionSurface.Backend.Standalone,
               signal_fun: signal_fun,
               now: ~U[2026-06-03 12:00:00Z]
             )

    assert result.signal_ref == "signal:consent:1"
    assert result.consent_ref =~ "consent:"

    assert_receive {:mezzanine_signal,
                    %{
                      signal_name: "mezzanine.signal.chassis.evolution.consent.v1",
                      candidate_ref: "candidate:repair:1",
                      decision: :approved,
                      idempotency_key: idempotency_key,
                      trace_id: "11111111111111111111111111111111"
                    }}

    assert idempotency_key =~ "idem:evolution:consent:"
  end

  defp ctx(kind) do
    {:ok, context} =
      RequestContext.new(%{
        trace_id: trace_id(kind),
        actor_ref: %{id: "actor:#{kind}:1", kind: kind, roles: ["operator"]},
        tenant_ref: %{id: "tenant:dev", slug: "dev"},
        installation_ref: %{id: "installation:dev", pack_slug: "extravaganza", status: :active}
      })

    context
  end

  defp candidate_store do
    %{
      "candidate:repair:1" => %{
        candidate_ref: "candidate:repair:1",
        state: :scored,
        diff_ref: "diff:candidate:repair:1",
        score_summary: %{overall_score: 0.88, dimensions: %{tests: 1.0, risk: 0.76}},
        receipt_refs: ["receipt:candidate:1", "receipt:trial:1"],
        trace_refs: ["trace:evolution:repair:1"],
        raw_diff: "raw private patch",
        private_transcript: "secret transcript"
      }
    }
  end

  defp trace_id(:operator), do: "11111111111111111111111111111111"
  defp trace_id(:agent), do: "22222222222222222222222222222222"
end
