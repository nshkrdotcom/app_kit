defmodule AppKit.GenericSurfacesTest do
  use ExUnit.Case, async: true

  alias AppKit.Core.Context
  alias AppKit.Core.Backends.GenericBackend

  defmodule FakeGenericBackend do
    @behaviour GenericBackend

    def sync_source(context, role_ref, request, _opts) do
      {:ok, {:sync_source, context.trace_ref, role_ref, request}}
    end

    def submit_work(context, request, _opts),
      do: {:ok, {:submit_work, context.trace_ref, request}}

    def collect_evidence(context, role_ref, request, _opts) do
      {:ok, {:collect_evidence, context.trace_ref, role_ref, request}}
    end

    def open_review(context, subject_ref, request, _opts) do
      {:ok, {:open_review, context.trace_ref, subject_ref, request}}
    end

    def get_projection(context, request, _opts),
      do: {:ok, {:get_projection, context.trace_ref, request}}

    def lookup_trace(context, trace_ref, _opts),
      do: {:ok, {:lookup_trace, context.trace_ref, trace_ref}}

    def request_lower_read(context, subject_ref, scope, _opts) do
      {:ok, {:request_lower_read, context.trace_ref, subject_ref, scope}}
    end
  end

  test "generic source surface uses role refs and explicit generic backend" do
    context = context!()

    assert {:ok, {:sync_source, "trace://tenant-a/request-a", :issue_tracker, %{cursor: nil}}} =
             AppKit.Sources.sync_source(context, :issue_tracker, %{cursor: nil},
               generic_backend: FakeGenericBackend
             )
  end

  test "generic surfaces fail closed without a generic backend" do
    assert {:error, error} = AppKit.Sources.sync_source(context!(), :issue_tracker, %{})
    assert error.code == "generic_app_kit_surface_not_ready"
    assert error.kind == :boundary
  end

  test "generic surfaces reject concrete binding refs at public call sites" do
    assert {:error, error} =
             AppKit.Sources.sync_source(
               context!(),
               :issue_tracker,
               %{source_binding_ref: "binding://tenant-a/install-a/source-a"},
               generic_backend: FakeGenericBackend
             )

    assert error.code == "generic_app_kit_surface_not_ready"
    assert error.details.reason == {:forbidden_generic_request_field, :source_binding_ref}
  end

  test "generic work, evidence, review, projection, trace, and lease surfaces dispatch" do
    context = context!()
    opts = [generic_backend: FakeGenericBackend]

    assert {:ok, {:submit_work, _, %{work_role_ref: :review_work}}} =
             AppKit.Work.submit(context, %{work_role_ref: :review_work}, opts)

    assert {:ok, {:collect_evidence, _, :evidence_role, %{subject_ref: "subject://a"}}} =
             AppKit.Evidence.collect(context, :evidence_role, %{subject_ref: "subject://a"}, opts)

    assert {:ok, {:open_review, _, "subject://a", %{kind: :review}}} =
             AppKit.Reviews.open(context, "subject://a", %{kind: :review}, opts)

    assert {:ok, {:get_projection, _, %{subject_ref: "subject://a"}}} =
             AppKit.Projections.get(context, %{subject_ref: "subject://a"}, opts)

    assert {:ok, {:lookup_trace, _, "trace://tenant-a/other"}} =
             AppKit.Traces.lookup(context, "trace://tenant-a/other", opts)

    assert {:ok, {:request_lower_read, _, "subject://a", :read}} =
             AppKit.Leases.request_lower_read(context, "subject://a", :read, opts)
  end

  defp context! do
    {:ok, context} =
      Context.new(%{
        actor_ref: %{id: "actor-a", kind: :user},
        tenant_ref: %{id: "tenant-a"},
        installation_ref: %{id: "install-a", pack_slug: "product-a"},
        trace_ref: "trace://tenant-a/request-a",
        request_ref: "request://tenant-a/request-a",
        idempotency_key: "idempotency://tenant-a/request-a"
      })

    context
  end
end
