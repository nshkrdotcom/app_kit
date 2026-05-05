defmodule AppKit.HeadlessSurface.Contract do
  @moduledoc """
  Product-safe headless surface contracts.
  """

  defmodule Accepted do
    @moduledoc """
    Product-safe accepted-command projection for headless surfaces.
    """

    @type t :: %__MODULE__{
            tenant_ref: String.t(),
            subject_ref: String.t(),
            actor_ref: String.t(),
            authority_projection_ref: String.t(),
            provider_account_ref: String.t(),
            connector_binding_ref: String.t(),
            credential_handle_ref: String.t(),
            credential_lease_ref: String.t(),
            native_auth_assertion_ref: String.t(),
            target_ref: String.t(),
            attach_grant_ref: String.t(),
            operation_policy_ref: String.t(),
            runtime_invocation_ref: String.t(),
            trace_ref: String.t(),
            idempotency_key: String.t(),
            correlation_id: String.t(),
            command_ref: String.t(),
            accepted?: true
          }

    defstruct [
      :tenant_ref,
      :subject_ref,
      :actor_ref,
      :authority_projection_ref,
      :provider_account_ref,
      :connector_binding_ref,
      :credential_handle_ref,
      :credential_lease_ref,
      :native_auth_assertion_ref,
      :target_ref,
      :attach_grant_ref,
      :operation_policy_ref,
      :runtime_invocation_ref,
      :trace_ref,
      :idempotency_key,
      :correlation_id,
      :command_ref,
      accepted?: true
    ]
  end

  defmodule OperatorCommand do
    @moduledoc """
    Product-safe operator command projection for headless surfaces.
    """

    @type t :: %__MODULE__{
            action:
              :cancel
              | :retry
              | :reassign_provider
              | :reassign_target
              | :request_human_input
              | :revoke_authority
              | :rotate_authority
              | :rotate_lease
              | :renew_authority
              | :rebind_authority
              | :detach_authority
              | :detach_target
              | :transfer_authority
              | :inspect_authority
              | :invalidate_authority
              | :resume_session,
            actor_ref: String.t() | nil,
            command_ref: String.t() | nil,
            authority_refs: [String.t()]
          }

    defstruct [:action, :actor_ref, :command_ref, :authority_refs]
  end

  @required_submit_refs [
    :tenant_ref,
    :subject_ref,
    :actor_ref,
    :authority_projection_ref,
    :provider_account_ref,
    :connector_binding_ref,
    :credential_handle_ref,
    :credential_lease_ref,
    :native_auth_assertion_ref,
    :target_ref,
    :attach_grant_ref,
    :operation_policy_ref,
    :runtime_invocation_ref,
    :trace_ref,
    :idempotency_key,
    :correlation_id
  ]

  @forbidden_material [
    :api_key,
    :auth_json,
    :authorization_header,
    :provider_payload,
    :raw_secret,
    :raw_token,
    :target_credentials,
    :token_file
  ]

  @actions [
    :cancel,
    :retry,
    :reassign_provider,
    :reassign_target,
    :request_human_input,
    :revoke_authority,
    :rotate_authority,
    :rotate_lease,
    :renew_authority,
    :rebind_authority,
    :detach_authority,
    :detach_target,
    :transfer_authority,
    :inspect_authority,
    :invalidate_authority,
    :resume_session
  ]
  @action_lookup Map.new(@actions, &{Atom.to_string(&1), &1})
  @known_fields @required_submit_refs ++
                  @forbidden_material ++ [:action, :command_ref, :authority_refs]

  @spec submit(map() | keyword()) ::
          {:ok, Accepted.t()}
          | {:error, {:missing_headless_surface_refs, [atom()]}}
          | {:error, {:forbidden_headless_surface_material, [atom()]}}
  def submit(attrs) when is_map(attrs) or is_list(attrs) do
    attrs = normalize(attrs)

    case forbidden_material(attrs) do
      [] ->
        case missing_refs(attrs) do
          [] -> {:ok, accepted(attrs)}
          missing -> {:error, {:missing_headless_surface_refs, missing}}
        end

      forbidden ->
        {:error, {:forbidden_headless_surface_material, forbidden}}
    end
  end

  @spec actions() :: [atom()]
  def actions, do: @actions

  @spec operator_command(map() | keyword()) ::
          {:ok, OperatorCommand.t()} | {:error, {:invalid_headless_surface_action, term()}}
  def operator_command(attrs) when is_map(attrs) or is_list(attrs) do
    attrs = normalize(attrs)

    case normalize_action(Map.get(attrs, :action)) do
      {:ok, action} ->
        {:ok,
         %OperatorCommand{
           action: action,
           actor_ref: Map.get(attrs, :actor_ref),
           command_ref: Map.get(attrs, :command_ref),
           authority_refs: List.wrap(Map.get(attrs, :authority_refs, []))
         }}

      :error ->
        {:error, {:invalid_headless_surface_action, Map.get(attrs, :action)}}
    end
  end

  defp accepted(attrs) do
    %Accepted{
      tenant_ref: Map.fetch!(attrs, :tenant_ref),
      subject_ref: Map.fetch!(attrs, :subject_ref),
      actor_ref: Map.fetch!(attrs, :actor_ref),
      authority_projection_ref: Map.fetch!(attrs, :authority_projection_ref),
      provider_account_ref: Map.fetch!(attrs, :provider_account_ref),
      connector_binding_ref: Map.fetch!(attrs, :connector_binding_ref),
      credential_handle_ref: Map.fetch!(attrs, :credential_handle_ref),
      credential_lease_ref: Map.fetch!(attrs, :credential_lease_ref),
      native_auth_assertion_ref: Map.fetch!(attrs, :native_auth_assertion_ref),
      target_ref: Map.fetch!(attrs, :target_ref),
      attach_grant_ref: Map.fetch!(attrs, :attach_grant_ref),
      operation_policy_ref: Map.fetch!(attrs, :operation_policy_ref),
      runtime_invocation_ref: Map.fetch!(attrs, :runtime_invocation_ref),
      trace_ref: Map.fetch!(attrs, :trace_ref),
      idempotency_key: Map.fetch!(attrs, :idempotency_key),
      correlation_id: Map.fetch!(attrs, :correlation_id),
      command_ref: "headless-command://tenant-1/#{Map.fetch!(attrs, :idempotency_key)}"
    }
  end

  defp forbidden_material(attrs), do: Enum.filter(@forbidden_material, &Map.has_key?(attrs, &1))
  defp missing_refs(attrs), do: Enum.reject(@required_submit_refs, &present?(Map.get(attrs, &1)))

  defp normalize_action(value) when is_atom(value) do
    if value in @actions, do: {:ok, value}, else: :error
  end

  defp normalize_action(value) when is_binary(value), do: Map.fetch(@action_lookup, value)
  defp normalize_action(_value), do: :error

  defp normalize(attrs) when is_list(attrs), do: attrs |> Map.new() |> normalize()

  defp normalize(attrs) when is_map(attrs) do
    Map.new(attrs, fn
      {key, value} when is_binary(key) -> {string_key(key), value}
      {key, value} -> {key, value}
    end)
  end

  defp string_key(key), do: Enum.find(@known_fields, key, &(Atom.to_string(&1) == key))

  defp present?(value) when is_binary(value), do: String.trim(value) != ""
  defp present?(value), do: not is_nil(value)
end
