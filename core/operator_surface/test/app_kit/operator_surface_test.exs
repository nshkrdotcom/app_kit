defmodule AppKit.OperatorSurfaceTest do
  use ExUnit.Case, async: true

  defmodule FakeOperatorBackend do
    @behaviour AppKit.Core.Backends.OperatorBackend

    alias AppKit.Core.{
      ActionResult,
      MemoryFragmentListRequest,
      MemoryFragmentProjection,
      MemoryFragmentProvenance,
      MemoryInvalidationRequest,
      MemoryPromotionRequest,
      MemoryProofTokenLookup,
      MemoryShareUpRequest,
      OperatorAction,
      OperatorProjection,
      ReadLease,
      RequestContext,
      RunRef,
      StreamAttachLease,
      SubjectRef,
      TimelineEvent,
      UnifiedTrace
    }

    @impl true
    def run_status(%RunRef{} = run_ref, attrs, _opts) do
      {:ok, %{run_id: run_ref.run_id, backend: :fake, attrs: attrs}}
    end

    @impl true
    def review_run(%RunRef{} = run_ref, evidence_attrs, opts) do
      {:ok,
       %{
         backend: :fake,
         run_id: run_ref.run_id,
         evidence_attrs: evidence_attrs,
         reason: Keyword.get(opts, :reason)
       }}
    end

    @impl true
    def subject_status(%RequestContext{} = context, %SubjectRef{} = subject_ref, _opts) do
      OperatorProjection.new(%{
        subject_ref: subject_ref,
        lifecycle_state: "processing",
        current_execution_ref: %{id: "exec-1", dispatch_state: :accepted},
        available_actions: [
          %{
            action_ref: %{
              id: "#{subject_ref.id}:pause",
              action_kind: "pause",
              subject_ref: subject_ref
            },
            label: "Pause"
          }
        ],
        payload: %{trace_id: context.trace_id}
      })
    end

    @impl true
    def timeline(%RequestContext{} = _context, %SubjectRef{} = _subject_ref, _opts) do
      {:ok,
       [
         TimelineEvent.new!(%{
           ref: "evt-1",
           event_kind: "run_scheduled",
           occurred_at: ~U[2026-04-18 12:00:00Z],
           summary: "Run scheduled"
         })
       ]}
    end

    @impl true
    def get_unified_trace(%RequestContext{} = context, execution_ref, _opts) do
      UnifiedTrace.new(%{
        trace_id: context.trace_id,
        join_keys: %{"execution_id" => execution_ref.id},
        steps: [
          %{
            ref: "step-1",
            source: "execution_record",
            occurred_at: ~U[2026-04-18 12:05:00Z],
            trace_id: context.trace_id,
            staleness_class: "lower_fresh",
            operator_actionable?: false,
            diagnostic?: false,
            payload: %{"dispatch_state" => "dispatching"}
          }
        ]
      })
    end

    @impl true
    def issue_read_lease(%RequestContext{} = context, execution_ref, _opts) do
      ReadLease.new(%{
        lease_ref: %{
          id: "lease-read-1",
          allowed_family: "unified_trace",
          execution_ref: execution_ref
        },
        trace_id: context.trace_id,
        expires_at: ~U[2026-04-18 12:10:00Z],
        lease_token: "read-token-1",
        allowed_operations: ["fetch_run", "events"],
        scope: %{"include_lower" => true},
        lineage_anchor: %{"submission_ref" => "sub-1"},
        invalidation_cursor: 7,
        invalidation_channel: "read:unified_trace"
      })
    end

    @impl true
    def issue_stream_attach_lease(%RequestContext{} = context, execution_ref, _opts) do
      StreamAttachLease.new(%{
        lease_ref: %{
          id: "lease-stream-1",
          allowed_family: "runtime_stream",
          execution_ref: execution_ref
        },
        trace_id: context.trace_id,
        expires_at: ~U[2026-04-18 12:10:00Z],
        attach_token: "stream-token-1",
        scope: %{"transport" => "sse"},
        lineage_anchor: %{"submission_ref" => "sub-1"},
        reconnect_cursor: 7,
        invalidation_channel: "stream:runtime_stream",
        poll_interval_ms: 2_000
      })
    end

    @impl true
    def available_actions(%RequestContext{} = _context, %SubjectRef{} = subject_ref, _opts) do
      {:ok,
       [
         OperatorAction.new!(%{
           action_ref: %{
             id: "#{subject_ref.id}:cancel",
             action_kind: "cancel",
             subject_ref: subject_ref
           },
           label: "Cancel",
           dangerous?: true,
           requires_confirmation?: true
         })
       ]}
    end

    @impl true
    def apply_action(
          %RequestContext{} = _context,
          %SubjectRef{} = _subject_ref,
          action_request,
          _opts
        ) do
      ActionResult.new(%{
        status: :completed,
        action_ref: action_request.action_ref,
        message: "action applied"
      })
    end

    @impl true
    def list_memory_fragments(
          %RequestContext{} = _context,
          %MemoryFragmentListRequest{} = _request,
          _opts
        ) do
      {:ok, [memory_fragment_projection()]}
    end

    @impl true
    def memory_fragment_by_proof_token(
          %RequestContext{} = _context,
          %MemoryProofTokenLookup{} = _lookup,
          _opts
        ) do
      {:ok, memory_fragment_projection()}
    end

    @impl true
    def memory_fragment_provenance(
          %RequestContext{} = _context,
          "memory-private://alpha/private-1",
          _opts
        ) do
      MemoryFragmentProvenance.new(%{
        fragment_ref: "memory-private://alpha/private-1",
        proof_token_ref: "proof://recall/1",
        proof_hash: valid_hash("proof"),
        source_contract_name: "OuterBrain.MemoryContextProvenance.v2",
        snapshot_epoch: 42,
        source_node_ref: "node://memory-reader@host/reader-1",
        commit_lsn: "16/B374D848",
        commit_hlc: %{wall_ns: 1_800_000_000_000_000_000, logical: 1, node: "reader-1"},
        provenance_refs: ["provenance://outer-brain/context/1"],
        evidence_refs: [%{ref: "evidence://recall/1", kind: "proof"}],
        governance_refs: [%{ref: "governance://memory/read", kind: "read"}]
      })
    end

    @impl true
    def request_memory_share_up(
          %RequestContext{} = _context,
          %MemoryShareUpRequest{} = request,
          _opts
        ) do
      memory_action_result(request.fragment_ref, "share_up", "Share-up requested")
    end

    @impl true
    def request_memory_promotion(
          %RequestContext{} = _context,
          %MemoryPromotionRequest{} = request,
          _opts
        ) do
      memory_action_result(request.shared_fragment_ref, "promote", "Promotion requested")
    end

    @impl true
    def request_memory_invalidation(
          %RequestContext{} = _context,
          %MemoryInvalidationRequest{} = request,
          _opts
        ) do
      memory_action_result(request.root_fragment_ref, "invalidate", "Invalidation requested")
    end

    defp memory_fragment_projection do
      {:ok, projection} =
        MemoryFragmentProjection.new(%{
          fragment_ref: "memory-private://alpha/private-1",
          tenant_ref: "tenant://alpha",
          installation_ref: "installation://alpha",
          tier: "private",
          proof_token_ref: "proof://recall/1",
          proof_hash: valid_hash("proof"),
          source_node_ref: "node://memory-reader@host/reader-1",
          snapshot_epoch: 42,
          commit_lsn: "16/B374D848",
          commit_hlc: %{wall_ns: 1_800_000_000_000_000_000, logical: 1, node: "reader-1"},
          provenance_refs: ["provenance://outer-brain/context/1"],
          evidence_refs: [%{ref: "evidence://recall/1", kind: "proof"}],
          governance_refs: [%{ref: "governance://memory/read", kind: "read"}],
          cluster_invalidation_status: "none",
          staleness_class: "fresh",
          redaction_posture: "operator_safe"
        })

      projection
    end

    defp memory_action_result(fragment_ref, action_kind, message) do
      ActionResult.new(%{
        status: :accepted,
        action_ref: %{
          id: "#{fragment_ref}:#{action_kind}",
          action_kind: action_kind
        },
        message: message,
        metadata: %{fragment_ref: fragment_ref}
      })
    end

    defp valid_hash(seed) do
      "sha256:" <> Base.encode16(:crypto.hash(:sha256, seed), case: :lower)
    end
  end

  alias AppKit.Core.{
    MemoryFragmentListRequest,
    MemoryInvalidationRequest,
    MemoryPromotionRequest,
    MemoryProofTokenLookup,
    MemoryShareUpRequest,
    OperatorActionRequest,
    RequestContext,
    RunRef,
    SubjectRef
  }

  alias AppKit.OperatorSurface

  test "projects run status and review output" do
    assert {:ok, run_ref} = RunRef.new(%{run_id: "run-1", scope_id: "workspace/main"})

    assert {:ok, projection} =
             OperatorSurface.run_status(run_ref, %{
               route_name: :compile_workspace,
               state: :waiting_review
             })

    assert {:ok, review} =
             OperatorSurface.review_run(run_ref, %{kind: :operator_note, summary: "looks good"})

    assert projection.run_id == "run-1"
    assert review.decision.state == :approved
  end

  test "delegates projection and review through a configured backend" do
    assert {:ok, run_ref} = RunRef.new(%{run_id: "run-2", scope_id: "workspace/main"})

    assert {:ok, projection} =
             OperatorSurface.run_status(
               run_ref,
               %{route_name: :compile_workspace},
               operator_backend: FakeOperatorBackend
             )

    assert {:ok, review} =
             OperatorSurface.review_run(
               run_ref,
               %{kind: :operator_note, summary: "needs context"},
               operator_backend: FakeOperatorBackend,
               reason: "operator requested detail"
             )

    assert projection.backend == :fake
    assert review.backend == :fake
    assert review.reason == "operator requested detail"
  end

  test "projects subject status, timeline, unified trace, actions, and action application" do
    context = request_context()
    subject_ref = subject_ref()

    assert {:ok, projection} =
             OperatorSurface.subject_status(
               context,
               subject_ref,
               operator_backend: FakeOperatorBackend
             )

    assert {:ok, timeline} =
             OperatorSurface.timeline(
               context,
               subject_ref,
               operator_backend: FakeOperatorBackend
             )

    assert {:ok, actions} =
             OperatorSurface.available_actions(
               context,
               subject_ref,
               operator_backend: FakeOperatorBackend
             )

    assert {:ok, action_request} =
             OperatorActionRequest.new(%{
               action_ref: hd(actions).action_ref,
               params: %{"reason" => "needs manual stop"}
             })

    assert {:ok, action_result} =
             OperatorSurface.apply_action(
               context,
               subject_ref,
               action_request,
               operator_backend: FakeOperatorBackend
             )

    assert {:ok, trace} =
             OperatorSurface.get_unified_trace(
               context,
               projection.current_execution_ref,
               operator_backend: FakeOperatorBackend
             )

    assert {:ok, read_lease} =
             OperatorSurface.issue_read_lease(
               context,
               projection.current_execution_ref,
               operator_backend: FakeOperatorBackend
             )

    assert {:ok, stream_lease} =
             OperatorSurface.issue_stream_attach_lease(
               context,
               projection.current_execution_ref,
               operator_backend: FakeOperatorBackend
             )

    assert projection.payload.trace_id == context.trace_id
    assert hd(timeline).event_kind == "run_scheduled"
    assert hd(actions).action_ref.action_kind == "cancel"
    assert action_result.action_ref.action_kind == "cancel"
    assert hd(trace.steps).source == "execution_record"
    assert read_lease.lease_ref.allowed_family == "unified_trace"
    assert stream_lease.lease_ref.allowed_family == "runtime_stream"
  end

  test "delegates memory-control listing, proof lookup, provenance, and write requests" do
    context = request_context()

    assert {:ok, list_request} =
             MemoryFragmentListRequest.new(%{
               proof_token_ref: "proof://recall/1",
               include_provenance?: true
             })

    assert {:ok, proof_lookup} =
             MemoryProofTokenLookup.new(%{
               proof_token_ref: "proof://recall/1",
               expected_tenant_ref: "tenant://alpha",
               reject_stale?: true,
               current_epoch: 42
             })

    assert {:ok, share_up_request} =
             MemoryShareUpRequest.new(%{
               fragment_ref: "memory-private://alpha/private-1",
               target_scope_ref: "scope://team-alpha",
               share_up_policy_ref: "share-up-policy://team-alpha",
               transform_ref: "transform://redact-pii",
               reason: "share project memory",
               evidence_refs: [%{ref: "evidence://operator/share-up", kind: "operator"}]
             })

    assert {:ok, promotion_request} =
             MemoryPromotionRequest.new(%{
               shared_fragment_ref: "memory-shared://alpha/shared-1",
               promotion_policy_ref: "promote-policy://governed",
               reason: "approved for governed memory",
               evidence_refs: [%{ref: "evidence://operator/promote", kind: "operator"}]
             })

    assert {:ok, invalidation_request} =
             MemoryInvalidationRequest.new(%{
               root_fragment_ref: "memory-private://alpha/private-1",
               reason: :operator_suppression,
               suppression_reason: "obsolete user preference",
               invalidate_policy_ref: "invalidate-policy://default",
               authority_ref: %{ref: "authority://operator/suppression", kind: "operator"},
               evidence_refs: [%{ref: "evidence://operator/invalidate", kind: "operator"}]
             })

    backend_opts = [operator_backend: FakeOperatorBackend]

    assert {:ok, [fragment]} =
             OperatorSurface.list_memory_fragments(context, list_request, backend_opts)

    assert {:ok, same_fragment} =
             OperatorSurface.memory_fragment_by_proof_token(context, proof_lookup, backend_opts)

    assert {:ok, provenance} =
             OperatorSurface.memory_fragment_provenance(
               context,
               "memory-private://alpha/private-1",
               backend_opts
             )

    assert {:ok, share_up_result} =
             OperatorSurface.request_memory_share_up(context, share_up_request, backend_opts)

    assert {:ok, promotion_result} =
             OperatorSurface.request_memory_promotion(context, promotion_request, backend_opts)

    assert {:ok, invalidation_result} =
             OperatorSurface.request_memory_invalidation(
               context,
               invalidation_request,
               backend_opts
             )

    assert fragment.proof_hash == same_fragment.proof_hash
    assert provenance.source_contract_name == "OuterBrain.MemoryContextProvenance.v2"
    assert share_up_result.action_ref.action_kind == "share_up"
    assert promotion_result.action_ref.action_kind == "promote"
    assert invalidation_result.action_ref.action_kind == "invalidate"
  end

  defp request_context do
    {:ok, context} =
      RequestContext.new(%{
        trace_id: "33333333333333333333333333333333",
        actor_ref: %{id: "user-1", kind: :human},
        tenant_ref: %{id: "tenant-1"},
        installation_ref: %{id: "inst-1", pack_slug: "expense_approval", status: :active}
      })

    context
  end

  defp subject_ref do
    {:ok, subject_ref} =
      SubjectRef.new(%{
        id: "subj-1",
        subject_kind: "expense_request"
      })

    subject_ref
  end
end
