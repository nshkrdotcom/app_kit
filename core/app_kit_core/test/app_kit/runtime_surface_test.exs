defmodule AppKit.RuntimeSurfaceTest do
  use ExUnit.Case, async: true

  alias AppKit.Core.RuntimeSurface.{
    LiveEffectReceipt,
    RuntimeLogPage,
    RuntimeProfileApplyResult,
    RuntimeStatusSnapshot
  }

  alias AppKit.RuntimeSurface

  defmodule Backend do
    @behaviour AppKit.Core.Backends.RuntimeBackend

    @impl true
    def apply_runtime_profile(context, runtime_profile, _opts) do
      RuntimeProfileApplyResult.new(%{
        status: :updated,
        tenant_ref: context.tenant_ref.id,
        profile_ref: "runtime-profile://symphony/import",
        program_ref: runtime_profile["program"]["slug"],
        policy_bundle_ref: runtime_profile["policy_bundle"]["name"],
        work_class_ref: runtime_profile["work_class"]["name"],
        placement_profile_ref: runtime_profile["placement_profile"]["profile_id"],
        metadata: %{"source" => "test"}
      })
    end

    @impl true
    def runtime_status(context, request, _opts) do
      RuntimeStatusSnapshot.new(%{
        tenant_ref: context.tenant_ref.id,
        program_ref: request[:program_ref],
        health: %{"active_run_count" => 1},
        preflight: %{"temporal" => "not_checked"},
        metadata: %{"profile_status" => "updated"}
      })
    end

    @impl true
    def runtime_logs(_context, request, _opts) do
      RuntimeLogPage.new(%{
        entries: [
          %{
            ref: "event://runtime/log/1",
            event_kind: "run_scheduled",
            summary: "Run scheduled",
            payload: %{"subject_id" => request[:subject_id]}
          }
        ],
        total_count: 1,
        metadata: %{"redacted" => true}
      })
    end

    @impl true
    def record_live_effect(context, attrs, _opts) do
      LiveEffectReceipt.new(Map.put(attrs, :tenant_ref, context.tenant_ref.id))
    end
  end

  test "delegates runtime profile, status, logs, and live-effect DTOs through backend" do
    context = request_context()
    runtime_profile = runtime_profile()

    assert {:ok, %RuntimeProfileApplyResult{} = applied} =
             RuntimeSurface.apply_runtime_profile(context, runtime_profile, backend: Backend)

    assert applied.status == :updated
    assert applied.program_ref == "symphony-workflow"

    assert {:ok, %RuntimeStatusSnapshot{} = status} =
             RuntimeSurface.runtime_status(context, %{program_ref: "program://one"},
               backend: Backend
             )

    assert status.health["active_run_count"] == 1
    assert status.preflight["temporal"] == "not_checked"

    assert {:ok, %RuntimeLogPage{} = logs} =
             RuntimeSurface.runtime_logs(context, %{subject_id: "subject-1"}, backend: Backend)

    assert [%{event_kind: "run_scheduled"}] = logs.entries

    assert {:ok, %LiveEffectReceipt{} = receipt} =
             RuntimeSurface.record_live_effect(
               context,
               %{
                 effect_ref: "live-effect://linear/source/1",
                 provider: "linear",
                 effect: "source_intake",
                 capability_ids: ["linear.issues.list"],
                 status: :provider_response_received,
                 credential_present?: true,
                 credential_redeemed?: true,
                 provider_request_sent?: true,
                 provider_response_received?: true,
                 receipt_recorded?: true,
                 product_readback_confirmed?: true
               },
               backend: Backend
             )

    assert receipt.provider == "linear"
    assert receipt.product_readback_confirmed? == true
  end

  test "live-effect DTO rejects raw secret-bearing fields" do
    assert {:error, :invalid_live_effect_receipt} =
             LiveEffectReceipt.new(%{
               effect_ref: "live-effect://linear/source/1",
               provider: "linear",
               effect: "source_intake",
               status: :provider_response_received,
               api_key: "secret"
             })
  end

  defp request_context do
    {:ok, context} =
      AppKit.Core.RequestContext.new(%{
        trace_id: "11111111111111111111111111111111",
        actor_ref: %{id: "operator", kind: :human},
        tenant_ref: %{id: "tenant-1"},
        installation_ref: %{id: "installation-1", pack_slug: "extravaganza"}
      })

    context
  end

  defp runtime_profile do
    %{
      "program" => %{"slug" => "symphony-workflow"},
      "policy_bundle" => %{"name" => "symphony_policy"},
      "work_class" => %{"name" => "symphony_work"},
      "placement_profile" => %{"profile_id" => "local"}
    }
  end
end
