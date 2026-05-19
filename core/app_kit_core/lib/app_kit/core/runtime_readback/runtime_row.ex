defmodule AppKit.Core.RuntimeReadback.RuntimeRow do
  @moduledoc "State-list row for runtime readback."

  alias AppKit.Core.PersistencePosture
  alias AppKit.Core.RuntimeReadback.{PollingState, SessionRef, Support, TokenTotals, WorkspaceRef}

  @enforce_keys [:subject_ref, :run_ref, :state, :updated_at]
  defstruct [
    :subject_ref,
    :run_ref,
    :execution_ref,
    :workflow_ref,
    :state,
    :status_reason,
    :updated_at,
    :session_ref,
    :workspace_ref,
    :polling_state,
    :token_totals,
    persistence_posture: PersistencePosture.memory(:runtime_projection),
    provider_refs: %{},
    extensions: %{}
  ]

  def new(%__MODULE__{} = value), do: {:ok, value}

  def new(attrs) do
    with {:ok, attrs, nil} <- Support.normalize(attrs),
         :ok <- Support.reject_selectors(attrs, :invalid_runtime_row),
         subject_ref when is_binary(subject_ref) <- Support.required(attrs, :subject_ref),
         true <- Support.safe_ref?(subject_ref),
         run_ref when is_binary(run_ref) <- Support.required(attrs, :run_ref),
         true <- Support.safe_ref?(run_ref),
         execution_ref <- Support.optional(attrs, :execution_ref),
         true <- Support.optional_ref?(execution_ref),
         workflow_ref <- Support.optional(attrs, :workflow_ref),
         true <- Support.optional_ref?(workflow_ref),
         state <- Support.required(attrs, :state),
         true <- Support.atomish?(state),
         status_reason <- Support.optional(attrs, :status_reason),
         true <- is_nil(status_reason) or is_binary(status_reason),
         updated_at <- Support.required(attrs, :updated_at),
         true <- Support.timestamp?(updated_at),
         {:ok, session_ref} <- Support.nested(Support.optional(attrs, :session_ref), SessionRef),
         {:ok, workspace_ref} <-
           Support.nested(Support.optional(attrs, :workspace_ref), WorkspaceRef),
         {:ok, polling_state} <-
           Support.nested(Support.optional(attrs, :polling_state), PollingState),
         {:ok, token_totals} <-
           Support.nested(Support.optional(attrs, :token_totals), TokenTotals),
         persistence_posture <- Support.persistence_posture(attrs),
         provider_refs <- Support.optional(attrs, :provider_refs, %{}),
         true <- is_map(provider_refs),
         extensions <- Support.optional(attrs, :extensions, %{}),
         true <- is_map(extensions) do
      {:ok,
       %__MODULE__{
         subject_ref: subject_ref,
         run_ref: run_ref,
         execution_ref: execution_ref,
         workflow_ref: workflow_ref,
         state: state,
         status_reason: status_reason,
         updated_at: updated_at,
         session_ref: session_ref,
         workspace_ref: workspace_ref,
         polling_state: polling_state,
         token_totals: token_totals,
         persistence_posture: persistence_posture,
         provider_refs: provider_refs,
         extensions: extensions
       }}
    else
      _ -> {:error, :invalid_runtime_row}
    end
  end

  def dump(%__MODULE__{} = value), do: Support.dump_struct(value)

  def sort_key(%__MODULE__{updated_at: updated_at, subject_ref: subject_ref, run_ref: run_ref}),
    do: {updated_key(updated_at), subject_ref, run_ref}

  defp updated_key(%DateTime{} = value), do: DateTime.to_iso8601(value)
  defp updated_key(value), do: to_string(value)
end
