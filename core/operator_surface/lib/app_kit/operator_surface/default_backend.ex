defmodule AppKit.OperatorSurface.DefaultBackend do
  @moduledoc """
  Default lower-stack-backed implementation for `AppKit.OperatorSurface`.
  """

  @behaviour AppKit.Core.Backends.OperatorBackend

  alias AppKit.Bridges.{IntegrationBridge, ProjectionBridge}

  alias AppKit.Core.{
    ActionResult,
    ExecutionRef,
    MemoryFragmentListRequest,
    MemoryFragmentProjection,
    MemoryFragmentProvenance,
    MemoryInvalidationRequest,
    MemoryPromotionRequest,
    MemoryProofTokenLookup,
    MemoryShareUpRequest,
    OperatorAction,
    OperatorActionRequest,
    OperatorProjection,
    ReadLease,
    RequestContext,
    RunRef,
    StreamAttachLease,
    SubjectRef,
    SurfaceError,
    TimelineEvent,
    UnifiedTrace
  }

  alias AppKit.RunGovernance

  @impl true
  @spec subject_status(RequestContext.t(), SubjectRef.t(), keyword()) ::
          {:ok, OperatorProjection.t()} | {:error, SurfaceError.t()}
  def subject_status(%RequestContext{} = context, %SubjectRef{} = subject_ref, opts)
      when is_list(opts) do
    OperatorProjection.new(%{
      subject_ref: subject_ref,
      lifecycle_state: Keyword.get(opts, :lifecycle_state, "unknown"),
      current_execution_ref: Keyword.get(opts, :current_execution_ref),
      available_actions: default_available_actions(subject_ref, opts),
      timeline: Keyword.get(opts, :timeline, []),
      payload: %{trace_id: context.trace_id}
    })
  end

  @impl true
  @spec timeline(RequestContext.t(), SubjectRef.t(), keyword()) ::
          {:ok, [TimelineEvent.t()]} | {:error, SurfaceError.t()}
  def timeline(%RequestContext{} = context, %SubjectRef{} = subject_ref, opts)
      when is_list(opts) do
    {:ok,
     Keyword.get(
       opts,
       :timeline,
       [
         TimelineEvent.new!(%{
           ref: "#{subject_ref.id}:timeline",
           event_kind: "status_inspected",
           occurred_at: DateTime.utc_now(),
           summary: "Operator timeline requested",
           payload: %{"trace_id" => context.trace_id}
         })
       ]
     )}
  end

  @impl true
  @spec get_unified_trace(RequestContext.t(), ExecutionRef.t(), keyword()) ::
          {:ok, UnifiedTrace.t()} | {:error, SurfaceError.t()}
  def get_unified_trace(%RequestContext{} = context, %ExecutionRef{} = execution_ref, opts)
      when is_list(opts) do
    UnifiedTrace.new(%{
      trace_id: context.trace_id,
      installation_ref: context.installation_ref,
      join_keys: %{"execution_id" => execution_ref.id},
      steps:
        Keyword.get(
          opts,
          :trace_steps,
          [
            %{
              ref: "#{execution_ref.id}:trace",
              source: "operator_projection",
              occurred_at: DateTime.utc_now(),
              trace_id: context.trace_id,
              staleness_class: "projection_stale",
              operator_actionable?: false,
              diagnostic?: false,
              payload: %{"execution_id" => execution_ref.id}
            }
          ]
        )
    })
  end

  @impl true
  @spec issue_read_lease(RequestContext.t(), ExecutionRef.t(), keyword()) ::
          {:ok, ReadLease.t()} | {:error, SurfaceError.t()}
  def issue_read_lease(%RequestContext{} = context, %ExecutionRef{} = execution_ref, opts)
      when is_list(opts) do
    ReadLease.new(%{
      lease_ref: %{
        id: Keyword.get(opts, :lease_id, "#{execution_ref.id}:read"),
        allowed_family: Keyword.get(opts, :allowed_family, "unified_trace"),
        execution_ref: execution_ref
      },
      trace_id: context.trace_id,
      expires_at: Keyword.get(opts, :expires_at, DateTime.utc_now()),
      lease_token: Keyword.get(opts, :lease_token, "read-lease-token"),
      allowed_operations: Keyword.get(opts, :allowed_operations, ["fetch_run"]),
      authorization_scope:
        Keyword.get(opts, :authorization_scope, authorization_scope(context, execution_ref)),
      scope: Keyword.get(opts, :scope, %{}),
      lineage_anchor: Keyword.get(opts, :lineage_anchor, %{"execution_id" => execution_ref.id}),
      invalidation_cursor: Keyword.get(opts, :invalidation_cursor, 0),
      invalidation_channel: Keyword.get(opts, :invalidation_channel, "read:default")
    })
  end

  @impl true
  @spec issue_stream_attach_lease(RequestContext.t(), ExecutionRef.t(), keyword()) ::
          {:ok, StreamAttachLease.t()} | {:error, SurfaceError.t()}
  def issue_stream_attach_lease(
        %RequestContext{} = context,
        %ExecutionRef{} = execution_ref,
        opts
      )
      when is_list(opts) do
    StreamAttachLease.new(%{
      lease_ref: %{
        id: Keyword.get(opts, :lease_id, "#{execution_ref.id}:stream"),
        allowed_family: Keyword.get(opts, :allowed_family, "runtime_stream"),
        execution_ref: execution_ref
      },
      trace_id: context.trace_id,
      expires_at: Keyword.get(opts, :expires_at, DateTime.utc_now()),
      attach_token: Keyword.get(opts, :attach_token, "stream-attach-token"),
      authorization_scope:
        Keyword.get(opts, :authorization_scope, authorization_scope(context, execution_ref)),
      scope: Keyword.get(opts, :scope, %{}),
      lineage_anchor: Keyword.get(opts, :lineage_anchor, %{"execution_id" => execution_ref.id}),
      reconnect_cursor: Keyword.get(opts, :reconnect_cursor, 0),
      invalidation_channel: Keyword.get(opts, :invalidation_channel, "stream:default"),
      poll_interval_ms: Keyword.get(opts, :poll_interval_ms, 2_000)
    })
  end

  @impl true
  @spec available_actions(RequestContext.t(), SubjectRef.t(), keyword()) ::
          {:ok, [OperatorAction.t()]} | {:error, SurfaceError.t()}
  def available_actions(%RequestContext{} = _context, %SubjectRef{} = subject_ref, opts)
      when is_list(opts) do
    {:ok, default_available_actions(subject_ref, opts)}
  end

  @impl true
  @spec apply_action(RequestContext.t(), SubjectRef.t(), OperatorActionRequest.t(), keyword()) ::
          {:ok, ActionResult.t()} | {:error, SurfaceError.t()}
  def apply_action(
        %RequestContext{} = context,
        %SubjectRef{} = subject_ref,
        %OperatorActionRequest{} = action_request,
        opts
      )
      when is_list(opts) do
    ActionResult.new(%{
      status: Keyword.get(opts, :action_status, :completed),
      action_ref: action_request.action_ref,
      execution_ref: Keyword.get(opts, :execution_ref),
      message:
        Keyword.get(
          opts,
          :message,
          "#{action_request.action_ref.action_kind} applied via default backend"
        ),
      metadata: %{
        subject_id: subject_ref.id,
        trace_id: context.trace_id,
        params: action_request.params
      }
    })
  end

  @impl true
  def list_memory_fragments(
        %RequestContext{} = context,
        %MemoryFragmentListRequest{} = request,
        opts
      )
      when is_list(opts) do
    {:ok, [default_memory_fragment(context, request.proof_token_ref, opts)]}
  end

  @impl true
  def memory_fragment_by_proof_token(
        %RequestContext{} = context,
        %MemoryProofTokenLookup{} = lookup,
        opts
      )
      when is_list(opts) do
    {:ok, default_memory_fragment(context, lookup.proof_token_ref, opts)}
  end

  @impl true
  def memory_fragment_provenance(%RequestContext{} = context, fragment_ref, opts)
      when is_binary(fragment_ref) and is_list(opts) do
    MemoryFragmentProvenance.new(%{
      fragment_ref: fragment_ref,
      proof_token_ref: Keyword.get(opts, :proof_token_ref, "proof://default"),
      proof_hash: Keyword.get(opts, :proof_hash, default_hash("proof")),
      source_contract_name: "OuterBrain.MemoryContextProvenance.v2",
      snapshot_epoch: Keyword.get(opts, :snapshot_epoch, 1),
      source_node_ref: Keyword.get(opts, :source_node_ref, "node://app-kit/default"),
      commit_lsn: Keyword.get(opts, :commit_lsn, "0/0"),
      commit_hlc: Keyword.get(opts, :commit_hlc, default_commit_hlc()),
      provenance_refs: Keyword.get(opts, :provenance_refs, ["provenance://app-kit/default"]),
      evidence_refs: Keyword.get(opts, :evidence_refs, [%{ref: "evidence://app-kit/default"}]),
      governance_refs:
        Keyword.get(opts, :governance_refs, [%{ref: "governance://app-kit/default"}]),
      metadata: %{trace_id: context.trace_id}
    })
  end

  @impl true
  def request_memory_share_up(
        %RequestContext{} = _context,
        %MemoryShareUpRequest{} = request,
        opts
      )
      when is_list(opts) do
    memory_action_result(
      request.fragment_ref,
      "share_up",
      Keyword.get(opts, :message, "Share-up requested")
    )
  end

  @impl true
  def request_memory_promotion(
        %RequestContext{} = _context,
        %MemoryPromotionRequest{} = request,
        opts
      )
      when is_list(opts) do
    memory_action_result(
      request.shared_fragment_ref,
      "promote",
      Keyword.get(opts, :message, "Promotion requested")
    )
  end

  @impl true
  def request_memory_invalidation(
        %RequestContext{} = _context,
        %MemoryInvalidationRequest{} = request,
        opts
      )
      when is_list(opts) do
    memory_action_result(
      request.root_fragment_ref,
      "invalidate",
      Keyword.get(opts, :message, "Invalidation requested")
    )
  end

  @impl true
  def run_status(%RunRef{} = run_ref, attrs, _opts) when is_map(attrs) do
    ProjectionBridge.operator_projection(run_ref, attrs)
  end

  @impl true
  def review_run(%RunRef{} = run_ref, evidence_attrs, opts) do
    with {:ok, evidence} <- RunGovernance.evidence(evidence_attrs),
         state <- RunGovernance.review_state(evidence, opts),
         {:ok, decision} <-
           RunGovernance.decision(%{
             run_id: run_ref.run_id,
             state: state,
             reason: Keyword.get(opts, :reason)
           }),
         {:ok, review_bundle} <-
           IntegrationBridge.review_bundle(run_ref, %{
             summary: evidence.summary,
             evidence_count: 1
           }) do
      {:ok, %{decision: decision, review_bundle: review_bundle}}
    end
  end

  defp default_available_actions(subject_ref, opts) do
    Keyword.get_lazy(opts, :available_actions, fn ->
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
      ]
    end)
  end

  defp default_memory_fragment(%RequestContext{} = context, proof_token_ref, opts) do
    {:ok, projection} =
      MemoryFragmentProjection.new(%{
        fragment_ref: Keyword.get(opts, :fragment_ref, "memory://default"),
        tenant_ref: context.tenant_ref.id,
        installation_ref: context.installation_ref && context.installation_ref.id,
        tier: Keyword.get(opts, :tier, "unknown"),
        proof_token_ref: proof_token_ref,
        proof_hash: Keyword.get(opts, :proof_hash, default_hash(proof_token_ref)),
        source_node_ref: Keyword.get(opts, :source_node_ref, "node://app-kit/default"),
        snapshot_epoch: Keyword.get(opts, :snapshot_epoch, 1),
        commit_lsn: Keyword.get(opts, :commit_lsn, "0/0"),
        commit_hlc: Keyword.get(opts, :commit_hlc, default_commit_hlc()),
        provenance_refs: Keyword.get(opts, :provenance_refs, ["provenance://app-kit/default"]),
        evidence_refs: Keyword.get(opts, :evidence_refs, [%{ref: "evidence://app-kit/default"}]),
        governance_refs:
          Keyword.get(opts, :governance_refs, [%{ref: "governance://app-kit/default"}]),
        cluster_invalidation_status: Keyword.get(opts, :cluster_invalidation_status, "unknown"),
        staleness_class: Keyword.get(opts, :staleness_class, "unknown"),
        redaction_posture: Keyword.get(opts, :redaction_posture, "operator_safe"),
        metadata: %{trace_id: context.trace_id}
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

  defp default_hash(seed) when is_binary(seed) do
    "sha256:" <> Base.encode16(:crypto.hash(:sha256, seed), case: :lower)
  end

  defp default_commit_hlc do
    %{wall_ns: System.system_time(:nanosecond), logical: 0, node: "app-kit"}
  end

  defp authorization_scope(%RequestContext{} = context, %ExecutionRef{} = execution_ref) do
    %{
      tenant_id: context.tenant_ref.id,
      installation_id: context.installation_ref && context.installation_ref.id,
      subject_id: execution_ref.subject_ref && execution_ref.subject_ref.id,
      execution_id: execution_ref.id,
      trace_id: context.trace_id,
      actor_ref: Map.from_struct(context.actor_ref),
      authorized_at: DateTime.utc_now()
    }
    |> Map.reject(fn {_key, value} -> is_nil(value) end)
  end
end
