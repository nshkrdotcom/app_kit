defmodule AppKit.Bridges.MezzanineBridgeContractCharacterizationTest do
  use ExUnit.Case, async: true

  alias AppKit.Bridges.MezzanineBridge
  alias AppKit.Core.RequestContext

  @adapter_contract [
    %{
      behaviour: AppKit.Core.Backends.InstallationBackend,
      target_module: "AppKit.Bridges.MezzanineBridge.InstallationAdapter",
      service_options: [:installation_service],
      callbacks: [
        create_installation: 3,
        import_authoring_bundle: 3,
        get_installation: 3,
        update_bindings: 4,
        list_installations: 3,
        suspend_installation: 3,
        reactivate_installation: 3
      ]
    },
    %{
      behaviour: AppKit.Core.Backends.SourceBackend,
      target_module: "AppKit.Bridges.MezzanineBridge.SourceAdapter",
      service_options: [:source_service],
      callbacks: [
        sync_source: 4,
        current_states: 4,
        fetch_candidates: 4,
        publish_source: 4
      ]
    },
    %{
      behaviour: AppKit.Core.Backends.WorkBackend,
      target_module: "AppKit.Bridges.MezzanineBridge.WorkAdapter",
      service_options: [:work_control_service],
      callbacks: [
        start_run: 2,
        start_run: 3,
        retry_run: 3,
        cancel_run: 3
      ]
    },
    %{
      behaviour: AppKit.Core.Backends.WorkQueryBackend,
      target_module: "AppKit.Bridges.MezzanineBridge.WorkQueryAdapter",
      service_options: [:work_query_service],
      callbacks: [
        ingest_subject: 3,
        list_subjects: 4,
        get_subject: 3,
        get_projection: 3,
        get_runtime_projection: 3,
        queue_stats: 3
      ]
    },
    %{
      behaviour: AppKit.Core.Backends.ReviewBackend,
      target_module: "AppKit.Bridges.MezzanineBridge.ReviewAdapter",
      service_options: [:review_query_service, :review_action_service, :program_context_service],
      callbacks: [
        list_pending: 3,
        get_review: 3,
        record_decision: 4,
        record_decision_by_id: 4
      ]
    },
    %{
      behaviour: AppKit.Core.Backends.OperatorBackend,
      target_module: "AppKit.Bridges.MezzanineBridge.OperatorAdapter",
      service_options: [
        :operator_query_service,
        :operator_action_service,
        :lease_service,
        :memory_control_service
      ],
      callbacks: [
        subject_status: 3,
        timeline: 3,
        get_unified_trace: 3,
        issue_read_lease: 3,
        issue_stream_attach_lease: 3,
        available_actions: 3,
        apply_action: 4,
        list_memory_fragments: 3,
        memory_fragment_by_proof_token: 3,
        memory_fragment_provenance: 3,
        request_memory_share_up: 3,
        request_memory_promotion: 3,
        request_memory_invalidation: 3,
        run_status: 3,
        review_run: 3
      ]
    },
    %{
      behaviour: AppKit.Core.Backends.RuntimeBackend,
      target_module: "AppKit.Bridges.MezzanineBridge.RuntimeAdapter",
      service_options: [
        :runtime_profile_service,
        :operator_query_service,
        :runtime_gateway_service
      ],
      callbacks: [
        invoke_runtime_operation: 5,
        invoke_runtime_tool: 5,
        apply_runtime_profile: 3,
        runtime_status: 3,
        runtime_logs: 3,
        record_live_effect: 3,
        collect_evidence: 4,
        invoke_resource_effect: 4
      ]
    },
    %{
      behaviour: AppKit.Core.Backends.HeadlessBackend,
      target_module: "AppKit.Bridges.MezzanineBridge.HeadlessAdapter",
      service_options: [:work_query_service],
      callbacks: [
        state_snapshot: 3,
        runtime_subject_detail: 4,
        runtime_run_detail: 4,
        request_runtime_refresh: 3,
        request_runtime_control: 3
      ]
    },
    %{
      behaviour: AppKit.Core.Backends.AgentIntakeBackend,
      target_module: "AppKit.Bridges.MezzanineBridge.AgentIntakeAdapter",
      service_options: [:agent_loop_runtime, :runtime_adapter],
      callbacks: [
        start_agent_run: 3,
        submit_agent_turn: 3,
        cancel_agent_run: 3,
        await_agent_outcome: 4
      ]
    }
  ]

  defmodule SourceService do
    def sync_source(context, source_role_ref, source_page, opts) do
      record(:sync_source, context, source_role_ref, source_page, opts)
    end

    def current_states(context, source_role_ref, request, opts) do
      record(:current_states, context, source_role_ref, request, opts)
    end

    def fetch_candidates(context, source_role_ref, request, opts) do
      record(:fetch_candidates, context, source_role_ref, request, opts)
    end

    def publish_source(context, source_role_ref, request, opts) do
      record(:publish_source, context, source_role_ref, request, opts)
    end

    defp record(callback, context, role_ref, request, opts) do
      send(
        self(),
        {:source_service_called, callback, context.tenant_ref.id, role_ref, request, opts}
      )

      {:ok, %{callback: callback, role_ref: role_ref, request: request}}
    end
  end

  test "documents the extraction contract for every current bridge behaviour" do
    declared_behaviours =
      MezzanineBridge.module_info(:attributes)
      |> Keyword.get_values(:behaviour)
      |> List.flatten()
      |> MapSet.new()

    expected_behaviours =
      @adapter_contract
      |> Enum.map(& &1.behaviour)
      |> MapSet.new()

    assert declared_behaviours == expected_behaviours

    assert Enum.map(@adapter_contract, & &1.target_module) == [
             "AppKit.Bridges.MezzanineBridge.InstallationAdapter",
             "AppKit.Bridges.MezzanineBridge.SourceAdapter",
             "AppKit.Bridges.MezzanineBridge.WorkAdapter",
             "AppKit.Bridges.MezzanineBridge.WorkQueryAdapter",
             "AppKit.Bridges.MezzanineBridge.ReviewAdapter",
             "AppKit.Bridges.MezzanineBridge.OperatorAdapter",
             "AppKit.Bridges.MezzanineBridge.RuntimeAdapter",
             "AppKit.Bridges.MezzanineBridge.HeadlessAdapter",
             "AppKit.Bridges.MezzanineBridge.AgentIntakeAdapter"
           ]

    for adapter <- @adapter_contract, {callback, arity} <- adapter.callbacks do
      assert function_exported?(MezzanineBridge, callback, arity),
             "#{adapter.target_module} must preserve #{callback}/#{arity}"
    end
  end

  test "characterizes source facade delegation through the injected lower service" do
    context = request_context()

    for callback <- [:sync_source, :current_states, :fetch_candidates, :publish_source] do
      request = %{callback: callback, marker: "source-contract"}
      opts = [source_service: SourceService, sentinel: callback]

      assert {:ok, %{callback: ^callback, role_ref: :source_role, request: ^request}} =
               apply(MezzanineBridge, callback, [context, :source_role, request, opts])

      assert_received {:source_service_called, ^callback, "tenant-1", :source_role, ^request,
                       ^opts}
    end
  end

  defp request_context do
    {:ok, context} =
      RequestContext.new(%{
        trace_id: "11111111111111111111111111111111",
        actor_ref: %{id: "operator", kind: :human},
        tenant_ref: %{id: "tenant-1"},
        installation_ref: %{id: "installation-1", pack_slug: "sample-host"}
      })

    context
  end
end
