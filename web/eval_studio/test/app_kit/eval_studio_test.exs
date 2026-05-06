defmodule AppKit.EvalStudioTest do
  use ExUnit.Case, async: true

  alias AppKit.EvalStudio

  test "renders eval state from refs and bounded drift signals" do
    assert {:ok, studio} =
             EvalStudio.studio(%{
               studio_ref: "studio://eval",
               tenant_ref: "tenant://alpha",
               suite_ref: "eval-suite://one",
               eval_run_ref: "eval-run://one",
               verdict: :regress,
               case_refs: ["eval-case://one"],
               drift_signal_refs: ["drift://latency"]
             })

    assert studio.redaction_posture == "eval_refs_and_bounded_signals_only"
  end

  test "rejects raw eval payloads" do
    assert {:error, {:raw_eval_studio_payload_forbidden, :eval_payload}} =
             EvalStudio.studio(%{
               studio_ref: "studio://eval",
               tenant_ref: "tenant://alpha",
               suite_ref: "eval-suite://one",
               eval_run_ref: "eval-run://one",
               verdict: :pass,
               eval_payload: %{private: true}
             })
  end
end
