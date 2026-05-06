defmodule AppKit.OperatorConsoleTest do
  use ExUnit.Case, async: true

  alias AppKit.OperatorConsole

  test "authorizes and renders DTO-only sections" do
    assert {:ok, session} = OperatorConsole.authorize(session_attrs())

    assert {:ok, view} =
             OperatorConsole.render(session, %{
               memory: [%{tenant_ref: "tenant://alpha", ref: "memory://one", status: "ready"}],
               prompts: [%{tenant_ref: "tenant://alpha", ref: "prompt://one", status: "draft"}],
               connectors: [
                 %{tenant_ref: "tenant://alpha", ref: "connector://one", status: "admitted"}
               ]
             })

    assert view.redaction_posture == "dto_and_bounded_exports_only"
    assert view.data_access_posture == "app_kit_dtos_no_lower_store_imports"
    assert view.section_count == 3
  end

  test "renders adaptive-control operator state through the console DTO path" do
    assert {:ok, session} = OperatorConsole.authorize(session_attrs())

    assert {:ok, view} =
             OperatorConsole.render(session, %{
               adaptive_controls: [
                 %{
                   tenant_ref: "tenant://alpha",
                   candidate_review_ref: "candidate-review://adaptive/worker/v2",
                   shadow_state_ref: "shadow://adaptive/worker/v2",
                   canary_state_ref: "canary://adaptive/worker/v2",
                   promotion_ref: "promotion://adaptive/worker/v2",
                   rollback_ref: "rollback://adaptive/worker/v1",
                   audit_ref: "audit://adaptive/worker/v2",
                   status: "operator_review"
                 }
               ]
             })

    assert view.section_count == 1
    assert Map.has_key?(view.sections, :adaptive_controls)
    assert view.redaction_posture == "dto_and_bounded_exports_only"
    assert view.data_access_posture == "app_kit_dtos_no_lower_store_imports"
  end

  test "rejects unauthorized and tenant mismatched projection access" do
    assert {:error, :operator_console_access_denied} =
             OperatorConsole.authorize(Map.put(session_attrs(), :operator_authorized?, false))

    assert {:ok, session} = OperatorConsole.authorize(session_attrs())

    assert {:error, :tenant_mismatched_operator_projection} =
             OperatorConsole.render(session, %{
               memory: [%{tenant_ref: "tenant://beta", ref: "memory://other"}]
             })
  end

  test "rejects raw payloads" do
    assert {:ok, session} = OperatorConsole.authorize(session_attrs())

    assert {:error, {:forbidden_assign_name, "memory_body"}} =
             OperatorConsole.render(session, %{
               memory: [%{tenant_ref: "tenant://alpha", memory_body: "private"}]
             })
  end

  defp session_attrs do
    %{
      session_ref: "session://operator/one",
      tenant_ref: "tenant://alpha",
      authority_ref: "authority://ops",
      installation_ref: "installation://one",
      operator_ref: "operator://one",
      trace_ref: "trace://phase-f",
      release_manifest_ref: "release://phase-f"
    }
  end
end
