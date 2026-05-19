defmodule AppKit.Core.RuntimeReadback.RuntimeEventRow do
  @moduledoc "M1-readable runtime event row. Future M2 event kinds pass through safely."

  alias AppKit.Core.RuntimeReadback.Support

  @enforce_keys [:event_ref, :event_seq, :event_kind, :observed_at]
  defstruct [
    :event_ref,
    :event_seq,
    :event_kind,
    :observed_at,
    :tenant_ref,
    :installation_ref,
    :subject_ref,
    :run_ref,
    :execution_ref,
    :workflow_ref,
    :attempt_ref,
    :session_ref,
    :turn_ref,
    :level,
    :message_summary,
    :payload_ref,
    :extensions,
    :trace_id,
    :profile_ref,
    :source_contract_ref
  ]

  def new(%__MODULE__{} = value), do: {:ok, value}

  def new(attrs) do
    with {:ok, attrs, nil} <- Support.normalize(attrs),
         :ok <- Support.reject_selectors(attrs, :invalid_runtime_event_row),
         event_ref when is_binary(event_ref) <- Support.required(attrs, :event_ref),
         true <- Support.safe_ref?(event_ref),
         event_seq <- Support.required(attrs, :event_seq),
         true <- Support.non_neg_integer?(event_seq),
         event_kind <- Support.required(attrs, :event_kind),
         true <- Support.atomish?(event_kind),
         observed_at <- Support.required(attrs, :observed_at),
         true <- Support.timestamp?(observed_at),
         fields <- optional_fields(attrs),
         true <-
           Enum.all?(
             [
               :tenant_ref,
               :installation_ref,
               :subject_ref,
               :run_ref,
               :execution_ref,
               :workflow_ref,
               :attempt_ref,
               :session_ref,
               :turn_ref,
               :payload_ref,
               :trace_id,
               :profile_ref,
               :source_contract_ref
             ],
             &Support.optional_ref?(Map.get(fields, &1))
           ),
         true <- is_nil(fields.level) or Support.atomish?(fields.level),
         true <- is_nil(fields.message_summary) or is_binary(fields.message_summary),
         true <- is_map(fields.extensions) do
      {:ok,
       struct!(
         __MODULE__,
         Map.merge(fields, %{
           event_ref: event_ref,
           event_seq: event_seq,
           event_kind: normalize_atomish(event_kind),
           observed_at: observed_at
         })
       )}
    else
      _ -> {:error, :invalid_runtime_event_row}
    end
  end

  def dump(%__MODULE__{} = value), do: Support.dump_struct(value)

  def sort_key(%__MODULE__{} = value),
    do: {value.event_seq, observed_key(value.observed_at), value.event_ref}

  defp optional_fields(attrs) do
    %{
      tenant_ref: Support.optional(attrs, :tenant_ref),
      installation_ref: Support.optional(attrs, :installation_ref),
      subject_ref: Support.optional(attrs, :subject_ref),
      run_ref: Support.optional(attrs, :run_ref),
      execution_ref: Support.optional(attrs, :execution_ref),
      workflow_ref: Support.optional(attrs, :workflow_ref),
      attempt_ref: Support.optional(attrs, :attempt_ref),
      session_ref: Support.optional(attrs, :session_ref),
      turn_ref: Support.optional(attrs, :turn_ref),
      level: Support.optional(attrs, :level),
      message_summary: Support.optional(attrs, :message_summary),
      payload_ref: Support.optional(attrs, :payload_ref),
      extensions: Support.optional(attrs, :extensions, %{}),
      trace_id: Support.optional(attrs, :trace_id),
      profile_ref: Support.optional(attrs, :profile_ref),
      source_contract_ref: Support.optional(attrs, :source_contract_ref)
    }
  end

  defp observed_key(%DateTime{} = value), do: DateTime.to_iso8601(value)
  defp observed_key(value), do: to_string(value)
  defp normalize_atomish(value) when is_binary(value), do: value
  defp normalize_atomish(value), do: value
end
