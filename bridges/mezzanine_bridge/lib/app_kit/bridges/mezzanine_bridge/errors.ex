defmodule AppKit.Bridges.MezzanineBridge.Errors do
  @moduledoc false

  alias AppKit.Core.SurfaceError

  @authorization_reasons [
    :cross_tenant_operator_command_denied,
    :cross_tenant_control_denied,
    :cross_tenant_live_effect_denied,
    :operator_actor_context_mismatch,
    :operator_actor_tenant_mismatch,
    :unauthorized_turn_submission,
    :unauthorized_lower_read
  ]
  @not_found_reasons [:bridge_not_found, :not_found, :pack_registration_not_found]
  @conflict_reasons [
    :handoff_state_conflict,
    :idempotency_conflict,
    :installation_pack_conflict,
    :review_gate_not_satisfied,
    :run_cursor_conflict,
    :run_terminal,
    :stale_turn_cursor
  ]
  @transient_reasons [:agent_run_owner_unavailable, :timeout, :temporarily_unavailable]
  @validation_reasons [
    :cursor_run_mismatch,
    :cursor_turn_mismatch,
    :non_contiguous_event,
    :non_contiguous_provider_event,
    :provider_events_without_model_turn,
    :stale_proof_token,
    :turn_acceptance_mismatch,
    :unsupported_owner_event_type
  ]
  @validation_reason_prefixes ["missing_", "invalid_", "unsupported_"]

  def normalize(%SurfaceError{} = error), do: {:error, error}

  def normalize({:archived, manifest_ref}) when is_binary(manifest_ref) do
    {:ok, error} =
      SurfaceError.new(%{
        code: "archived",
        message: "Subject is archived",
        kind: :terminal,
        retryable: false,
        details: %{manifest_ref: manifest_ref}
      })

    {:error, error}
  end

  def normalize({:stale_control_version, current_version})
      when is_integer(current_version) and current_version > 0 do
    {:ok, error} =
      SurfaceError.new(%{
        code: "stale_control_version",
        message: "Run control changed; reload the durable run state before retrying",
        kind: :conflict,
        retryable: false,
        details: %{current_control_row_version: current_version}
      })

    {:error, error}
  end

  def normalize({:invalid_control_transition, current_state, action}) do
    {:ok, error} =
      SurfaceError.new(%{
        code: "invalid_control_transition",
        message: "The requested control is not valid for the durable run state",
        kind: :conflict,
        retryable: false,
        details: %{current_state: to_string(current_state), action: to_string(action)}
      })

    {:error, error}
  end

  def normalize(reason) do
    {:ok, error} =
      SurfaceError.new(%{
        code: code(reason),
        message: message(reason),
        kind: kind(reason),
        retryable: retryable?(reason),
        details: %{reason: inspect(reason)}
      })

    {:error, error}
  end

  defp code(reason) when is_atom(reason), do: Atom.to_string(reason)
  defp code(_reason), do: "bridge_error"

  defp message(reason) do
    reason
    |> inspect()
    |> String.trim_leading(":")
    |> String.replace("_", " ")
    |> String.capitalize()
  end

  defp kind(reason) when reason in @authorization_reasons, do: :authorization
  defp kind(reason) when reason in @not_found_reasons, do: :not_found
  defp kind(reason) when reason in @conflict_reasons, do: :conflict
  defp kind(reason) when reason in @transient_reasons, do: :transient
  defp kind(reason) when reason in @validation_reasons, do: :validation

  defp kind(reason) when is_atom(reason) do
    if validation_reason?(reason), do: :validation, else: :boundary
  end

  defp kind(_reason), do: :boundary

  defp retryable?(reason), do: kind(reason) == :transient

  defp validation_reason?(reason) when is_atom(reason) do
    reason
    |> Atom.to_string()
    |> then(fn string_reason ->
      Enum.any?(@validation_reason_prefixes, &String.starts_with?(string_reason, &1))
    end)
  end
end
