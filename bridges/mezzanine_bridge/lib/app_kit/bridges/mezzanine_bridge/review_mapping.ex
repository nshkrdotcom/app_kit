defmodule AppKit.Bridges.MezzanineBridge.ReviewMapping do
  @moduledoc false

  alias AppKit.Bridges.MezzanineBridge.Common
  alias AppKit.Core.{DecisionRef, DecisionSummary, RequestContext, SubjectRef}

  def decision_summary_from_row(row, %RequestContext{} = context) do
    with {:ok, decision_ref} <- decision_ref_from_row(row, context) do
      DecisionSummary.new(%{
        decision_ref: decision_ref,
        status: Common.normalize_string(Common.fetch_value(row, :status) || "pending"),
        required_by: Common.fetch_value(row, :required_by),
        subject_ref: decision_ref.subject_ref,
        summary: Common.fetch_value(row, :summary),
        schema_ref: "mezzanine/review_unit",
        schema_version: 1,
        payload: Common.fetch_value(row, :payload) || %{}
      })
    end
  end

  defp decision_ref_from_row(row, %RequestContext{} = context) do
    raw_ref = Common.fetch_value(row, :decision_ref) || %{}

    raw_subject_ref =
      Common.fetch_value(raw_ref, :subject_ref) || Common.fetch_value(row, :subject_ref)

    with {:ok, subject_ref} <- subject_ref_from_any(raw_subject_ref, context) do
      DecisionRef.new(%{
        id: Common.fetch_value(raw_ref, :id) || Common.fetch_value(row, :review_unit_id),
        decision_kind:
          Common.normalize_string(
            Common.fetch_value(raw_ref, :decision_kind) ||
              Common.fetch_value(row, :review_kind) || "review"
          ),
        subject_ref: subject_ref
      })
    end
  end

  defp subject_ref_from_any(nil, _context), do: {:ok, nil}

  defp subject_ref_from_any(raw_subject_ref, %RequestContext{} = context)
       when is_map(raw_subject_ref) do
    SubjectRef.new(%{
      id: Common.fetch_value(raw_subject_ref, :id),
      subject_kind:
        Common.normalize_string(Common.fetch_value(raw_subject_ref, :subject_kind) || "subject"),
      installation_ref: context.installation_ref
    })
  end

  defp subject_ref_from_any(_raw_subject_ref, _context), do: {:error, :invalid_subject_ref}
end
