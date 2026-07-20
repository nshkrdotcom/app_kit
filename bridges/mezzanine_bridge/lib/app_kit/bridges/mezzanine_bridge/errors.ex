defmodule AppKit.Bridges.MezzanineBridge.Errors do
  @moduledoc false

  alias AppKit.Core.SurfaceError

  @authorization_reasons [
    :cross_tenant_operator_command_denied,
    :operator_actor_tenant_mismatch,
    :unauthorized_lower_read
  ]
  @not_found_reasons [:bridge_not_found, :not_found, :pack_registration_not_found]
  @conflict_reasons [
    :handoff_state_conflict,
    :idempotency_conflict,
    :installation_pack_conflict,
    :review_gate_not_satisfied
  ]
  @transient_reasons [:agent_run_owner_unavailable, :timeout, :temporarily_unavailable]
  @validation_reasons [:cursor_run_mismatch, :non_contiguous_event, :stale_proof_token]
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
