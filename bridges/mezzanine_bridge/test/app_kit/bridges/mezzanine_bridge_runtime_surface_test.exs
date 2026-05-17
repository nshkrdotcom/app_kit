defmodule AppKit.Bridges.MezzanineBridgeRuntimeSurfaceTest do
  use ExUnit.Case, async: true

  alias AppKit.Bridges.MezzanineBridge

  alias AppKit.Core.RuntimeSurface.{
    GitHubPrBranchCleanupReceipt,
    GitHubPrEvidenceReceipt,
    LiveEffectReceipt,
    RuntimeLogPage,
    RuntimeProfileApplyResult,
    RuntimeStatusSnapshot
  }

  defmodule RuntimeProfileService do
    def apply(tenant_id, runtime_profile) do
      send(self(), {:runtime_profile_apply, tenant_id, runtime_profile})

      {:ok,
       %{
         status: :updated,
         profile_ref: "runtime-profile://#{tenant_id}/sample",
         program_ref: "program://sample-workflow",
         policy_bundle_ref: "policy-bundle://sample",
         work_class_ref: "work-class://sample",
         placement_profile_ref: "placement-profile://local",
         metadata: %{"source" => "runtime-profile-service"}
       }}
    end
  end

  defmodule OperatorQueryService do
    def system_health(tenant_id, program_id) do
      send(self(), {:system_health, tenant_id, program_id})

      {:ok,
       %{
         program_id: program_id,
         active_run_count: 2,
         pending_review_count: 1,
         queue_stats: %{ready_count: 3}
       }}
    end

    def timeline(tenant_id, subject_id) do
      send(self(), {:timeline, tenant_id, subject_id})

      {:ok,
       %{
         entries: [
           %{
             ref: "event://runtime/log/1",
             event_kind: "run_scheduled",
             summary: "Run scheduled",
             payload: %{subject_id: subject_id}
           }
         ]
       }}
    end
  end

  defmodule SourceService do
    def publish_source(context, publication_role_ref, attrs, _opts) do
      send(self(), {:publish_source, context.tenant_ref.id, publication_role_ref, attrs})

      {:ok,
       %{
         source_publication_receipt: %{
           source_publication_receipt_ref: "source-publication://linear-primary/test",
           source_publish_ref: attrs.source_publish_ref,
           source_binding_id: attrs.source_binding_id,
           source_ref: attrs.source_ref,
           status: "published",
           capability_id: "linear.comments.update",
           lower_runtime_kind: "direct_connector",
           authority_ref: "authority-decision://linear/test",
           workpad_refs: ["linear-comment://comment-1"]
         }
       }}
    end
  end

  defmodule GitHubPrEvidenceService do
    def fetch(attrs, opts) do
      send(self(), {:fetch_github_pr_evidence, attrs, opts})

      {:ok,
       %{
         effect_ref: "live-effect://github/pr-evidence/17",
         provider: "github",
         effect: "github_pr_evidence",
         status: :receipt_recorded,
         capability_ids: ["github.pr.fetch", "github.pr.reviews.list"],
         repo: attrs.repo,
         pull_number: attrs.pull_number,
         head_sha: attrs.ref,
         evidence_ref: "evidence://github-pr/nshkrdotcom/sample-app/17/test",
         credential_present?: true,
         credential_redeemed?: true,
         provider_request_sent?: true,
         provider_response_received?: true,
         receipt_recorded?: true,
         product_readback_confirmed?: true,
         provider_ids: %{pull_request: "17"},
         provider_refs: %{pull_request: "https://github.com/nshkrdotcom/sample-app/pull/17"},
         write_operations: [],
         receipt_refs: %{
           lower_request_refs: ["lower-request://github/pr-fetch"],
           lower_receipt_refs: ["lower-receipt://github/pr-fetch/succeeded"]
         }
       }}
    end
  end

  defmodule GitHubPrBranchCleanupService do
    def cleanup(attrs, opts) do
      send(self(), {:cleanup_github_pr_branch, attrs, opts})

      {:ok,
       %{
         effect_ref: "live-effect://github/pr-branch-cleanup/cleanup-branch",
         provider: "github",
         effect: "github_pr_branch_cleanup",
         status: :receipt_recorded,
         capability_ids: ["github.pr.list", "github.comment.create", "github.pr.update"],
         repo: attrs.repo,
         branch: attrs.branch,
         pull_numbers: [17],
         closed_pull_numbers: [17],
         credential_present?: true,
         credential_redeemed?: true,
         provider_request_sent?: true,
         provider_response_received?: true,
         receipt_recorded?: true,
         product_readback_confirmed?: true,
         provider_ids: %{pull_requests: ["17"]},
         provider_refs: %{
           pull_requests: ["https://github.com/nshkrdotcom/sample-app/pull/17"]
         },
         write_operations: ["github.comment.create", "github.pr.update"],
         receipt_refs: %{
           lower_request_refs: ["lower-request://github/pr-cleanup"],
           lower_receipt_refs: ["lower-receipt://github/pr-cleanup/succeeded"]
         }
       }}
    end
  end

  test "applies runtime profiles through the Mezzanine runtime profile service" do
    context = request_context()
    runtime_profile = runtime_profile()

    assert {:ok, %RuntimeProfileApplyResult{} = result} =
             MezzanineBridge.apply_runtime_profile(context, runtime_profile,
               runtime_profile_service: RuntimeProfileService
             )

    assert_received {:runtime_profile_apply, "tenant-1", ^runtime_profile}
    assert result.status == :updated
    assert result.profile_ref == "runtime-profile://tenant-1/sample"
    assert result.program_ref == "program://sample-workflow"
  end

  test "exposes status and logs as operator-safe runtime DTOs" do
    context = request_context(%{program_id: "program-1"})

    assert {:ok, %RuntimeStatusSnapshot{} = status} =
             MezzanineBridge.runtime_status(context, %{},
               operator_query_service: OperatorQueryService
             )

    assert_received {:system_health, "tenant-1", "program-1"}
    assert status.program_ref == "program-1"
    assert status.health["active_run_count"] == 2
    assert status.health["queue_stats"]["ready_count"] == 3

    assert {:ok, %RuntimeLogPage{} = logs} =
             MezzanineBridge.runtime_logs(context, %{subject_id: "subject-1"},
               operator_query_service: OperatorQueryService
             )

    assert_received {:timeline, "tenant-1", "subject-1"}
    assert [%{event_kind: "run_scheduled"}] = logs.entries
  end

  test "wraps live effect proof state without accepting raw provider secrets" do
    context = request_context()

    assert {:ok, %LiveEffectReceipt{} = receipt} =
             MezzanineBridge.record_live_effect(context, %{
               effect_ref: "live-effect://linear/source/1",
               provider: "linear",
               effect: "source_intake",
               capability_ids: ["linear.issues.list"],
               status: :receipt_recorded,
               credential_present?: true,
               credential_redeemed?: true,
               provider_request_sent?: true,
               provider_response_received?: true,
               receipt_recorded?: true,
               product_readback_confirmed?: false
             })

    assert receipt.tenant_ref == "tenant-1"
    assert receipt.receipt_recorded? == true

    assert {:error, _surface_error} =
             MezzanineBridge.record_live_effect(context, %{
               effect_ref: "live-effect://linear/source/1",
               provider: "linear",
               effect: "source_intake",
               status: :receipt_recorded,
               token: "secret"
             })
  end

  test "publishes Linear source receipts through the AppKit source bridge" do
    context = request_context()

    attrs = %{
      source_publish_ref: "linear_workpad_review",
      source_binding_id: "linear-primary",
      source_ref: "linear://inst-1/issue/ENG-321",
      comment_id: "comment-1",
      body: "Ready for review"
    }

    assert {:ok, result} =
             MezzanineBridge.publish_source(context, :source_publication, attrs,
               source_service: SourceService
             )

    assert_received {:publish_source, "tenant-1", :source_publication, ^attrs}
    assert result.source_publication_receipt.status == "published"
    assert result.source_publication_receipt.authority_ref == "authority-decision://linear/test"
  end

  test "fetches GitHub PR evidence through the Mezzanine evidence service" do
    context = request_context()
    request = %{repo: "nshkrdotcom/sample-app", pull_number: 17, ref: "head-sha"}

    assert {:ok, %GitHubPrEvidenceReceipt{} = receipt} =
             MezzanineBridge.fetch_github_pr_evidence(context, request,
               github_pr_evidence_service: GitHubPrEvidenceService
             )

    assert_received {:fetch_github_pr_evidence, attrs, opts}
    assert attrs.tenant_id == "tenant-1"
    assert attrs.actor_id == "operator"
    assert attrs.repo == "nshkrdotcom/sample-app"
    assert attrs.pull_number == 17
    assert attrs.ref == "head-sha"
    assert Keyword.fetch!(opts, :github_pr_evidence_service) == GitHubPrEvidenceService
    assert receipt.provider == "github"
    assert receipt.provider_ids["pull_request"] == "17"
    assert receipt.write_operations == []
  end

  test "cleans up GitHub PRs for a branch through the Mezzanine cleanup service" do
    context = request_context()
    request = %{repo: "nshkrdotcom/sample-app", branch: "cleanup-branch", confirm_close?: true}

    assert {:ok, %GitHubPrBranchCleanupReceipt{} = receipt} =
             MezzanineBridge.cleanup_github_pr_branch(context, request,
               github_pr_branch_cleanup_service: GitHubPrBranchCleanupService
             )

    assert_received {:cleanup_github_pr_branch, attrs, opts}
    assert attrs.tenant_id == "tenant-1"
    assert attrs.actor_id == "operator"
    assert attrs.repo == "nshkrdotcom/sample-app"
    assert attrs.branch == "cleanup-branch"
    assert attrs.confirm_close? == true
    assert Keyword.fetch!(opts, :github_pr_branch_cleanup_service) == GitHubPrBranchCleanupService
    assert receipt.provider == "github"
    assert receipt.effect == "github_pr_branch_cleanup"
    assert receipt.closed_pull_numbers == [17]
    assert receipt.write_operations == ["github.comment.create", "github.pr.update"]
  end

  defp request_context(metadata \\ %{}) do
    {:ok, context} =
      AppKit.Core.RequestContext.new(%{
        trace_id: "11111111111111111111111111111111",
        actor_ref: %{id: "operator", kind: :human},
        tenant_ref: %{id: "tenant-1"},
        installation_ref: %{id: "installation-1", pack_slug: "sample-host"},
        metadata: metadata
      })

    context
  end

  defp runtime_profile do
    %{
      "program" => %{"slug" => "sample-workflow"},
      "policy_bundle" => %{"name" => "sample_policy"},
      "work_class" => %{"name" => "sample_work"},
      "placement_profile" => %{"profile_id" => "local"}
    }
  end
end
