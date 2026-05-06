defmodule AppKit.Web.ComponentsTest do
  use ExUnit.Case, async: true

  alias AppKit.Web.Components

  test "builds safe ref, hash, decision, and projection table components" do
    assert {:ok, ref} = Components.ref_badge("Trace", "trace://phase-f")
    assert ref.component == :ref_badge

    assert {:ok, hash} = Components.hash_badge("Bundle hash", "sha256:abc")
    assert hash.redaction_posture == "bounded_refs_only"

    assert {:ok, decision} = Components.decision_class("Decision", :review)
    assert decision.value == "review"

    assert {:ok, table} =
             Components.projection_table(%{
               table_ref: "table://operator/one",
               tenant_ref: "tenant://alpha",
               columns: ["ref", "status"],
               rows: [%{ref: "prompt://one", status: "ready"}]
             })

    assert table.component == :projection_table
  end

  test "rejects raw assign names recursively" do
    assert {:error, {:forbidden_assign_name, "prompt_body"}} =
             Components.projection_table(%{
               table_ref: "table://operator/one",
               tenant_ref: "tenant://alpha",
               columns: ["ref"],
               rows: [%{ref: "prompt://one", prompt_body: "private"}]
             })

    assert {:error, {:forbidden_assign_name, "token"}} =
             Components.field(%{
               component: :ref_badge,
               label: "Credential",
               value: "ref",
               token: "x"
             })
  end

  test "source policy detects forbidden imports from caller supplied fragments" do
    safe_source = "defmodule ProductWeb do\n  alias AppKit.OperatorConsole\nend\n"
    unsafe_source = "defmodule ProductWeb do\n  alias LowerRuntime.Store\nend\n"

    assert :ok = Components.source_policy(safe_source, ["LowerRuntime."])

    assert {:error, [%Components.SourceViolation{line: 2, fragment: "LowerRuntime."}]} =
             Components.source_policy(unsafe_source, ["LowerRuntime."])
  end
end
