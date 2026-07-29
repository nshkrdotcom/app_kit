defmodule AppKit.Bridges.MezzanineBridge.ProductSurfaceAdapterTest do
  use ExUnit.Case, async: true

  alias AppKit.Bridges.MezzanineBridge.ProductSurfaceAdapter
  alias AppKit.Core.PersistencePosture
  alias AppKit.Core.ProductSurface.{CapabilityProjection, RunProjection}
  alias AppKit.Core.{RequestContext, SurfaceError}

  @run_ref "run://synapse/tenant-1/product-surface"
  @tenant_ref "tenant://synapse/tenant-1"

  defmodule FakeOwner do
    def run_projection(context, run_ref, opts) do
      send(Keyword.fetch!(opts, :test_pid), {:run_projection, context, run_ref, opts})
      Keyword.fetch!(opts, :run_projection_result)
    end

    def capability_projections(context, request, opts) do
      send(
        Keyword.fetch!(opts, :test_pid),
        {:capability_projections, context, request, opts}
      )

      Keyword.fetch!(opts, :capability_projection_result)
    end
  end

  defmodule IncompleteOwner do
    def run_projection(_context, _run_ref, _opts), do: {:ok, %{state: :running}}

    def capability_projections(_context, _request, _opts) do
      {:ok, [%{advertised?: true}]}
    end
  end

  test "calls the explicitly injected owner and returns its revalidated run truth" do
    projection = run_projection_attrs()
    context = context()

    assert {:ok, %RunProjection{} = result} =
             ProductSurfaceAdapter.run_projection(
               context,
               @run_ref,
               product_projection_service: FakeOwner,
               run_projection_result: {:ok, projection},
               test_pid: self()
             )

    assert_receive {:run_projection, ^context, @run_ref, owner_opts}
    assert owner_opts[:product_projection_service] == FakeOwner
    assert result.run_ref == projection.run_ref
    assert result.owner_projection_ref == projection.owner_projection_ref
    assert result.source_contract_ref == projection.source_contract_ref
    assert result.cursor.tenant_ref == @tenant_ref
    assert result.turns == []
    assert result.events == []
    assert result.operations == []
  end

  test "fails closed when the product projection owner is absent or incomplete" do
    assert {:error,
            %SurfaceError{
              code: "product_projection_owner_not_configured",
              kind: :boundary,
              retryable: false
            }} = ProductSurfaceAdapter.run_projection(context(), @run_ref, [])

    assert {:error,
            %SurfaceError{
              code: "product_projection_owner_not_configured",
              kind: :boundary,
              retryable: false
            }} = ProductSurfaceAdapter.capability_projections(context(), %{}, [])

    assert {:error,
            %SurfaceError{
              code: "invalid_product_run_projection",
              kind: :validation,
              retryable: false
            }} =
             ProductSurfaceAdapter.run_projection(
               context(),
               @run_ref,
               product_projection_service: IncompleteOwner
             )

    assert {:error,
            %SurfaceError{
              code: "invalid_product_capability_projection",
              kind: :validation,
              retryable: false
            }} =
             ProductSurfaceAdapter.capability_projections(
               context(),
               %{},
               product_projection_service: IncompleteOwner
             )
  end

  test "rejects run identity mismatches anywhere in the composite" do
    outer_mismatch = Map.put(run_projection_attrs(), :run_ref, "run://synapse/other")

    assert {:error,
            %SurfaceError{
              code: "product_run_identity_mismatch",
              kind: :validation,
              retryable: false
            }} =
             ProductSurfaceAdapter.run_projection(
               context(),
               @run_ref,
               product_projection_service: FakeOwner,
               run_projection_result: {:ok, outer_mismatch},
               test_pid: self()
             )

    nested_mismatch =
      put_in(
        run_projection_attrs(),
        [:control, :run_ref],
        "run://synapse/other"
      )

    assert {:error,
            %SurfaceError{
              code: "product_run_identity_mismatch",
              kind: :validation,
              retryable: false
            }} =
             ProductSurfaceAdapter.run_projection(
               context(),
               @run_ref,
               product_projection_service: FakeOwner,
               run_projection_result: {:ok, nested_mismatch},
               test_pid: self()
             )
  end

  test "rejects a projection cursor from another request tenant" do
    tenant_mismatch =
      put_in(
        run_projection_attrs(),
        [:cursor, :tenant_ref],
        "tenant://synapse/other"
      )

    assert {:error,
            %SurfaceError{
              code: "product_cursor_tenant_mismatch",
              kind: :authorization,
              retryable: false
            }} =
             ProductSurfaceAdapter.run_projection(
               context(),
               @run_ref,
               product_projection_service: FakeOwner,
               run_projection_result: {:ok, tenant_mismatch},
               test_pid: self()
             )
  end

  test "preserves advertised and unavailable capability truth in owner order" do
    capabilities = [
      capability_attrs(%{
        capability_ref: "capability://model/gemini-completion",
        advertised?: true,
        operation_refs: ["operation-class://model/completion"],
        availability: :available
      }),
      capability_attrs(%{
        capability_ref: "capability://execution/runtime-http",
        kind: :execution_lane,
        configured_mode: :runtime_admitted,
        advertised?: false,
        operation_refs: [],
        availability: {:unavailable, :not_admitted}
      })
    ]

    context = context()
    request = %{scope_ref: @tenant_ref}

    assert {:ok, [%CapabilityProjection{} = advertised, %CapabilityProjection{} = unavailable]} =
             ProductSurfaceAdapter.capability_projections(
               context,
               request,
               product_projection_service: FakeOwner,
               capability_projection_result: {:ok, capabilities},
               test_pid: self()
             )

    assert_receive {:capability_projections, ^context, ^request, owner_opts}
    assert owner_opts[:product_projection_service] == FakeOwner
    assert advertised.advertised?
    assert advertised.availability.state == :available
    refute unavailable.advertised?
    assert unavailable.availability.state == :unavailable
    assert unavailable.availability.reason == :not_admitted
  end

  test "deeply revalidates capability structs instead of trusting prebuilt values" do
    {:ok, capability} =
      CapabilityProjection.new(
        capability_attrs(%{
          advertised?: true,
          operation_refs: ["operation-class://model/completion"],
          availability: :available
        })
      )

    tampered = %{capability | operation_refs: []}

    assert {:error,
            %SurfaceError{
              code: "invalid_product_capability_projection",
              kind: :validation,
              retryable: false
            }} =
             ProductSurfaceAdapter.capability_projections(
               context(),
               %{},
               product_projection_service: FakeOwner,
               capability_projection_result: {:ok, [tampered]},
               test_pid: self()
             )
  end

  test "rejects malformed requests and non-list owner responses" do
    assert {:error, %SurfaceError{code: "invalid_product_run_projection_request"}} =
             ProductSurfaceAdapter.run_projection(%{}, @run_ref, [])

    assert {:error, %SurfaceError{code: "invalid_product_capability_projection_request"}} =
             ProductSurfaceAdapter.capability_projections(context(), [], [])

    assert {:error,
            %SurfaceError{
              code: "invalid_product_projection_owner_response",
              kind: :validation,
              retryable: false
            }} =
             ProductSurfaceAdapter.capability_projections(
               context(),
               %{},
               product_projection_service: FakeOwner,
               capability_projection_result: {:ok, %{}},
               test_pid: self()
             )
  end

  defp context do
    {:ok, context} =
      RequestContext.new(%{
        trace_id: "11111111111111111111111111111111",
        actor_ref: %{id: "actor://synapse/operator", kind: :human},
        tenant_ref: %{id: @tenant_ref}
      })

    context
  end

  defp run_projection_attrs do
    %{
      run_ref: @run_ref,
      subject_ref: "subject://synapse/product-surface",
      workflow_ref: "workflow://synapse/product-surface",
      owner_projection_ref: "projection://mezzanine/run/product-surface",
      source_contract_ref: "contract://mezzanine/run-acceptance/v1",
      state: :running,
      updated_at: "2026-07-28T12:00:00Z",
      cursor: %{
        cursor_ref: "cursor://synapse/product-surface/4",
        ledger_ref: @run_ref,
        tenant_ref: @tenant_ref,
        actor_ref: "actor://synapse/operator",
        last_seq_seen: 4,
        visibility: :product
      },
      control: %{
        run_ref: @run_ref,
        owner_projection_ref: "projection://mezzanine/control/product-surface",
        source_contract_ref: "contract://mezzanine/recovery-control/v1",
        row_version: 2,
        state: :running,
        available_actions: [:pause, :cancel, :supersede],
        availability: :available
      },
      persistence_posture: PersistencePosture.durable(:runtime_projection),
      availability: :available
    }
  end

  defp capability_attrs(overrides) do
    Map.merge(
      %{
        capability_ref: "capability://model/default",
        owner_projection_ref: "projection://runtime/capability/default",
        source_contract_ref: "contract://runtime/capability/v1",
        producer_revision_ref: "revision://jido-integration/current",
        contract_version: "1",
        kind: :model,
        configured_mode: :local_effect,
        advertised?: false,
        health_ref: nil,
        operation_refs: [],
        scope_refs: [@tenant_ref],
        availability: {:unavailable, :not_configured}
      },
      overrides
    )
  end
end
