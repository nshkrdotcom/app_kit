defmodule AppKit.ProductSurfaceTest do
  use ExUnit.Case, async: true

  alias AppKit.BackendStack
  alias AppKit.Core.PersistencePosture
  alias AppKit.Core.ProductSurface.{CapabilityProjection, RunProjection}

  defmodule Backend do
    @behaviour AppKit.Core.Backends.ProductSurfaceBackend

    @impl true
    def run_projection(_context, run_ref, _opts) do
      {:ok,
       %{
         run_ref: run_ref,
         subject_ref: "subject://synapse/product-surface",
         workflow_ref: "workflow://synapse/product-surface",
         owner_projection_ref: "projection://mezzanine/run/product-surface",
         source_contract_ref: "contract://mezzanine/run-acceptance/v1",
         state: :running,
         updated_at: "2026-07-28T12:00:00Z",
         cursor: %{
           cursor_ref: "cursor://synapse/product-surface/4",
           ledger_ref: run_ref,
           tenant_ref: "tenant://default",
           actor_ref: "actor://synapse/operator",
           last_seq_seen: 4,
           visibility: :product
         },
         control: %{
           run_ref: run_ref,
           owner_projection_ref: "projection://mezzanine/control/product-surface",
           source_contract_ref: "contract://mezzanine/recovery-control/v1",
           row_version: 2,
           state: :running,
           available_actions: [:pause, :cancel, :supersede],
           availability: :available
         },
         persistence_posture: PersistencePosture.durable(:runtime_projection),
         availability: :available
       }}
    end

    @impl true
    def capability_projections(_context, _request, _opts) do
      {:ok,
       [
         %{
           capability_ref: "capability://model/gemini-completion",
           owner_projection_ref: "projection://runtime/capability/gemini-completion",
           source_contract_ref: "contract://runtime/capability/v1",
           producer_revision_ref: "revision://jido-integration/current",
           contract_version: "1",
           kind: :model,
           configured_mode: :local_effect,
           advertised?: true,
           health_ref: "health://model/gemini-completion/ready",
           operation_refs: ["operation-class://model/completion"],
           scope_refs: ["scope://tenant/default"],
           availability: :available
         },
         %{
           capability_ref: "capability://execution/runtime-http",
           owner_projection_ref: "projection://runtime/capability/runtime-http",
           source_contract_ref: "contract://runtime/capability/v1",
           producer_revision_ref: "revision://execution-plane/current",
           contract_version: "1",
           kind: :execution_lane,
           configured_mode: :runtime_admitted,
           advertised?: false,
           operation_refs: [],
           scope_refs: [],
           availability: {:unavailable, :not_admitted}
         }
       ]}
    end
  end

  defmodule InvalidBackend do
    @behaviour AppKit.Core.Backends.ProductSurfaceBackend

    @impl true
    def run_projection(_context, _run_ref, _opts), do: {:ok, %{state: :completed}}

    @impl true
    def capability_projections(_context, _request, _opts) do
      {:ok,
       [
         %{
           capability_ref: "capability://model/static-success",
           owner_projection_ref: "projection://runtime/capability/static-success",
           source_contract_ref: "contract://runtime/capability/v1",
           producer_revision_ref: "revision://runtime/current",
           contract_version: "1",
           kind: :model,
           configured_mode: :local_effect,
           advertised?: true,
           operation_refs: [],
           scope_refs: [],
           availability: :available
         }
       ]}
    end
  end

  test "revalidates a durable composite run returned by the configured backend" do
    stack = BackendStack.new!(product_surface_backend: Backend)

    assert {:ok, %RunProjection{state: :running}} =
             AppKit.ProductSurface.run_projection(
               %{},
               "run://synapse/product-surface",
               backend_stack: stack
             )

    assert {:error, :invalid_product_run_projection} =
             AppKit.ProductSurface.run_projection(
               %{},
               "run://synapse/product-surface",
               backend: InvalidBackend
             )
  end

  test "advertises only executable available capability projections" do
    assert {:ok, [%CapabilityProjection{advertised?: true}]} =
             AppKit.ProductSurface.advertised_capabilities(%{}, %{}, backend: Backend)

    assert {:error, :invalid_product_capability_projection} =
             AppKit.ProductSurface.capabilities(%{}, %{}, backend: InvalidBackend)
  end
end
