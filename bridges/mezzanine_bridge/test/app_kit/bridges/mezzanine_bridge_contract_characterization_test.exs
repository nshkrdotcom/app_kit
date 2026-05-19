defmodule AppKit.Bridges.MezzanineBridgeContractCharacterizationTest do
  use ExUnit.Case, async: true

  alias AppKit.Bridges.MezzanineBridge

  alias AppKit.Bridges.MezzanineBridge.{
    AgentIntakeAdapter,
    HeadlessAdapter,
    InstallationAdapter,
    ReviewAdapter,
    RuntimeAdapter,
    SourceAdapter,
    WorkAdapter,
    WorkQueryAdapter
  }

  alias AppKit.Core.AgentIntake.{RunOutcomeFuture, TurnSubmission}
  alias AppKit.Core.RuntimeReadback.{CommandResult, RuntimeStateSnapshot}

  alias AppKit.Core.{
    ActionResult,
    DecisionRef,
    InstallationBinding,
    InstallationRef,
    InstallTemplate,
    PageRequest,
    RequestContext,
    Result,
    RunRef,
    RunRequest,
    SubjectRef,
    SurfaceError
  }

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

  defmodule PartialSourceService do
    def sync_source(_context, source_role_ref, source_page, _opts),
      do: {:ok, %{role_ref: source_role_ref, source_page: source_page}}
  end

  defmodule WorkQueryService do
    def ingest_subject(attrs, opts) do
      send(self(), {:work_query_service_called, :ingest_subject, attrs, opts})

      {:ok, %{subject_id: "subject-1", subject_kind: "work_object"}}
    end

    def list_subjects(tenant_id, program_id, filters) do
      send(self(), {:work_query_service_called, :list_subjects, tenant_id, program_id, filters})

      {:ok,
       [
         %{
           subject_id: "subject-1",
           subject_kind: "work_object",
           status: "planned",
           title: "Subject one",
           description: "A test subject"
         }
       ]}
    end

    def queue_stats(tenant_id, program_id) do
      send(self(), {:work_query_service_called, :queue_stats, tenant_id, program_id})
      {:ok, %{queued: 1}}
    end
  end

  defmodule WorkControlService do
    def start_run(context, run_request, opts) do
      send(
        self(),
        {:work_control_service_called, :start_run, context.tenant_ref.id, run_request, opts}
      )

      Result.new(%{
        surface: :work_control,
        state: :scheduled,
        payload: %{subject_ref: run_request.subject_ref}
      })
    end

    def retry_run(context, run_ref, opts) do
      send(
        self(),
        {:work_control_service_called, :retry_run, context.tenant_ref.id, run_ref, opts}
      )

      ActionResult.new(%{status: :accepted, message: "retry accepted"})
    end

    def cancel_run(context, run_ref, opts) do
      send(
        self(),
        {:work_control_service_called, :cancel_run, context.tenant_ref.id, run_ref, opts}
      )

      ActionResult.new(%{status: :accepted, message: "cancel accepted"})
    end

    def start_run(domain_call, opts) do
      send(self(), {:work_control_service_called, :domain_start_run, domain_call, opts})
      {:ok, %{domain_call: domain_call, opts: opts}}
    end
  end

  defmodule ReviewQueryService do
    def list_pending_reviews(tenant_id, program_id) do
      send(self(), {:review_query_service_called, :list_pending_reviews, tenant_id, program_id})

      {:ok,
       [
         %{
           decision_ref: %{
             id: "decision-1",
             decision_kind: "approval",
             subject_ref: %{id: "subject-1", subject_kind: "work_object"}
           },
           status: "pending",
           summary: "Needs operator approval"
         }
       ]}
    end

    def get_review_detail(tenant_id, decision_id) do
      send(self(), {:review_query_service_called, :get_review_detail, tenant_id, decision_id})
      {:ok, %{decision_id: decision_id, detail: true}}
    end
  end

  defmodule ReviewActionService do
    def record_decision(tenant_id, decision_id, attrs, opts) do
      send(
        self(),
        {:review_action_service_called, :record_decision, tenant_id, decision_id, attrs, opts}
      )

      {:ok, %{status: :accepted, message: "decision recorded"}}
    end
  end

  defmodule InstallationService do
    def create_installation(attrs, opts) do
      send(self(), {:installation_service_called, :create_installation, attrs, opts})
      {:ok, install_result("installation-1", :created, "created")}
    end

    def import_authoring_bundle(attrs, opts) do
      send(self(), {:installation_service_called, :import_authoring_bundle, attrs, opts})
      {:ok, install_result("installation-1", :updated, "imported")}
    end

    def get_installation(installation_id, opts) do
      send(self(), {:installation_service_called, :get_installation, installation_id, opts})
      {:ok, %{installation_ref: installation_ref(installation_id, :active)}}
    end

    def update_bindings(installation_id, binding_config, opts) do
      send(
        self(),
        {:installation_service_called, :update_bindings, installation_id, binding_config, opts}
      )

      {:ok, %{status: :accepted, message: "bindings updated"}}
    end

    def list_installations(tenant_id, filters, opts) do
      send(self(), {:installation_service_called, :list_installations, tenant_id, filters, opts})
      {:ok, [%{installation_ref: installation_ref("installation-1", :active)}]}
    end

    def suspend_installation(installation_id, opts) do
      send(self(), {:installation_service_called, :suspend_installation, installation_id, opts})
      {:ok, %{status: :accepted, message: "suspended"}}
    end

    def reactivate_installation(installation_id, opts) do
      send(
        self(),
        {:installation_service_called, :reactivate_installation, installation_id, opts}
      )

      {:ok, %{status: :accepted, message: "reactivated"}}
    end

    defp install_result(installation_id, status, message) do
      %{
        installation_ref: installation_ref(installation_id, :active),
        status: status,
        message: message
      }
    end

    defp installation_ref(installation_id, status) do
      %{
        id: installation_id,
        pack_slug: "sample-host",
        pack_version: "1.0.0",
        compiled_pack_revision: 1,
        status: status
      }
    end
  end

  defmodule RuntimeGatewayService do
    def invoke_runtime_operation(
          context,
          runtime_role_ref,
          operation_role_ref,
          spec_attrs,
          runtime_binding,
          opts
        ) do
      send(
        self(),
        {:runtime_gateway_service_called, :invoke_runtime_operation, context.tenant_ref.id,
         runtime_role_ref, operation_role_ref, spec_attrs, runtime_binding, opts}
      )

      {:ok,
       %{
         run_ref: "run://agent-1",
         workflow_ref: "workflow://agent-1",
         subject_ref: spec_attrs.subject_ref,
         status: "running"
       }}
    end

    def invoke_runtime_tool(context, tool_role_ref, operation_role_ref, request, opts) do
      send(
        self(),
        {:runtime_gateway_service_called, :invoke_runtime_tool, context.tenant_ref.id,
         tool_role_ref, operation_role_ref, request, opts}
      )

      {:ok, %{tool_role_ref: tool_role_ref, operation_role_ref: operation_role_ref}}
    end
  end

  defmodule RuntimeProfileService do
    def apply(tenant_id, runtime_profile) do
      send(self(), {:runtime_profile_service_called, :apply, tenant_id, runtime_profile})
      {:ok, %{status: :updated, profile_ref: runtime_profile.profile_ref}}
    end
  end

  defmodule OperatorQueryService do
    def system_health(tenant_id, program_id) do
      send(self(), {:operator_query_service_called, :system_health, tenant_id, program_id})
      {:ok, %{status: "ok", preflight: %{checks: []}}}
    end

    def timeline(tenant_id, subject_id) do
      send(self(), {:operator_query_service_called, :timeline, tenant_id, subject_id})
      {:ok, %{entries: [%{message: "started"}], total_count: 1}}
    end
  end

  defmodule HeadlessWorkQueryService do
    def list_subjects(tenant_id, program_id, filters) do
      send(
        self(),
        {:headless_work_query_service_called, :list_subjects, tenant_id, program_id, filters}
      )

      {:ok,
       [
         %{
           subject_id: "subject-1",
           status: "running",
           title: "Subject one",
           updated_at: DateTime.utc_now()
         }
       ]}
    end

    def get_subject_projection(tenant_id, subject_id, opts) do
      send(
        self(),
        {:headless_work_query_service_called, :get_subject_projection, tenant_id, subject_id,
         opts}
      )

      {:ok,
       %{
         projection_name: "operator_subject_runtime",
         computed_at: DateTime.utc_now(),
         subject_ref: subject_id,
         execution: %{dispatch_state: "running"},
         lower_receipt: %{run_id: "lower-run-1"},
         source_bindings: [%{id: "source-binding-1"}],
         runtime: %{
           token_totals: %{
             total_input_tokens: 1,
             total_output_tokens: 2,
             total_tokens: 3
           }
         }
       }}
    end
  end

  defmodule AgentRuntime do
    def run(_request), do: :ok
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

  test "source adapter owns source service delegation behind the facade" do
    context = request_context()
    request = %{marker: "source-adapter"}
    opts = [source_service: SourceService, sentinel: :source_adapter]

    assert {:ok, %{callback: :sync_source, role_ref: :source_role, request: ^request}} =
             SourceAdapter.sync_source(context, :source_role, request, opts)

    assert_received {:source_service_called, :sync_source, "tenant-1", :source_role, ^request,
                     ^opts}

    assert {:ok, %{callback: :publish_source, role_ref: :publication_role, request: ^request}} =
             SourceAdapter.publish_source(context, :publication_role, request, opts)

    assert_received {:source_service_called, :publish_source, "tenant-1", :publication_role,
                     ^request, ^opts}
  end

  test "source adapter normalizes missing optional service callbacks" do
    context = request_context()
    opts = [source_service: PartialSourceService]

    assert {:error,
            %SurfaceError{
              code: "source_current_state_not_configured",
              kind: :boundary,
              retryable: false
            }} = SourceAdapter.current_states(context, :source_role, %{}, opts)

    assert {:error,
            %SurfaceError{
              code: "source_candidate_fetch_not_configured",
              kind: :boundary,
              retryable: false
            }} = SourceAdapter.fetch_candidates(context, :source_role, %{}, opts)

    assert {:error,
            %SurfaceError{
              code: "source_publication_not_configured",
              kind: :boundary,
              retryable: false
            }} = SourceAdapter.publish_source(context, :publication_role, %{}, opts)
  end

  test "work query adapter owns work query service delegation behind the facade" do
    context = request_context()
    {:ok, page_request} = PageRequest.new(%{limit: 5})

    opts = [
      work_query_service: WorkQueryService,
      program_id: "program-1",
      work_class_id: "work-class-1"
    ]

    assert {:ok, %SubjectRef{id: "subject-1", subject_kind: "work_object"}} =
             WorkQueryAdapter.ingest_subject(context, %{title: "Subject one"}, opts)

    assert_received {:work_query_service_called, :ingest_subject, attrs, ^opts}
    assert attrs.tenant_id == "tenant-1"
    assert attrs.program_id == "program-1"
    assert attrs.work_class_id == "work-class-1"

    assert {:ok, %{entries: [%{subject_ref: %SubjectRef{id: "subject-1"}}]}} =
             MezzanineBridge.list_subjects(context, nil, page_request, opts)

    assert_received {:work_query_service_called, :list_subjects, "tenant-1", "program-1", %{}}

    assert {:ok, %{queued: 1, filters: %{}}} =
             WorkQueryAdapter.queue_stats(context, nil, opts)

    assert_received {:work_query_service_called, :queue_stats, "tenant-1", "program-1"}
  end

  test "work adapter owns work control service delegation behind the facade" do
    context = request_context()
    {:ok, subject_ref} = SubjectRef.new(%{id: "subject-1", subject_kind: "work_object"})
    {:ok, run_request} = RunRequest.new(%{subject_ref: subject_ref, reason: "test"})
    {:ok, run_ref} = RunRef.new(%{run_id: "run-1", scope_id: "scope-1"})
    opts = [work_control_service: WorkControlService]

    assert {:ok, %Result{surface: :work_control, state: :scheduled}} =
             MezzanineBridge.start_run(context, run_request, opts)

    assert_received {:work_control_service_called, :start_run, "tenant-1", ^run_request, ^opts}

    assert {:ok, %ActionResult{status: :accepted, message: "retry accepted"}} =
             WorkAdapter.retry_run(context, run_ref, opts)

    assert_received {:work_control_service_called, :retry_run, "tenant-1", ^run_ref, ^opts}

    assert {:ok, %{domain_call: %{kind: "domain"}, opts: ^opts}} =
             WorkAdapter.start_run(%{kind: "domain"}, opts)

    assert_received {:work_control_service_called, :domain_start_run, %{kind: "domain"}, ^opts}
  end

  test "review adapter owns review query and action service delegation behind the facade" do
    context = request_context()
    {:ok, page_request} = PageRequest.new(%{limit: 5})

    {:ok, subject_ref} = SubjectRef.new(%{id: "subject-1", subject_kind: "work_object"})

    {:ok, decision_ref} =
      DecisionRef.new(%{id: "decision-1", decision_kind: "approval", subject_ref: subject_ref})

    opts = [
      review_query_service: ReviewQueryService,
      review_action_service: ReviewActionService,
      program_id: "program-1"
    ]

    assert {:ok, %{entries: [%{decision_ref: %DecisionRef{id: "decision-1"}}]}} =
             ReviewAdapter.list_pending(context, page_request, opts)

    assert_received {:review_query_service_called, :list_pending_reviews, "tenant-1", "program-1"}

    assert {:ok, %{decision_id: "decision-1", detail: true}} =
             MezzanineBridge.get_review(context, decision_ref, opts)

    assert_received {:review_query_service_called, :get_review_detail, "tenant-1", "decision-1"}

    assert {:ok, %ActionResult{status: :accepted, message: "decision recorded"}} =
             MezzanineBridge.record_decision(context, decision_ref, %{decision: "approve"}, opts)

    assert_received {:review_action_service_called, :record_decision, "tenant-1", "decision-1",
                     attrs, ^opts}

    assert attrs.program_id == "program-1"
    assert attrs.actor_ref == "operator"
    assert attrs.decision == "approve"
  end

  test "installation adapter owns installation service delegation behind the facade" do
    context = request_context()
    {:ok, page_request} = PageRequest.new(%{limit: 5})

    {:ok, template} =
      InstallTemplate.new(%{
        template_key: "default",
        pack_slug: "sample-host",
        pack_version: "1.0.0"
      })

    {:ok, installation_ref} =
      InstallationRef.new(%{id: "installation-1", pack_slug: "sample-host"})

    {:ok, binding} =
      InstallationBinding.new(%{
        binding_key: "execution-default",
        binding_kind: :execution,
        config: %{recipe_ref: "recipe://default"}
      })

    opts = [installation_service: InstallationService]

    assert {:ok, %{installation_ref: %InstallationRef{id: "installation-1"}, status: :created}} =
             InstallationAdapter.create_installation(context, template, opts)

    assert_received {:installation_service_called, :create_installation, attrs, ^opts}
    assert attrs.tenant_id == "tenant-1"
    assert attrs.template_key == "default"

    assert {:ok, %ActionResult{status: :accepted, message: "bindings updated"}} =
             MezzanineBridge.update_bindings(context, installation_ref, [binding], opts)

    assert_received {:installation_service_called, :update_bindings, "installation-1",
                     binding_config, ^opts}

    assert binding_config["execution_bindings"]["execution-default"].recipe_ref ==
             "recipe://default"

    assert {:ok, %{entries: [%InstallationRef{id: "installation-1"}]}} =
             MezzanineBridge.list_installations(context, page_request, opts)

    assert_received {:installation_service_called, :list_installations, "tenant-1", %{}, ^opts}
  end

  test "runtime adapter owns runtime gateway and runtime surface delegation behind the facade" do
    context = request_context()

    opts = [
      runtime_gateway_service: RuntimeGatewayService,
      runtime_profile_service: RuntimeProfileService,
      operator_query_service: OperatorQueryService,
      runtime_binding: %{driver: "fixture"},
      program_id: "program-1"
    ]

    request = agent_run_request()

    assert {:ok, %RunOutcomeFuture{run_ref: "run://agent-1", workflow_ref: "workflow://agent-1"}} =
             MezzanineBridge.invoke_runtime_operation(
               context,
               :runtime_role,
               :operation_role,
               request,
               opts
             )

    assert_received {:runtime_gateway_service_called, :invoke_runtime_operation, "tenant-1",
                     :runtime_role, :operation_role, spec_attrs, %{driver: "fixture"}, ^opts}

    assert spec_attrs.subject_ref == "subject-1"
    assert spec_attrs.runtime_profile_ref == :runtime_default

    assert {:ok, %{status: :updated, tenant_ref: "tenant-1", profile_ref: "runtime://default"}} =
             RuntimeAdapter.apply_runtime_profile(
               context,
               %{profile_ref: "runtime://default"},
               opts
             )

    assert_received {:runtime_profile_service_called, :apply, "tenant-1",
                     %{profile_ref: "runtime://default"}}

    assert {:ok, %{tenant_ref: "tenant-1", program_ref: "program-1", health: %{"status" => "ok"}}} =
             MezzanineBridge.runtime_status(context, %{}, opts)

    assert_received {:operator_query_service_called, :system_health, "tenant-1", "program-1"}
  end

  test "headless adapter owns runtime readback delegation behind the facade" do
    context = request_context()
    opts = [work_query_service: HeadlessWorkQueryService, program_id: "program-1"]

    assert {:ok, %RuntimeStateSnapshot{tenant_ref: "tenant-1", rows: rows}} =
             HeadlessAdapter.state_snapshot(context, %{page_size: 10}, opts)

    assert [%{subject_ref: "subject://subject-1", state: "running"}] = rows

    assert_received {:headless_work_query_service_called, :list_subjects, "tenant-1", "program-1",
                     %{}}

    assert_received {:headless_work_query_service_called, :get_subject_projection, "tenant-1",
                     "subject-1", projection_opts}

    assert Keyword.fetch!(projection_opts, :runtime_projection?)
  end

  test "agent intake adapter owns agent command delegation behind the facade" do
    context = request_context()
    opts = [agent_loop_runtime: AgentRuntime]

    {:ok, turn_submission} =
      TurnSubmission.new(%{
        idempotency_key: "turn-1",
        actor_ref: "actor-1",
        run_ref: "run://agent-1",
        kind: :user_input,
        payload_ref: "payload://turn-1"
      })

    assert {:ok, %CommandResult{command_kind: :submit_turn, correlation_id: "run://agent-1"}} =
             AgentIntakeAdapter.submit_agent_turn(context, turn_submission, opts)

    assert {:ok, %CommandResult{command_kind: :cancel, correlation_id: "run://agent-1"}} =
             MezzanineBridge.cancel_agent_run(context, "run://agent-1", opts)
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

  defp agent_run_request do
    %{
      tenant_ref: "tenant-1",
      installation_ref: "installation-1",
      subject_ref: "subject-1",
      actor_ref: "actor-1",
      profile_bundle: %{
        source_profile_ref: :source_default,
        runtime_profile_ref: :runtime_default,
        tool_scope_ref: :tool_default,
        evidence_profile_ref: :evidence_default,
        publication_profile_ref: :publication_default,
        review_profile_ref: :review_default,
        memory_profile_ref: :none,
        projection_profile_ref: :projection_default
      },
      tool_catalog_ref: "tool-catalog-1",
      budget_ref: "budget-1",
      recall_scope_ref: "recall-1",
      idempotency_key: "agent-run-1",
      trace_id: "trace-1",
      correlation_id: "correlation-1",
      submission_dedupe_key: "submission-1",
      initial_input_ref: "input-1",
      params: %{}
    }
  end
end
