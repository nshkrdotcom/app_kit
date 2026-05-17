defmodule Mezzanine.AppKitBridge.WorkServicesTest do
  use ExUnit.Case, async: false

  alias AppKit.Core.{PageRequest, RequestContext, RunRef, RunRequest, TraceIdentity}
  alias Ecto.Adapters.SQL.Sandbox

  alias Mezzanine.Archival.ArchivalManifest
  alias Mezzanine.Archival.Repo, as: ArchivalRepo
  alias Mezzanine.Execution.Repo, as: ExecutionRepo
  alias Mezzanine.IntegrationBridge.AuthorizedInvocation

  alias Mezzanine.AppKitBridge.{
    ProgramContextService,
    ReviewQueryService,
    SourceService,
    WorkControlService,
    WorkQueryService
  }

  alias Mezzanine.OpsDomain.Repo, as: OpsRepo
  alias Mezzanine.Programs.{PolicyBundle, Program}
  alias Mezzanine.Work.{WorkClass, WorkObject}

  defmodule CurrentStateBridge do
    def source_read_allowed_operations(_source_role_ref, _source_binding, _opts),
      do: ["linear.users.get_self", "linear.issues.list"]

    def fetch_source_current_states(invocation, source_role_ref, issue_ids, source_binding, opts) do
      send(
        self(),
        {:current_state_requested, invocation, source_role_ref, issue_ids, source_binding, opts}
      )

      {:ok,
       %{
         source_role_ref: source_role_ref,
         source_current_state: %{
           operation: "linear.issues.list",
           subject_attrs: [%{provider_external_ref: "lin-issue-321"}],
           missing_issue_ids: ["lin-missing"]
         }
       }}
    end
  end

  defmodule CredentialIngressBridge do
    def source_read_allowed_operations(_source_role_ref, _source_binding, _opts),
      do: ["linear.users.get_self", "linear.issues.list"]

    def prepare_linear_api_key_invocation(api_key, attrs, opts \\ []) do
      send(self(), {:prepare_linear_api_key_invocation, api_key, attrs, opts})

      {:ok,
       %{
         authorized_invocation:
           Process.get(:credential_ingress_invocation) ||
             raise("credential ingress invocation missing"),
         connection_id: "connection-linear-live",
         credential_ref_id: "cred:connection-linear-live",
         source_opts: [
           invoke_opts: [connection_id: "connection-linear-live"],
           credential_ref_id: "cred:connection-linear-live",
           credential_redeemed?: true
         ]
       }}
    end

    def fetch_source_candidates(invocation, source_role_ref, source_binding, opts) do
      send(self(), {:fetch_source_candidates, invocation, source_role_ref, source_binding, opts})

      {:ok,
       %{
         source_role_ref: source_role_ref,
         source_binding_id: source_binding.source_binding_id,
         credential_redeemed?: Keyword.get(opts, :credential_redeemed?),
         provider_request_sent?: true,
         provider_response_received?: true,
         source_intake: %{
           operation: "linear.issues.list",
           subject_attrs: [%{source_ref: "linear://inst/issue/ENG-321"}]
         }
       }}
    end

    def fetch_source_current_states(invocation, source_role_ref, issue_ids, source_binding, opts) do
      send(
        self(),
        {:fetch_source_current_states, invocation, source_role_ref, issue_ids, source_binding,
         opts}
      )

      {:ok,
       %{
         source_role_ref: source_role_ref,
         credential_redeemed?: Keyword.get(opts, :credential_redeemed?),
         provider_request_sent?: true,
         provider_response_received?: true,
         source_current_state: %{
           operation: "linear.issues.list",
           subject_attrs: [%{provider_external_ref: "lin-issue-321"}],
           missing_issue_ids: []
         }
       }}
    end
  end

  defmodule ExistingConnectionBridge do
    def source_read_allowed_operations(_source_role_ref, _source_binding, _opts),
      do: ["linear.users.get_self", "linear.issues.list"]

    def prepare_linear_connection_invocation(connection_id, attrs, opts \\ []) do
      send(self(), {:prepare_linear_connection_invocation, connection_id, attrs, opts})

      {:ok,
       %{
         authorized_invocation:
           Process.get(:connection_ingress_invocation) ||
             raise("connection ingress invocation missing"),
         connection_id: connection_id,
         credential_ref_id: Keyword.get(opts, :credential_ref_id),
         source_opts: [
           invoke_opts: [connection_id: connection_id],
           credential_ref_id: Keyword.get(opts, :credential_ref_id),
           credential_lease_ref: Keyword.get(opts, :credential_lease_ref),
           credential_redeemed?: true
         ]
       }}
    end

    def fetch_source_candidates(invocation, source_role_ref, source_binding, opts) do
      send(self(), {:fetch_source_candidates, invocation, source_role_ref, source_binding, opts})

      {:ok,
       %{
         source_role_ref: source_role_ref,
         source_binding_id: source_binding.source_binding_id,
         credential_redeemed?: Keyword.get(opts, :credential_redeemed?),
         provider_request_sent?: true,
         provider_response_received?: true,
         source_intake: %{
           operation: "linear.issues.list",
           subject_attrs: [%{source_ref: "linear://inst/issue/ENG-321"}]
         }
       }}
    end
  end

  defmodule StateUpdateBridge do
    def update_linear_issue_state(invocation, attrs, opts) do
      send(self(), {:update_linear_issue_state, invocation, attrs, opts})

      {:ok,
       %{
         source_publication_receipt: %{
           source_publication_receipt_ref: "source-publication://linear-primary/state-update",
           source_publish_ref: attrs.source_publish_ref,
           source_binding_id: attrs.source_binding_id,
           source_ref: attrs.source_ref,
           status: "published",
           capability_id: "linear.issues.update",
           issue_id: attrs.issue_id,
           state_name: attrs.state_name,
           state_id: "state-done",
           lower_request_ref: "lower-request://linear/state-update",
           lower_receipt_ref: "lower-receipt://linear/state-update"
         },
         provider_request_sent?: true,
         provider_response_received?: true
       }}
    end

    def publish_linear_source(_invocation, _attrs, _opts) do
      raise "state-update publication must use update_linear_issue_state"
    end
  end

  defmodule DryRunPublicationBridge do
    def publish_linear_source(invocation, attrs, opts) do
      send(self(), {:dry_run_publish_linear_source, invocation, attrs, opts})

      {:ok,
       %{
         source_publication_receipt: %{
           source_publication_receipt_ref: "source-publication://linear-primary/dry-run-denial",
           source_publish_ref: attrs.source_publish_ref,
           source_binding_id: attrs.source_binding_id,
           source_ref: attrs.source_ref,
           status: "dry_run_denied",
           capability_id: "linear.comments.create",
           issue_id: attrs.issue_id,
           lower_request_ref: "lower-request://linear/publication-dry-run",
           lower_denial_ref: "lower-denial://linear/publication-dry-run/policy_denied",
           denial_class: "policy_denied",
           provider_request_sent?: false,
           provider_response_received?: false,
           workpad_refs: []
         },
         lower_denial_ref: "lower-denial://linear/publication-dry-run/policy_denied",
         provider_request_sent?: false,
         provider_response_received?: false,
         credential_redeemed?: Keyword.get(opts, :credential_redeemed?)
       }}
    end

    def update_linear_issue_state(_invocation, _attrs, _opts) do
      raise "comment dry-run publication must use publish_linear_source"
    end
  end

  defmodule LinearGraphQLToolBridge do
    def execute_linear_graphql_tool(invocation, attrs, opts) do
      send(self(), {:linear_graphql_tool, invocation, attrs, opts})

      {:ok,
       %{
         operation: "linear.graphql.execute",
         tool_name: "linear_graphql",
         success?: true,
         dynamic_tool_response: %{
           "success" => true,
           "output" => ~s({"data":{"viewer":{"id":"usr-linear-viewer"}}}),
           "contentItems" => [
             %{
               "type" => "inputText",
               "text" => ~s({"data":{"viewer":{"id":"usr-linear-viewer"}}})
             }
           ]
         },
         lower_request_ref: "lower-request://linear/graphql",
         lower_receipt_ref: "lower-receipt://linear/graphql/succeeded",
         provider_request_sent?: true,
         provider_response_received?: true,
         credential_redeemed?: Keyword.get(opts, :credential_redeemed?)
       }}
    end
  end

  setup do
    ops_owner = Sandbox.start_owner!(OpsRepo, shared: false)
    archival_owner = Sandbox.start_owner!(ArchivalRepo, shared: false)

    on_exit(fn ->
      Sandbox.stop_owner(archival_owner)
      Sandbox.stop_owner(ops_owner)
    end)

    :ok
  end

  test "work query service exposes adapter-shaped subject reads without relying on the deprecated work surface" do
    %{tenant_id: tenant_id, program: program, work_class: work_class} =
      fixture_stack("tenant-bridge-work")

    assert {:ok, first_subject} =
             WorkQueryService.ingest_subject(%{
               tenant_id: tenant_id,
               program_id: program.id,
               work_class_id: work_class.id,
               external_ref: "linear:ENG-401",
               title: "Bridge work item",
               payload: %{"issue_id" => "ENG-401"},
               source_kind: "linear"
             })

    assert {:ok, second_subject} =
             WorkQueryService.ingest_subject(%{
               tenant_id: tenant_id,
               program_id: program.id,
               work_class_id: work_class.id,
               external_ref: "linear:ENG-401",
               title: "Bridge work item updated",
               payload: %{"issue_id" => "ENG-401", "state" => "updated"},
               source_kind: "linear"
             })

    assert first_subject.subject_id == second_subject.subject_id
    assert second_subject.title == "Bridge work item updated"
    assert second_subject.subject_kind == :work_object
    assert second_subject.program_id == program.id

    assert {:ok, subjects} = WorkQueryService.list_subjects(tenant_id, program.id, %{})
    assert Enum.any?(subjects, &(&1.subject_id == second_subject.subject_id))

    assert {:ok, detail} =
             WorkQueryService.get_subject_detail(tenant_id, second_subject.subject_id)

    assert detail.subject_id == second_subject.subject_id
    assert detail.subject_kind == :work_object
    assert detail.title == "Bridge work item updated"
    assert is_map(detail.gate_status)
    assert is_list(detail.pending_review_ids)

    assert [%{obligation_id: obligation_id, obligation_kind: "review", status: "pending"}] =
             detail.pending_obligations

    assert String.starts_with?(obligation_id, "obligation:review:")
    assert detail.blocking_conditions == []
    assert detail.next_step_preview.step_kind == "start_run"
    assert detail.next_step_preview.status == "ready"

    assert {:ok, projection} =
             WorkQueryService.get_subject_projection(tenant_id, second_subject.subject_id)

    assert projection.subject_id == second_subject.subject_id
    assert projection.subject_kind == :work_object
    assert projection.work_status == :planned
    assert projection.next_step_preview.step_kind == "start_run"
    assert projection.blocking_conditions == []

    assert {:ok, stats} = WorkQueryService.queue_stats(tenant_id, program.id)
    assert stats.program_id == program.id
    assert stats.active_count >= 1
  end

  test "source service syncs product-role source pages through adapter normalization and durable work intake" do
    %{tenant_id: tenant_id, program: program, work_class: work_class} =
      fixture_stack("tenant-bridge-source-sync")

    context = request_context_by_slug(tenant_id, program.slug, work_class.name)

    assert {:ok, result} =
             SourceService.sync_source(
               context,
               :issue_tracker,
               %{
                 issues: [linear_issue()],
                 page_info: %{has_next_page: false},
                 source_binding: source_binding(),
                 viewer: %{id: "usr-linear-viewer"}
               }
             )

    assert result.source_role_ref == :issue_tracker
    assert result.source_intake.operation == "linear.issues.list"

    assert [
             %{
               subject_ref: subject_ref,
               payload: %{
                 external_ref: "linear://tenant-bridge-source-sync/issue/ENG-321",
                 provider_external_ref: "lin-issue-321",
                 source_state: "Todo"
               }
             }
           ] = result.subjects

    assert subject_ref.subject_kind == "work_object"

    assert {:ok, page_request} = PageRequest.new(%{limit: 10})

    assert {:ok, queue_page} =
             AppKit.Bridges.MezzanineBridge.list_subjects(context, nil, page_request, [])

    queue_entry =
      Enum.find(
        queue_page.entries,
        &(Map.get(&1.payload, :provider_external_ref) == "lin-issue-321")
      )

    assert queue_entry
    queue_payload = queue_entry.payload
    assert queue_payload.identifier == "ENG-321"
    assert queue_payload.provider_external_ref == "lin-issue-321"
    assert queue_payload.source_binding_id == "linear-primary"
    assert queue_payload.source_state == "Todo"
    assert queue_payload.branch_ref == "eng-321-investigate-deployment-rollback"
    assert queue_payload.source_url == "https://linear.app/example/issue/ENG-321"
    assert queue_payload.labels == ["ops"]
    assert [%{"identifier" => "SEC-9"}] = queue_payload.blocker_refs

    assert queue_payload.pre_dispatch_revalidation == %{
             "status" => "released",
             "reason" => "non_terminal_dependency",
             "safe_action" => "release_claim",
             "source_ref" => "linear://tenant-bridge-source-sync/issue/ENG-321"
           }

    assert {:ok, detail} =
             WorkQueryService.get_subject_detail(tenant_id, subject_ref.id)

    assert detail.title == "Investigate deployment rollback"
    assert detail.external_ref == "linear://tenant-bridge-source-sync/issue/ENG-321"
    assert [%{blocker_kind: "source_blocked"}] = detail.blocking_conditions
    assert detail.next_step_preview.status == "blocked"

    assert {:ok, appkit_detail} =
             AppKit.Bridges.MezzanineBridge.get_subject(context, subject_ref, [])

    assert [%{blocker_kind: "source_blocked", metadata: blocker_metadata}] =
             appkit_detail.blocking_conditions

    assert blocker_metadata.dispatch_eligible == false
    assert blocker_metadata.dispatch_preflight_reason == "non_terminal_dependency"
    assert [%{"identifier" => "SEC-9"}] = blocker_metadata.blocker_refs
    assert appkit_detail.next_step_preview.metadata.dispatch_eligible == false

    assert appkit_detail.next_step_preview.metadata.dispatch_preflight_reason ==
             "non_terminal_dependency"

    detail_payload = appkit_detail.payload
    assert detail_payload.identifier == "ENG-321"
    assert detail_payload.description == "Trace queue latency"
    assert detail_payload.priority == 2
    assert detail_payload.provider_revision == "2026-03-12T10:00:00Z"
    assert detail_payload.pre_dispatch_revalidation["reason"] == "non_terminal_dependency"
    assert detail_payload.source_routing["assignee"]["id"] == "usr-linear-viewer"

    assert detail_payload.source_routing["provenance"]["source_ref"] ==
             "linear://tenant-bridge-source-sync/issue/ENG-321"
  end

  test "source service delegates current-state lookups with a product role ref" do
    context = request_context_by_slug("tenant-current-state", "coding-ops", "coding_task")
    invocation = authorized_invocation_allowing(["linear.issues.list"])

    assert {:ok, result} =
             SourceService.current_states(
               context,
               :issue_tracker,
               %{issue_ids: ["lin-issue-321", "lin-missing"], source_binding: source_binding()},
               authorized_invocation: invocation,
               integration_bridge_service: CurrentStateBridge
             )

    assert result.source_role_ref == :issue_tracker
    assert result.source_current_state.operation == "linear.issues.list"
    assert result.source_current_state.missing_issue_ids == ["lin-missing"]

    assert_received {:current_state_requested, ^invocation, :issue_tracker,
                     ["lin-issue-321", "lin-missing"], requested_binding, _opts}

    assert requested_binding.source_binding_id == "linear-primary"
  end

  test "source service prepares API key credentials before candidate fetch" do
    context = request_context_by_slug("tenant-linear-live", "coding-ops", "coding_task")
    invocation = authorized_invocation_allowing(["linear.users.get_self", "linear.issues.list"])
    api_key = "lin_api_live_secret"

    Process.put(:credential_ingress_invocation, invocation)

    assert {:ok, result} =
             SourceService.fetch_candidates(
               context,
               :issue_tracker,
               %{source_binding: source_binding()},
               linear_api_key: api_key,
               integration_bridge_service: CredentialIngressBridge
             )

    assert_received {:prepare_linear_api_key_invocation, ^api_key, attrs, _opts}
    assert attrs.tenant_id == "tenant-linear-live"
    assert attrs.installation_id == "tenant-linear-live"
    assert attrs.allowed_operations == ["linear.users.get_self", "linear.issues.list"]

    assert attrs.subject_id == "issue_tracker"

    assert_received {:fetch_source_candidates, ^invocation, :issue_tracker, requested_binding,
                     opts}

    assert requested_binding.source_binding_id == "linear-primary"
    assert Keyword.fetch!(opts, :invoke_opts)[:connection_id] == "connection-linear-live"
    refute Keyword.has_key?(opts, :linear_api_key)
    assert result.credential_redeemed? == true
    assert result.source_role_ref == :issue_tracker
    refute inspect(result) =~ api_key
  after
    Process.delete(:credential_ingress_invocation)
  end

  test "source service uses explicit connection binding without raw credential material" do
    context = request_context_by_slug("tenant-linear-existing", "coding-ops", "coding_task")
    invocation = authorized_invocation_allowing(["linear.users.get_self", "linear.issues.list"])
    Process.put(:connection_ingress_invocation, invocation)

    assert {:ok, result} =
             SourceService.fetch_candidates(
               context,
               :issue_tracker,
               %{source_binding: source_binding()},
               connection_id: "connection-linear-existing",
               credential_ref_id: "credential-ref-linear-existing",
               credential_lease_ref: "credential-lease-linear-existing",
               integration_bridge_service: ExistingConnectionBridge
             )

    assert_received {:prepare_linear_connection_invocation, "connection-linear-existing", attrs,
                     prepare_opts}

    assert attrs.tenant_id == "tenant-linear-existing"
    assert attrs.allowed_operations == ["linear.users.get_self", "linear.issues.list"]
    assert Keyword.fetch!(prepare_opts, :credential_ref_id) == "credential-ref-linear-existing"

    assert attrs.subject_id == "issue_tracker"

    assert_received {:fetch_source_candidates, ^invocation, :issue_tracker, requested_binding,
                     opts}

    assert requested_binding.source_binding_id == "linear-primary"
    assert Keyword.fetch!(opts, :invoke_opts)[:connection_id] == "connection-linear-existing"
    assert Keyword.fetch!(opts, :credential_ref_id) == "credential-ref-linear-existing"
    assert Keyword.fetch!(opts, :credential_lease_ref) == "credential-lease-linear-existing"
    assert result.credential_redeemed? == true
    assert result.source_role_ref == :issue_tracker
    refute Keyword.has_key?(opts, :linear_api_key)
    refute Keyword.has_key?(opts, :api_key)
  after
    Process.delete(:connection_ingress_invocation)
  end

  test "source service prepares API key credentials before current-state lookup" do
    context = request_context_by_slug("tenant-linear-current-live", "coding-ops", "coding_task")
    invocation = authorized_invocation_allowing(["linear.users.get_self", "linear.issues.list"])
    api_key = "lin_api_live_secret"

    Process.put(:credential_ingress_invocation, invocation)

    assert {:ok, result} =
             SourceService.current_states(
               context,
               :issue_tracker,
               %{issue_ids: ["lin-issue-321"], source_binding: source_binding()},
               linear_api_key: api_key,
               integration_bridge_service: CredentialIngressBridge
             )

    assert_received {:prepare_linear_api_key_invocation, ^api_key, attrs, _opts}
    assert attrs.tenant_id == "tenant-linear-current-live"
    assert attrs.allowed_operations == ["linear.users.get_self", "linear.issues.list"]
    assert attrs.subject_id == "issue_tracker"

    assert_received {:fetch_source_current_states, ^invocation, :issue_tracker, ["lin-issue-321"],
                     requested_binding, opts}

    assert requested_binding.source_binding_id == "linear-primary"
    assert Keyword.fetch!(opts, :invoke_opts)[:connection_id] == "connection-linear-live"
    refute Keyword.has_key?(opts, :linear_api_key)
    assert result.credential_redeemed? == true
    assert result.source_role_ref == :issue_tracker
    refute inspect(result) =~ api_key
  after
    Process.delete(:credential_ingress_invocation)
  end

  test "source service routes issue-state publication through the state update bridge" do
    context = request_context_by_slug("tenant-linear-state", "coding-ops", "coding_task")

    invocation =
      authorized_invocation_allowing(["linear.workflow_states.list", "linear.issues.update"])

    attrs = %{
      source_publish_ref: "linear_state_update",
      source_binding_id: "linear-primary",
      source_ref: "linear://inst-1/issue/ENG-321",
      issue_id: "lin-issue-321",
      state_name: "Done",
      team_id: "team-linear"
    }

    assert {:ok, result} =
             SourceService.publish_linear_source(context, attrs,
               authorized_invocation: invocation,
               integration_bridge_service: StateUpdateBridge
             )

    assert_received {:update_linear_issue_state, ^invocation, requested_attrs, _opts}
    assert requested_attrs.state_name == "Done"
    assert requested_attrs.team_id == "team-linear"
    assert result.source_publication_receipt.capability_id == "linear.issues.update"
    assert result.source_publication_receipt.state_id == "state-done"
  end

  test "source service forwards Linear publication dry-run to the lower bridge" do
    context = request_context_by_slug("tenant-linear-dry-run", "coding-ops", "coding_task")
    invocation = authorized_invocation_allowing(["linear.comments.create"])

    attrs = %{
      source_publish_ref: "linear_workpad_review",
      source_binding_id: "linear-primary",
      source_ref: "linear://inst-1/issue/ENG-321",
      issue_id: "lin-issue-321",
      body: "Ready for review",
      allow_create_fallback?: true
    }

    assert {:ok, result} =
             SourceService.publish_linear_source(context, attrs,
               authorized_invocation: invocation,
               integration_bridge_service: DryRunPublicationBridge,
               dry_run?: true,
               credential_redeemed?: true
             )

    assert_received {:dry_run_publish_linear_source, ^invocation, requested_attrs, opts}
    assert requested_attrs.issue_id == "lin-issue-321"
    assert Keyword.fetch!(opts, :dry_run?) == true
    assert Keyword.fetch!(opts, :credential_redeemed?) == true
    assert result.provider_request_sent? == false
    assert result.credential_redeemed? == true
    assert result.source_publication_receipt.status == "dry_run_denied"
    assert result.source_publication_receipt.lower_denial_ref =~ "policy_denied"
  end

  test "source service forwards Linear GraphQL dynamic tool execution to the lower bridge" do
    context = request_context_by_slug("tenant-linear-graphql", "coding-ops", "coding_task")
    invocation = authorized_invocation_allowing(["linear.graphql.execute"])

    attrs = %{
      query: "query Viewer { viewer { id } }",
      variables: %{"includeTeams" => false}
    }

    assert {:ok, result} =
             SourceService.execute_linear_graphql_tool(context, attrs,
               authorized_invocation: invocation,
               integration_bridge_service: LinearGraphQLToolBridge,
               credential_redeemed?: true
             )

    assert_received {:linear_graphql_tool, ^invocation, requested_attrs, opts}
    assert requested_attrs.query == "query Viewer { viewer { id } }"
    assert requested_attrs.variables == %{"includeTeams" => false}
    assert Keyword.fetch!(opts, :credential_redeemed?) == true
    assert result.operation == "linear.graphql.execute"
    assert result.tool_name == "linear_graphql"
    assert result.success? == true
    assert result.dynamic_tool_response["success"] == true
  end

  test "work query service returns explicit archived errors once a subject manifest is archived" do
    %{tenant_id: tenant_id, program: program, work_class: work_class} =
      fixture_stack("tenant-bridge-archived-work")

    assert {:ok, subject} =
             WorkQueryService.ingest_subject(%{
               tenant_id: tenant_id,
               program_id: program.id,
               work_class_id: work_class.id,
               external_ref: "linear:ENG-701",
               title: "Archived work item",
               payload: %{"issue_id" => "ENG-701"},
               source_kind: "linear"
             })

    manifest_ref = archive_subject_manifest!(tenant_id, subject.subject_id)

    assert {:error, :archived, ^manifest_ref} =
             WorkQueryService.get_subject_detail(tenant_id, subject.subject_id)

    assert {:error, :archived, ^manifest_ref} =
             WorkQueryService.get_subject_projection(tenant_id, subject.subject_id)
  end

  test "work query service exposes reducer runtime projection when the row exists" do
    subject_id = Ecto.UUID.generate()

    fetcher = fn "tenant-runtime", ^subject_id, _opts ->
      {:ok,
       %{
         projection_name: "operator_subject_runtime",
         projection_kind: "operator_runtime",
         subject_id: subject_id,
         computed_at: ~U[2026-04-25 13:00:00Z],
         payload: %{
           "subject" => %{
             "subject_id" => subject_id,
             "subject_kind" => "linear_coding_ticket",
             "lifecycle_state" => "awaiting_review"
           },
           "source_binding" => %{
             "binding_ref" => "linear-primary",
             "source_ref" => "source://linear/tenant-runtime/#{subject_id}",
             "source_kind" => "linear_issue",
             "external_system" => "linear",
             "source_state" => "In Review",
             "workpad_refs" => ["source-workpad://linear/tenant-runtime/#{subject_id}"]
           },
           "execution" => %{"execution_id" => "exec-1", "dispatch_state" => "completed"},
           "lower_receipt" => %{
             "receipt_id" => "receipt-1",
             "lower_receipt_ref" => "lower-receipt://exec-1/attempt-1",
             "execution_ref" => "execution://exec-1"
           },
           "runtime" => %{
             "token_totals" => %{"input" => 120, "output" => 45},
             "rate_limit" => %{"remaining" => 80},
             "event_counts" => %{"tool_call" => 2}
           },
           "review" => %{"pending_decision_ids" => ["dec-1"]},
           "evidence" => %{"evidence_refs" => [%{"evidence_kind" => "pull_request"}]}
         }
       }}
    end

    assert {:ok, projection} =
             WorkQueryService.get_subject_projection("tenant-runtime", subject_id,
               projection_row_fetcher: fetcher
             )

    assert projection.subject_id == subject_id
    assert projection.subject_kind == "linear_coding_ticket"
    assert projection.lifecycle_state == "awaiting_review"
    assert projection.work_status == :awaiting_review
    assert projection.review_status == :pending
    assert projection.runtime["token_totals"] == %{"input" => 120, "output" => 45}
    assert projection.runtime["rate_limit"]["remaining"] == 80
    assert projection.runtime["event_counts"]["tool_call"] == 2
    assert projection.lower_receipt["receipt_id"] == "receipt-1"
    assert [%{"evidence_kind" => "pull_request"}] = projection.evidence["evidence_refs"]
  end

  test "work query service maps unknown runtime lifecycle strings to unknown" do
    subject_id = Ecto.UUID.generate()

    fetcher = fn "tenant-runtime", ^subject_id, _opts ->
      {:ok,
       %{
         projection_name: "operator_subject_runtime",
         subject_id: subject_id,
         computed_at: ~U[2026-04-25 13:00:00Z],
         payload: %{
           "subject" => %{
             "subject_id" => subject_id,
             "subject_kind" => "linear_coding_ticket",
             "lifecycle_state" => "provider_supplied_future_lifecycle"
           },
           "source_binding" => %{"source_ref" => "source://linear/#{subject_id}"},
           "execution" => %{},
           "lower_receipt" => %{}
         }
       }}
    end

    assert {:ok, projection} =
             WorkQueryService.get_subject_projection("tenant-runtime", subject_id,
               projection_row_fetcher: fetcher
             )

    assert projection.work_status == :unknown
  end

  test "work query service does not fall back to generic subject projections for runtime reads" do
    subject_id = Ecto.UUID.generate()

    fetcher = fn "tenant-runtime", ^subject_id, opts ->
      send(self(), {:runtime_fetch, opts})
      :not_found
    end

    assert {:error, :runtime_projection_not_found} =
             WorkQueryService.get_subject_projection("tenant-runtime", subject_id,
               projection_row_fetcher: fetcher,
               runtime_projection?: true
             )

    assert_receive {:runtime_fetch, opts}
    assert Keyword.get(opts, :projection_name) == "operator_subject_runtime"
  end

  test "work query service rejects non-runtime projection rows for runtime reads" do
    subject_id = Ecto.UUID.generate()

    fetcher = fn "tenant-runtime", ^subject_id, _opts ->
      {:ok,
       %{
         projection_name: "generic_subject_projection",
         subject_id: subject_id,
         computed_at: ~U[2026-04-25 13:00:00Z],
         payload: %{
           "subject" => %{"subject_id" => subject_id},
           "source_binding" => %{"source_ref" => "source://linear/tenant-runtime/#{subject_id}"},
           "execution" => %{"execution_id" => "exec-1"},
           "lower_receipt" => %{"lower_receipt_ref" => "lower-receipt://exec-1/attempt-1"}
         }
       }}
    end

    assert {:error, :runtime_projection_not_found} =
             WorkQueryService.get_subject_projection("tenant-runtime", subject_id,
               projection_row_fetcher: fetcher,
               runtime_projection?: true
             )
  end

  test "work control service returns the same app-kit compatible run result through the extracted service layer" do
    %{tenant_id: tenant_id, program: program, work_class: work_class} =
      fixture_stack("tenant-bridge-start-run")

    assert {:ok, result} =
             WorkControlService.start_run(
               %{
                 route_name: "operator.dispatch",
                 title: "Dispatch operator task",
                 payload: %{"issue_id" => "ENG-501"}
               },
               tenant_id: tenant_id,
               program_id: program.id,
               work_class_id: work_class.id,
               scope_id: "program/#{program.id}"
             )

    assert result.surface == :work_control
    assert result.state == :waiting_review
    assert %RunRef{} = result.payload.run_ref
    assert result.payload.run_ref.metadata.tenant_id == tenant_id
    assert is_binary(result.payload.work_object_id)
    assert is_binary(result.payload.plan_id)
    assert result.payload.review_required == true
  end

  test "typed work-control start_run persists a run and pending review unit for an existing subject" do
    %{tenant_id: tenant_id, program: program, work_class: work_class} =
      fixture_stack("tenant-bridge-typed-start-run")

    assert {:ok, subject} =
             WorkQueryService.ingest_subject(%{
               tenant_id: tenant_id,
               program_id: program.id,
               work_class_id: work_class.id,
               external_ref: "linear:ENG-601",
               title: "Typed start-run subject",
               payload: %{"issue_id" => "ENG-601"},
               source_kind: "linear"
             })

    context = request_context(tenant_id, program.id, work_class.id)

    assert {:ok, run_request} =
             RunRequest.new(%{
               subject_ref: %{id: subject.subject_id, subject_kind: "work_object"},
               recipe_ref: "triage_ticket",
               params: %{"priority" => "high"}
             })

    assert {:ok, result} = WorkControlService.start_run(context, run_request, [])

    assert result.surface == :work_control
    assert result.state == :waiting_review
    assert result.payload.subject_ref.id == subject.subject_id
    assert is_binary(result.payload.run_ref.run_id)
    assert result.payload.run_ref.metadata.work_object_id == subject.subject_id
    assert result.payload.run_ref.metadata.program_id == program.id
    assert is_binary(result.payload.review_unit_id)
    assert String.starts_with?(result.payload.workflow_start_ref, "workflow-start-outbox://")
    assert String.starts_with?(result.payload.workflow_start_outbox_id, "workflow-start:")
    assert result.payload.workflow_dispatch_state == "queued"
    assert result.payload.run_ref.metadata.workflow_start_ref == result.payload.workflow_start_ref
    assert is_binary(result.payload.execution_id)
    assert result.payload.execution_dispatch_state == "queued"
    assert result.payload.run_ref.metadata.execution_id == result.payload.execution_id

    assert %{
             rows: [[outbox_id, workflow_id, idempotency_key, dispatch_state]]
           } =
             ExecutionRepo.query!(
               """
               SELECT outbox_id, workflow_id, idempotency_key, dispatch_state
               FROM workflow_start_outbox
               WHERE outbox_id = $1
               """,
               [result.payload.workflow_start_outbox_id]
             )

    assert outbox_id == result.payload.workflow_start_outbox_id
    assert String.starts_with?(workflow_id, "tenant:#{tenant_id}:resource:work-object://")
    assert is_binary(idempotency_key)
    assert dispatch_state == "queued"

    assert %{
             rows: [
               [execution_id, execution_dispatch_state, submission_dedupe_key, workflow_start_ref]
             ]
           } =
             ExecutionRepo.query!(
               """
               SELECT id::text, dispatch_state::text, submission_dedupe_key,
                      dispatch_envelope->>'workflow_start_ref'
               FROM execution_records
               WHERE subject_id::text = $1
               """,
               [subject.subject_id]
             )

    assert execution_id == result.payload.execution_id
    assert execution_dispatch_state == "queued"
    assert submission_dedupe_key == idempotency_key
    assert workflow_start_ref == result.payload.workflow_start_ref

    assert {:ok, detail} = WorkQueryService.get_subject_detail(tenant_id, subject.subject_id)
    assert detail.active_run_id == result.payload.run_ref.run_id
    assert detail.active_run_status == :scheduled
    assert detail.active_execution_id == result.payload.execution_id
    assert detail.active_execution_dispatch_state == :queued
    assert result.payload.review_unit_id in detail.pending_review_ids
    assert hd(detail.pending_obligations).decision_ref_id == result.payload.review_unit_id
    assert hd(detail.blocking_conditions).blocker_kind == "review_pending"
    assert detail.next_step_preview.step_kind == "record_review_decision"
    assert detail.next_step_preview.status == "blocked"

    assert {:ok, runtime_projection} =
             WorkQueryService.get_subject_projection(tenant_id, subject.subject_id,
               projection_row_fetcher: fn _installation_id, _subject_id, _opts -> :not_found end,
               runtime_projection?: true
             )

    assert runtime_projection.projection_name == "operator_subject_runtime"
    assert runtime_projection.execution["execution_id"] == result.payload.execution_id
    assert runtime_projection.execution["dispatch_state"] == "queued"
    assert runtime_projection.execution["metadata"]["scheduler_state"] == "claim_queued"
    assert runtime_projection.execution["metadata"]["claim_state"] == "claimed"
    assert runtime_projection.execution["metadata"]["running_state"] == "not_running"
    assert runtime_projection.execution["metadata"]["retry_state"] == "none"
    assert runtime_projection.runtime["event_counts"]["scheduler_claim_queued"] == 1
    assert runtime_projection.runtime["retry_queue"] == []

    assert runtime_projection.lower_receipt["lower_receipt_ref"] ==
             "lower-receipt://pending/#{result.payload.execution_id}"

    assert [%{"binding_ref" => "linear_primary"}] = runtime_projection.source_bindings

    assert {:ok, appkit_projection} =
             AppKit.Bridges.MezzanineBridge.get_runtime_projection(
               context,
               run_request.subject_ref,
               projection_row_fetcher: fn _installation_id, _subject_id, _opts -> :not_found end
             )

    assert appkit_projection.execution_state.metadata["scheduler_state"] == "claim_queued"
    assert appkit_projection.execution_state.metadata["claim_state"] == "claimed"
    assert appkit_projection.execution_state.metadata["running_state"] == "not_running"
    assert appkit_projection.execution_state.metadata["retry_state"] == "none"
    assert appkit_projection.runtime.retry_queue == []

    retry_at = ~U[2026-05-10 22:30:00Z]

    ExecutionRepo.query!(
      """
      UPDATE execution_records
      SET dispatch_state = 'in_flight',
          next_dispatch_at = $2,
          last_dispatch_error_kind = 'restart_recovery',
          last_dispatch_error_payload = jsonb_build_object(
            'reason', 'dispatch_worker_restarted',
            'delay_type', 'continuation',
            'delay_ms', 1000,
            'continuation?', true,
            'worker_ref', 'worker://worker-a',
            'workspace_ref', 'workspace://work-1'
          ),
          updated_at = $3
      WHERE id::text = $1
      """,
      [result.payload.execution_id, retry_at, retry_at]
    )

    assert {:ok, retry_projection} =
             AppKit.Bridges.MezzanineBridge.get_runtime_projection(
               context,
               run_request.subject_ref,
               projection_row_fetcher: fn _installation_id, _subject_id, _opts -> :not_found end
             )

    assert retry_projection.execution_state.dispatch_state == "in_flight"
    assert retry_projection.execution_state.metadata["scheduler_state"] == "retry_scheduled"
    assert retry_projection.execution_state.metadata["claim_state"] == "released"
    assert retry_projection.execution_state.metadata["running_state"] == "not_running"
    assert retry_projection.execution_state.metadata["retry_state"] == "scheduled"

    assert [
             %{
               "attempt_ref" => retry_attempt_ref,
               "status" => "scheduled",
               "reason" => "restart_recovery",
               "scheduled_at" => scheduled_at,
               "due_at" => due_at,
               "delay_type" => "continuation",
               "delay_ms" => 1000,
               "continuation?" => true,
               "worker_ref" => "worker://worker-a",
               "workspace_ref" => "workspace://work-1"
             }
           ] = retry_projection.runtime.retry_queue

    assert retry_attempt_ref == "attempt://#{result.payload.execution_id}/1"
    assert DateTime.compare(scheduled_at, retry_at) == :eq
    assert DateTime.compare(due_at, retry_at) == :eq

    completed_at = ~U[2026-05-10 22:40:00Z]

    ExecutionRepo.query!(
      """
      UPDATE execution_records
      SET dispatch_state = 'completed',
          next_dispatch_at = NULL,
          last_dispatch_error_kind = NULL,
          last_dispatch_error_payload = '{}'::jsonb,
          updated_at = $2
      WHERE id::text = $1
      """,
      [result.payload.execution_id, completed_at]
    )

    assert {:ok, completed_projection} =
             AppKit.Bridges.MezzanineBridge.get_runtime_projection(
               context,
               run_request.subject_ref,
               projection_row_fetcher: fn _installation_id, _subject_id, _opts -> :not_found end
             )

    assert completed_projection.lifecycle_state == "completed"
    assert completed_projection.execution_state.dispatch_state == "completed"
    assert completed_projection.execution_state.metadata["scheduler_state"] == "completed"
    assert completed_projection.execution_state.metadata["claim_state"] == "completed"
    assert completed_projection.execution_state.metadata["running_state"] == "not_running"
    assert completed_projection.execution_state.metadata["retry_state"] == "none"
    assert completed_projection.execution_state.metadata["completion_state"] == "completed"

    assert {:ok, pending_reviews} = ReviewQueryService.list_pending_reviews(tenant_id, program.id)
    assert Enum.any?(pending_reviews, &(&1.decision_ref.id == result.payload.review_unit_id))
  end

  test "typed work-control start_run can complete deterministic lower lane and project receipt facts" do
    %{tenant_id: tenant_id, program: program, work_class: work_class} =
      fixture_stack("tenant-bridge-deterministic-lower")

    assert {:ok, subject} =
             WorkQueryService.ingest_subject(%{
               tenant_id: tenant_id,
               program_id: program.id,
               work_class_id: work_class.id,
               external_ref: "linear:ENG-603",
               title: "Deterministic lower subject",
               payload: %{"issue_id" => "ENG-603"},
               source_kind: "linear"
             })

    context = request_context(tenant_id, program.id, work_class.id)

    assert {:ok, run_request} =
             RunRequest.new(%{
               subject_ref: %{id: subject.subject_id, subject_kind: "work_object"},
               recipe_ref: "coding_operations",
               params: %{"priority" => "high"}
             })

    assert {:ok, result} =
             WorkControlService.start_run(context, run_request, deterministic_lower_lane?: true)

    assert result.payload.execution_dispatch_state == "completed"

    assert {:ok, runtime_projection} =
             WorkQueryService.get_subject_projection(tenant_id, subject.subject_id,
               projection_row_fetcher: fn _installation_id, _subject_id, _opts -> :not_found end,
               runtime_projection?: true
             )

    lower_receipt_ref = runtime_projection.lower_receipt["lower_receipt_ref"]
    assert String.starts_with?(lower_receipt_ref, "lower-receipt://")
    refute String.contains?(lower_receipt_ref, "/pending/")
    assert runtime_projection.execution["dispatch_state"] == "completed"
    assert runtime_projection.runtime["event_counts"]["codex.session.completed"] == 1
    assert runtime_projection.runtime["token_totals"]["total"] == 192
    assert runtime_projection.source_publication["capability_id"] == "linear.comments.update"
    assert runtime_projection.github_pr["provider"] == "github"

    assert {:ok, typed_runtime_projection} =
             AppKit.Bridges.MezzanineBridge.get_runtime_projection(
               context,
               run_request.subject_ref,
               projection_row_fetcher: fn _installation_id, _subject_id, _opts -> :not_found end
             )

    assert typed_runtime_projection.execution_state.dispatch_state == "completed"
    assert hd(typed_runtime_projection.lower_receipts).lower_receipt_ref == lower_receipt_ref
    assert typed_runtime_projection.runtime.token_totals["total"] == 192

    assert typed_runtime_projection.runtime.metadata["source_publication"]["capability_id"] ==
             "linear.comments.update"

    assert Enum.any?(
             typed_runtime_projection.evidence,
             &(&1.evidence_kind == "github_pr" and
                 String.starts_with?(&1.content_ref, "github-pr://"))
           )
  end

  test "typed work-control start_run preserves phase 2 run metadata for workflow handoff" do
    %{tenant_id: tenant_id, program: program, work_class: work_class} =
      fixture_stack("tenant-bridge-phase2-start-run")

    assert {:ok, subject} =
             WorkQueryService.ingest_subject(%{
               tenant_id: tenant_id,
               program_id: program.id,
               work_class_id: work_class.id,
               external_ref: "linear:ENG-602",
               title: "Phase 2 metadata subject",
               payload: %{"issue_id" => "ENG-602"},
               source_kind: "linear"
             })

    assert {:ok, context} =
             RequestContext.new(%{
               trace_id: TraceIdentity.mint(),
               actor_ref: %{id: "ops_lead", kind: :human},
               tenant_ref: %{id: tenant_id},
               idempotency_key: "idem-phase2-run",
               metadata: %{program_id: program.id, work_class_id: work_class.id}
             })

    run_metadata = %{
      "pack_revision" => 7,
      "runtime_profile_ref" => "codex_session",
      "runtime_profile_kind" => "temporal_local",
      "runtime_profile_revision" => 3,
      "lower_runtime_kind" => "codex_session",
      "requested_capability_ids" => ["codex.session.turn", "linear.comments.update"],
      "requested_action_ids" => ["codex.session.turn"],
      "source_binding_refs" => ["linear_primary"],
      "resource_scope_refs" => ["source_binding://linear_primary"],
      "workspace_policy_ref" => "workspace-policy://coding/default",
      "live_provider_allowed" => false,
      "evidence_profile_ref" => "github_pr_plus_workpad",
      "redaction_profile_ref" => "redaction://default",
      "prompt_context_recipe_refs" => ["coding_agent_system"]
    }

    assert {:ok, run_request} =
             RunRequest.new(%{
               subject_ref: %{id: subject.subject_id, subject_kind: "work_object"},
               recipe_ref: "coding_operations",
               params: %{
                 "runtime_policy_config" => %{"run" => %{"capability" => "codex.session.turn"}}
               },
               metadata: run_metadata
             })

    assert {:ok, result} = WorkControlService.start_run(context, run_request, [])

    assert result.payload.run_request_metadata["idempotency_key"] == "idem-phase2-run"
    assert result.payload.run_request_metadata["runtime_profile_ref"] == "codex_session"
    assert result.payload.run_request_metadata["requested_action_ids"] == ["codex.session.turn"]
    assert result.payload.run_ref.metadata.idempotency_key == "idem-phase2-run"
    assert result.payload.run_ref.metadata.pack_revision == 7
    assert result.payload.run_ref.metadata.runtime_profile_ref == "codex_session"
    assert String.starts_with?(result.payload.workflow_start_ref, "workflow-start-outbox://")
    assert result.payload.workflow_start_ref == result.payload.run_ref.metadata.workflow_start_ref

    assert result.payload.workflow_start_outbox_id ==
             result.payload.run_ref.metadata.workflow_start_outbox_id

    assert result.payload.workflow_dispatch_state == "queued"
    assert is_binary(result.payload.execution_id)
    assert result.payload.execution_dispatch_state == "queued"
    assert result.payload.run_ref.metadata.execution_id == result.payload.execution_id
    assert is_binary(result.payload.workflow_start_evidence_ref)
  end

  test "program context service resolves durable routing ids from product metadata" do
    %{tenant_id: tenant_id, program: program, work_class: work_class} =
      fixture_stack("tenant-bridge-routing-context")

    assert {:ok, resolved} =
             ProgramContextService.resolve(
               tenant_id,
               %{program_slug: program.slug, work_class_name: work_class.name}
             )

    assert resolved.program_id == program.id
    assert resolved.work_class_id == work_class.id
  end

  defp fixture_stack(tenant_id) do
    actor = %{tenant_id: tenant_id}

    {:ok, program} =
      Program.create_program(
        %{
          slug: "bridge-work-#{System.unique_integer([:positive])}",
          name: "Bridge Work Program",
          product_family: "operator_stack",
          configuration: %{},
          metadata: %{}
        },
        actor: actor,
        tenant: tenant_id
      )

    {:ok, bundle} =
      PolicyBundle.load_bundle(
        %{
          program_id: program.id,
          name: "default",
          version: "1.0.0",
          policy_kind: :workflow_md,
          source_ref: "WORKFLOW.md",
          body: workflow_body(),
          metadata: %{}
        },
        actor: actor,
        tenant: tenant_id
      )

    {:ok, work_class} =
      WorkClass.create_work_class(
        %{
          program_id: program.id,
          name: "coding_task_#{System.unique_integer([:positive])}",
          kind: "coding_task",
          intake_schema: %{"required" => ["title"]},
          policy_bundle_id: bundle.id,
          default_review_profile: %{"required" => true},
          default_run_profile: %{"runtime" => "session"}
        },
        actor: actor,
        tenant: tenant_id
      )

    {:ok, _existing_work} =
      WorkObject.ingest(
        %{
          program_id: program.id,
          work_class_id: work_class.id,
          external_ref: "linear:SEED-#{System.unique_integer([:positive])}",
          title: "Seed work",
          description: "Seed active work",
          priority: 50,
          source_kind: "linear",
          payload: %{"issue_id" => "SEED"},
          normalized_payload: %{"issue_id" => "SEED"}
        },
        actor: actor,
        tenant: tenant_id
      )

    %{
      tenant_id: tenant_id,
      actor: actor,
      program: program,
      bundle: bundle,
      work_class: work_class
    }
  end

  defp request_context(tenant_id, program_id, work_class_id) do
    {:ok, context} =
      RequestContext.new(%{
        trace_id: TraceIdentity.mint(),
        actor_ref: %{id: "ops_lead", kind: :human},
        tenant_ref: %{id: tenant_id},
        metadata: %{program_id: program_id, work_class_id: work_class_id}
      })

    context
  end

  defp request_context_by_slug(tenant_id, program_slug, work_class_name) do
    {:ok, context} =
      RequestContext.new(%{
        trace_id: TraceIdentity.mint(),
        actor_ref: %{id: "ops_lead", kind: :human},
        tenant_ref: %{id: tenant_id},
        metadata: %{program_slug: program_slug, work_class_name: work_class_name}
      })

    context
  end

  defp source_binding do
    %{
      source_binding_id: "linear-primary",
      installation_id: "tenant-bridge-source-sync",
      provider: "linear",
      connection_ref: "linear-primary",
      candidate_filters: %{assignee: "me"},
      state_mapping: %{
        "submitted" => ["Todo"],
        "completed" => ["Done"],
        "rejected" => ["Canceled", "Duplicate"]
      }
    }
  end

  defp authorized_invocation_allowing(allowed_operations) do
    attrs =
      authorized_invocation_attrs()
      |> put_in([:invocation_request, :allowed_operations], allowed_operations)
      |> put_in([:invocation_request, :execution_governance, :operations], %{
        "allowed_operations" => allowed_operations
      })

    AuthorizedInvocation.new!(attrs)
  end

  defp authorized_invocation_attrs do
    %{
      tenant_id: "tenant-current-state",
      installation_id: "inst-current-state",
      subject_id: "subject-current-state",
      execution_id: "exec-current-state",
      trace_id: "trace-current-state",
      idempotency_key: "idem-current-state",
      submission_dedupe_key: "dedupe-current-state",
      invocation_request: %{
        schema_version: 2,
        invocation_request_id: "invoke-current-state",
        request_id: "request-current-state",
        session_id: "session-current-state",
        tenant_id: "tenant-current-state",
        trace_id: "trace-current-state",
        actor_id: "actor-current-state",
        target_id: "target-current-state",
        target_kind: "runtime_target",
        selected_step_id: "step-current-state",
        allowed_operations: ["linear.issues.list"],
        authority_packet: %{
          contract_version: "v1",
          decision_id: "decision-current-state",
          tenant_id: "tenant-current-state",
          request_id: "request-current-state",
          policy_version: "mock-v1",
          boundary_class: "workspace_session",
          trust_profile: "baseline",
          approval_profile: "standard",
          egress_profile: "restricted",
          workspace_profile: "workspace",
          resource_profile: "standard",
          decision_hash: String.duplicate("a", 64),
          extensions: %{"citadel" => %{}}
        },
        boundary_intent: %{},
        topology_intent: %{},
        execution_governance: %{
          "contract_version" => "v1",
          "execution_governance_id" => "governance-current-state",
          "authority_ref" => %{"decision_id" => "decision-current-state"},
          "operations" => %{"allowed_operations" => ["linear.issues.list"]},
          "sandbox" => %{},
          "credentials" => %{},
          "resources" => %{}
        },
        extensions: %{
          "citadel" => %{
            "execution_envelope" => %{
              "installation_id" => "inst-current-state",
              "installation_revision" => 1,
              "subject_id" => "subject-current-state",
              "execution_id" => "exec-current-state",
              "submission_dedupe_key" => "dedupe-current-state"
            }
          }
        }
      }
    }
  end

  defp linear_issue do
    %{
      id: "lin-issue-321",
      identifier: "ENG-321",
      title: "Investigate deployment rollback",
      description: "Trace queue latency",
      priority: 2,
      branch_name: "eng-321-investigate-deployment-rollback",
      labels: ["Ops"],
      url: "https://linear.app/example/issue/ENG-321",
      created_at: "2026-03-12T09:15:00Z",
      updated_at: "2026-03-12T10:00:00Z",
      pre_dispatch_revalidation: %{
        "status" => "released",
        "reason" => "non_terminal_dependency",
        "safe_action" => "release_claim",
        "source_ref" => "linear://tenant-bridge-source-sync/issue/ENG-321"
      },
      state: %{id: "state-todo", name: "Todo", type: "unstarted"},
      assignee: %{id: "usr-linear-viewer", name: "Taylor Automation"},
      blockers: [
        %{
          id: "rel-blocks-001",
          type: "blocks",
          direction: "inbound",
          issue: %{
            id: "lin-issue-009",
            identifier: "SEC-9",
            title: "Restore deployment credentials",
            url: "https://linear.app/example/issue/SEC-9",
            state: %{id: "state-started", name: "In Progress", type: "started"}
          }
        }
      ]
    }
  end

  defp workflow_body do
    """
    ---
    tracker:
      kind: linear
      endpoint: https://api.linear.app/graphql
    run:
      profile: default_session
      runtime_class: session
      capability: codex.session.turn
      target: linear-default
    approval:
      mode: manual
      reviewers:
        - ops_lead
      escalation_required: true
    retry:
      strategy: exponential
      max_attempts: 4
      initial_backoff_ms: 5000
      max_backoff_ms: 300000
    placement:
      profile_id: default-placement
      strategy: affinity
      target_selector:
        runtime_driver: jido_session
      runtime_preferences:
        locality: same_region
    workspace:
      root_mode: per_work
      sandbox_profile: strict
    review:
      required: true
      required_decisions: 1
      gates:
        - operator
    capability_grants:
      - capability_id: linear.issues.retrieve
        mode: allow
      - capability_id: linear.issues.update
        mode: allow
    ---
    # Operator Prompt
    """
  end

  defp archive_subject_manifest!(installation_id, subject_id) do
    terminal_at = ~U[2026-04-16 12:00:00Z]

    manifest_ref =
      "archive/#{installation_id}/#{subject_id}/#{System.unique_integer([:positive])}"

    {:ok, manifest} =
      ArchivalManifest.stage(%{
        manifest_ref: manifest_ref,
        installation_id: installation_id,
        subject_id: subject_id,
        subject_state: "completed",
        execution_states: [],
        trace_ids: [],
        execution_ids: [],
        decision_ids: [],
        evidence_ids: [],
        audit_fact_ids: [],
        projection_names: [],
        terminal_at: terminal_at,
        due_at: terminal_at,
        retention_seconds: 0,
        storage_kind: "filesystem",
        metadata: %{"source" => "work_services_test"}
      })

    {:ok, _archived} = ArchivalManifest.mark_archived(manifest, %{archived_at: terminal_at})
    manifest_ref
  end
end
