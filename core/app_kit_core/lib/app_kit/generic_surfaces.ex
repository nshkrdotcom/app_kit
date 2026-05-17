defmodule AppKit.Sources do
  @moduledoc "Generic source surface using product role refs."

  alias AppKit.Core.{Context, GenericSurfaceSupport}

  @backend_key :generic_backend

  def sync_source(%Context{} = context, source_role_ref, request, opts \\ []) do
    GenericSurfaceSupport.dispatch(opts, @backend_key, :sync_source, [
      context,
      source_role_ref,
      request
    ])
  end

  def fetch_candidates(%Context{} = context, source_role_ref, query, opts \\ []) do
    GenericSurfaceSupport.dispatch(opts, @backend_key, :fetch_candidates, [
      context,
      source_role_ref,
      query
    ])
  end

  def current_states(%Context{} = context, source_role_ref, source_object_refs, opts \\ []) do
    request = %{source_object_refs: source_object_refs}

    GenericSurfaceSupport.dispatch(opts, @backend_key, :current_states, [
      context,
      source_role_ref,
      request
    ])
  end

  def publish(%Context{} = context, publication_role_ref, request, opts \\ []) do
    GenericSurfaceSupport.dispatch(opts, @backend_key, :publish, [
      context,
      publication_role_ref,
      request
    ])
  end

  def execute_operation(
        %Context{} = context,
        source_role_ref,
        operation_role_ref,
        request,
        opts \\ []
      ) do
    GenericSurfaceSupport.dispatch(opts, @backend_key, :execute_operation, [
      context,
      source_role_ref,
      operation_role_ref,
      request
    ])
  end
end

defmodule AppKit.Work do
  @moduledoc "Generic work command surface."

  alias AppKit.Core.{Context, GenericSurfaceSupport}

  @backend_key :generic_backend

  def submit(%Context{} = context, work_request, opts \\ []) do
    GenericSurfaceSupport.dispatch(opts, @backend_key, :submit_work, [context, work_request])
  end

  def start(%Context{} = context, work_item_ref, opts \\ []) do
    submit(context, %{action: :start, work_item_ref: work_item_ref}, opts)
  end

  def pause(%Context{} = context, work_item_ref, reason, opts \\ []) do
    submit(context, %{action: :pause, work_item_ref: work_item_ref, reason: reason}, opts)
  end

  def resume(%Context{} = context, work_item_ref, reason, opts \\ []) do
    submit(context, %{action: :resume, work_item_ref: work_item_ref, reason: reason}, opts)
  end

  def cancel(%Context{} = context, work_item_ref, reason, opts \\ []) do
    submit(context, %{action: :cancel, work_item_ref: work_item_ref, reason: reason}, opts)
  end

  def get(%Context{} = context, work_item_ref, opts \\ []) do
    submit(context, %{action: :get, work_item_ref: work_item_ref}, opts)
  end

  def list(%Context{} = context, filters, opts \\ []) do
    submit(context, %{action: :list, filters: filters}, opts)
  end

  def get_runtime_projection(%Context{} = context, subject_ref, opts \\ []) do
    AppKit.Projections.get(context, %{subject_ref: subject_ref, projection_kind: :runtime}, opts)
  end
end

defmodule AppKit.Evidence do
  @moduledoc "Generic evidence surface."

  alias AppKit.Core.{Context, GenericSurfaceSupport}

  @backend_key :generic_backend

  def attach(%Context{} = context, subject_ref, evidence_record, opts \\ []) do
    request = %{subject_ref: subject_ref, evidence_record: evidence_record}

    GenericSurfaceSupport.dispatch(opts, @backend_key, :collect_evidence, [
      context,
      :attached,
      request
    ])
  end

  def collect(%Context{} = context, evidence_role_ref, request, opts \\ []) do
    GenericSurfaceSupport.dispatch(opts, @backend_key, :collect_evidence, [
      context,
      evidence_role_ref,
      request
    ])
  end

  def list(%Context{} = context, subject_ref, opts \\ []) do
    collect(context, :evidence_readback, %{subject_ref: subject_ref}, opts)
  end

  def get_receipt(%Context{} = context, receipt_ref, opts \\ []) do
    collect(context, :evidence_readback, %{receipt_ref: receipt_ref}, opts)
  end
end

defmodule AppKit.Reviews do
  @moduledoc "Generic review surface."

  alias AppKit.Core.{Context, GenericSurfaceSupport}

  @backend_key :generic_backend

  def open(%Context{} = context, subject_ref, request, opts \\ []) do
    GenericSurfaceSupport.dispatch(opts, @backend_key, :open_review, [
      context,
      subject_ref,
      request
    ])
  end

  def submit_decision(%Context{} = context, review_ref, decision, opts \\ []) do
    request = %{decision: decision}

    GenericSurfaceSupport.dispatch(opts, @backend_key, :submit_review_decision, [
      context,
      review_ref,
      request
    ])
  end

  def request_changes(%Context{} = context, review_ref, reason, opts \\ []) do
    submit_decision(context, review_ref, %{decision: :request_changes, reason: reason}, opts)
  end

  def approve(%Context{} = context, review_ref, reason, opts \\ []) do
    submit_decision(context, review_ref, %{decision: :approve, reason: reason}, opts)
  end

  def reject(%Context{} = context, review_ref, reason, opts \\ []) do
    submit_decision(context, review_ref, %{decision: :reject, reason: reason}, opts)
  end

  def list_pending(%Context{} = context, page, opts \\ []) do
    open(context, :review_readback, %{page: page}, opts)
  end

  def get(%Context{} = context, review_ref, opts \\ []) do
    open(context, review_ref, %{action: :get}, opts)
  end
end

defmodule AppKit.Projections do
  @moduledoc "Generic projection read surface."

  alias AppKit.Core.{Context, GenericSurfaceSupport}

  @backend_key :generic_backend

  def get(%Context{} = context, request, opts \\ []) do
    GenericSurfaceSupport.dispatch(opts, @backend_key, :get_projection, [context, request])
  end
end

defmodule AppKit.Traces do
  @moduledoc "Generic trace lookup, replay, and export surface."

  alias AppKit.Core.{Context, GenericSurfaceSupport}

  @backend_key :generic_backend

  def lookup(%Context{} = context, trace_ref, opts \\ []) do
    GenericSurfaceSupport.dispatch(opts, @backend_key, :lookup_trace, [context, trace_ref])
  end

  def replay(%Context{} = context, trace_ref, opts \\ []) do
    GenericSurfaceSupport.dispatch(opts, @backend_key, :replay_trace, [context, trace_ref])
  end

  def export(%Context{} = context, trace_ref, redaction_policy_ref, opts \\ []) do
    request = %{trace_ref: trace_ref, redaction_policy_ref: redaction_policy_ref}
    GenericSurfaceSupport.dispatch(opts, @backend_key, :replay_trace, [context, request])
  end
end

defmodule AppKit.Leases do
  @moduledoc "Generic lower-read and stream-attach lease surface."

  alias AppKit.Core.{Context, GenericSurfaceSupport}

  @backend_key :generic_backend

  def request_lower_read(%Context{} = context, subject_ref, scope, opts \\ []) do
    GenericSurfaceSupport.dispatch(opts, @backend_key, :request_lower_read, [
      context,
      subject_ref,
      scope
    ])
  end

  def request_stream_attach(%Context{} = context, subject_ref, scope, opts \\ []) do
    request_lower_read(context, subject_ref, %{scope: scope, attach: :stream}, opts)
  end

  def revoke(%Context{} = context, lease_ref, reason, opts \\ []) do
    request_lower_read(context, lease_ref, %{action: :revoke, reason: reason}, opts)
  end
end
