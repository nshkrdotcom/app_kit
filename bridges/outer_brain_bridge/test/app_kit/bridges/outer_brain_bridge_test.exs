defmodule AppKit.Bridges.OuterBrainBridgeTest do
  use ExUnit.Case, async: false

  alias AppKit.Bridges.OuterBrainBridge
  alias AppKit.Core.{Telemetry, TraceIdentity}
  alias AppKit.ScopeObjects
  alias Citadel.DomainSurface.Adapters.CitadelAdapter.Accepted

  defmodule TelemetryForwarder do
    def handle_event(event, measurements, metadata, test_pid) do
      send(test_pid, {:telemetry, event, measurements, metadata})
    end
  end

  defmodule FakeKernelRuntime do
    @moduledoc false

    def dispatch_command(command, _opts) do
      {:ok,
       Accepted.new!(%{
         request_id: command.idempotency_key,
         session_id: command.context[:session_id],
         trace_id: command.trace_id,
         ingress_path: :direct_intent_envelope,
         lifecycle_event: :live_owner,
         continuity_revision: 1
       })}
    end
  end

  defmodule SemanticFailureRuntime do
    @moduledoc false

    def submit_turn(_text, _opts) do
      {:semantic_failure,
       %{
         kind: :semantic_insufficient_context,
         provenance: [%{"surface" => "outer_brain.test_runtime"}],
         operator_message: "Need the workspace target before dispatch."
       }}
    end
  end

  defmodule MemoryContextAdapter do
    @moduledoc false

    @behaviour OuterBrain.Prompting.ContextAdapter

    @impl true
    def fetch_fragments(request, runtime_binding) do
      send(runtime_binding["test_pid"], {:context_pack_request, request, runtime_binding})

      {:ok,
       [
         %{
           fragment_id: "fragment-memory-1",
           content: %{"summary" => "prior bounded implementation note"},
           provenance: %{"memory_ref" => "memory://workspace/main/1"},
           staleness: %{"class" => "fresh"},
           metadata: %{
             "memory_evidence_ref" => "memory-evidence://workspace/main/1",
             "rank" => 1
           }
         }
       ]}
    end
  end

  test "submits a semantic turn through the outer_brain seam" do
    attach_telemetry(self(), [:trace_minted])

    assert {:ok, scope} =
             ScopeObjects.host_scope(%{
               scope_id: "workspace/main",
               session_id: "sess-outer-brain-bridge",
               tenant_id: "tenant-1",
               actor_id: "user-1",
               environment: "dev",
               metadata: %{workspace_root: "/workspace/main"}
             })

    assert {:ok, turn} =
             OuterBrainBridge.submit_turn(
               scope,
               "compile the workspace",
               idempotency_key: "turn-outer-brain-1",
               domain_module: Citadel.DomainSurface.Examples.ProvingGround,
               route_sources: [
                 Citadel.DomainSurface.Examples.ProvingGround.Routes.CompileWorkspace
               ],
               kernel_runtime: {FakeKernelRuntime, []}
             )

    assert turn.action_request.route == "compile_workspace"
    assert turn.dispatch_result.request_id == "turn-outer-brain-1"
    assert TraceIdentity.valid?(turn.dispatch_result.trace_id)

    assert_event(
      :trace_minted,
      %{count: 1},
      %{
        trace_id: turn.dispatch_result.trace_id,
        tenant_id: "tenant-1",
        source: :request_edge,
        surface: :outer_brain_bridge
      }
    )
  end

  test "preserves provider-neutral semantic failure carrier fields across the AppKit bridge" do
    assert {:ok, scope} =
             ScopeObjects.host_scope(%{
               scope_id: "workspace/main",
               session_id: "sess-outer-brain-semantic-failure",
               tenant_id: "tenant-1",
               actor_id: "user-1",
               environment: "dev",
               metadata: %{workspace_root: "/workspace/main"}
             })

    assert {:error, {:semantic_failure, carrier}} =
             OuterBrainBridge.submit_turn(
               scope,
               "compile it",
               idempotency_key: "turn-outer-brain-semantic-failure",
               domain_module: Citadel.DomainSurface.Examples.ProvingGround,
               route_sources: [
                 Citadel.DomainSurface.Examples.ProvingGround.Routes.CompileWorkspace
               ],
               semantic_runtime: SemanticFailureRuntime
             )

    assert carrier.kind == :semantic_insufficient_context
    assert carrier.retry_class == :clarification_required
    assert carrier.tenant_id == "tenant-1"
    assert carrier.semantic_session_id == "sess-outer-brain-semantic-failure"
    assert carrier.causal_unit_id == "turn-outer-brain-semantic-failure"
    assert TraceIdentity.valid?(carrier.request_trace_id)
    assert carrier.provenance == [%{"surface" => "outer_brain.test_runtime"}]
    assert carrier.operator_message == "Need the workspace target before dispatch."
  end

  test "builds an OuterBrain context pack from memory DTO refs without raw memory bodies" do
    assert {:ok, scope} =
             ScopeObjects.host_scope(%{
               scope_id: "workspace/main",
               session_id: "sess-context-pack",
               tenant_id: "tenant-1",
               actor_id: "user-1",
               environment: "dev",
               metadata: %{workspace_root: "/workspace/main"}
             })

    assert {:ok, pack} =
             OuterBrainBridge.build_context_pack(
               scope,
               %{
                 objective: "repair the governed slice",
                 refs: ["run://extravaganza/1"],
                 memory_query: %{
                   request_ref: "memory-query://extravaganza/run/1",
                   intent: memory_query_intent()
                 },
                 context_sources: [
                   %{
                     source_ref: "workspace_memory",
                     binding_key: "shared_memory",
                     usage_phase: :retrieval,
                     required?: false,
                     schema_ref: "context/workspace_memory",
                     max_fragments: 1
                   }
                 ],
                 context_bindings: %{
                   "shared_memory" => %{
                     "adapter_key" => "memory_context",
                     "test_pid" => self(),
                     "config" => %{"workspace" => "main"}
                   }
                 }
               },
               trace_id: "0123456789abcdef0123456789abcdef",
               trace_trust: true,
               adapter_registry: %{"memory_context" => MemoryContextAdapter}
             )

    assert_received {:context_pack_request, request, binding}
    assert request.trace_id == "0123456789abcdef0123456789abcdef"
    assert binding["adapter_key"] == "memory_context"

    assert pack.context_pack_ref =~ "context-pack://app-kit/"
    assert pack.context_hash =~ "sha256:"
    assert pack.memory_query_ref == "memory-query://extravaganza/run/1"
    assert pack.memory_budget_ref == "budget://a"
    assert pack.redaction_policy_ref == "policy://hash"
    assert pack.fragment_refs == ["fragment-memory-1"]
    assert pack.memory_evidence_refs == ["memory-evidence://workspace/main/1"]
    refute String.contains?(inspect(pack), "raw memory body")
  end

  test "context pack bridge rejects raw memory bodies at the AppKit DTO boundary" do
    assert {:ok, scope} =
             ScopeObjects.host_scope(%{
               scope_id: "workspace/main",
               session_id: "sess-context-pack-raw",
               tenant_id: "tenant-1",
               actor_id: "user-1",
               environment: "dev",
               metadata: %{}
             })

    assert {:error, {:raw_memory_surface_payload_forbidden, :body}} =
             OuterBrainBridge.build_context_pack(scope, %{
               objective: "bad raw memory",
               memory_query: %{
                 request_ref: "memory-query://raw",
                 intent: memory_query_intent(),
                 body: "raw memory body"
               }
             })
  end

  defp attach_telemetry(test_pid, event_keys) do
    handler_id = "outer-brain-bridge-test-#{System.unique_integer([:positive])}"

    :telemetry.attach_many(
      handler_id,
      Enum.map(event_keys, &Telemetry.event_name/1),
      &TelemetryForwarder.handle_event/4,
      test_pid
    )

    on_exit(fn -> :telemetry.detach(handler_id) end)
  end

  defp assert_event(event_key, measurements, metadata) do
    event_name = Telemetry.event_name(event_key)
    assert_receive {:telemetry, ^event_name, ^measurements, ^metadata}
    assert_contract_shape(event_key, measurements, metadata)
  end

  defp assert_contract_shape(event_key, measurements, metadata) do
    assert Enum.sort(Map.keys(measurements)) ==
             event_key |> Telemetry.measurement_keys() |> Enum.sort()

    assert Enum.sort(Map.keys(metadata)) ==
             event_key |> Telemetry.metadata_keys() |> Enum.sort()
  end

  defp memory_query_intent do
    %{
      tenant_ref: "tenant://a",
      authority_ref: "authority://a",
      installation_ref: "installation://a",
      idempotency_key: "idem-query",
      trace_ref: "trace://a",
      scope_key: %{
        tenant_ref: "tenant://a",
        installation_ref: "installation://a",
        subject_ref: "subject://a",
        run_ref: "run://a"
      },
      query_class: "semantic",
      query_text_hash: "sha256:query",
      query_redacted_excerpt: "bounded query",
      redaction_policy: %{level: :hash_only, redaction_policy_ref: "policy://hash"},
      max_results: 3,
      budget_ref: %{
        budget_ref: "budget://a",
        tenant_ref: "tenant://a",
        authority_ref: "authority://a",
        installation_ref: "installation://a",
        trace_ref: "trace://a"
      }
    }
  end
end
