defmodule AppKit.OperatorSurface.DefaultBackend do
  @moduledoc """
  Default lower-stack-backed implementation for `AppKit.OperatorSurface`.
  """

  @behaviour AppKit.Core.Backends.OperatorBackend

  alias AppKit.Bridges.{IntegrationBridge, ProjectionBridge}

  alias AppKit.Core.{
    ActionResult,
    ExecutionRef,
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
              freshness: "northbound_projection",
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
