defmodule Mezzanine.AppKitBridge.RuntimeGatewayService do
  @moduledoc """
  AppKit runtime gateway service over Mezzanine lower dispatch.

  Product callers pass role refs. This service prepares any required lower
  authorization and forwards the request to Mezzanine's binding-driven runtime
  or tool dispatcher.
  """

  alias AppKit.Core.RequestContext
  alias Mezzanine.IntegrationBridge
  alias Mezzanine.IntegrationBridge.AuthorizedInvocation

  @spec invoke_runtime_operation(
          RequestContext.t(),
          term(),
          term(),
          map(),
          map() | keyword() | nil,
          keyword()
        ) :: {:ok, map()} | {:error, term()}
  def invoke_runtime_operation(
        %RequestContext{} = _context,
        runtime_role_ref,
        operation_role_ref,
        attrs,
        runtime_binding,
        opts \\ []
      )
      when (is_atom(runtime_role_ref) or is_binary(runtime_role_ref)) and
             (is_atom(operation_role_ref) or is_binary(operation_role_ref)) and is_map(attrs) and
             is_list(opts) do
    service = integration_bridge_service(opts)

    if service_exports?(service, :invoke_runtime_operation, 6) do
      service.invoke_runtime_operation(
        nil,
        runtime_role_ref,
        operation_role_ref,
        attrs,
        runtime_binding,
        opts
      )
    else
      {:error, :runtime_operation_not_configured}
    end
  end

  @spec invoke_runtime_tool(RequestContext.t(), term(), term(), map(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def invoke_runtime_tool(
        %RequestContext{} = context,
        tool_role_ref,
        operation_role_ref,
        attrs,
        opts \\ []
      )
      when (is_atom(tool_role_ref) or is_binary(tool_role_ref)) and
             (is_atom(operation_role_ref) or is_binary(operation_role_ref)) and is_map(attrs) and
             is_list(opts) do
    tool_binding = tool_binding(attrs, opts)

    with {:ok, _tenant_id} <- required_context_id(context.tenant_ref, :tenant_ref),
         allowed_operations <-
           runtime_tool_allowed_operations(
             tool_role_ref,
             operation_role_ref,
             tool_binding,
             attrs,
             opts
           ),
         {:ok, invocation, opts} <-
           authorized_invocation(
             context,
             allowed_operations,
             value(attrs, :tool_ref) || value(tool_binding, :tool_ref) || tool_role_ref,
             with_credential_adapter(opts, tool_binding)
           ),
         attrs <- attrs |> Map.new() |> Map.put_new(:trace_id, context.trace_id),
         {:ok, service} <- runtime_tool_service(opts) do
      service.invoke_runtime_tool(
        invocation,
        tool_role_ref,
        operation_role_ref,
        attrs,
        tool_binding,
        opts
      )
    end
  end

  @spec collect_evidence(RequestContext.t(), term(), map(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def collect_evidence(%RequestContext{} = context, evidence_role_ref, attrs, opts \\ [])
      when (is_atom(evidence_role_ref) or is_binary(evidence_role_ref)) and is_map(attrs) and
             is_list(opts) do
    evidence_binding = evidence_binding(attrs, opts)
    attrs = gateway_attrs(context, attrs)
    service = integration_bridge_service(opts)

    if service_exports?(service, :collect_evidence, 4) do
      service.collect_evidence(evidence_role_ref, attrs, evidence_binding, opts)
    else
      {:error, :evidence_collection_not_configured}
    end
  end

  @spec invoke_resource_effect(RequestContext.t(), term(), map(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def invoke_resource_effect(
        %RequestContext{} = context,
        resource_effect_role_ref,
        attrs,
        opts \\ []
      )
      when (is_atom(resource_effect_role_ref) or is_binary(resource_effect_role_ref)) and
             is_map(attrs) and is_list(opts) do
    resource_effect_binding = resource_effect_binding(attrs, opts)
    attrs = gateway_attrs(context, attrs)
    service = integration_bridge_service(opts)

    if service_exports?(service, :invoke_resource_effect, 4) do
      service.invoke_resource_effect(
        resource_effect_role_ref,
        attrs,
        resource_effect_binding,
        opts
      )
    else
      {:error, :resource_effect_not_configured}
    end
  end

  defp runtime_tool_allowed_operations(
         tool_role_ref,
         operation_role_ref,
         tool_binding,
         attrs,
         opts
       ) do
    explicit_operations =
      Keyword.get(opts, :allowed_operations) ||
        value(attrs, :allowed_operations) ||
        value(tool_binding, :allowed_operations)

    cond do
      is_list(explicit_operations) and explicit_operations != [] ->
        explicit_operations

      service_exports?(integration_bridge_service(opts), :runtime_tool_allowed_operations, 5) ->
        integration_bridge_service(opts).runtime_tool_allowed_operations(
          tool_role_ref,
          operation_role_ref,
          tool_binding,
          attrs,
          opts
        )

      true ->
        []
    end
  end

  defp tool_binding(attrs, opts) do
    Keyword.get(opts, :tool_binding) ||
      value(attrs, :tool_binding) ||
      value(attrs, "tool_binding")
  end

  defp evidence_binding(attrs, opts) do
    Keyword.get(opts, :evidence_binding) ||
      value(attrs, :evidence_binding) ||
      value(attrs, "evidence_binding")
  end

  defp resource_effect_binding(attrs, opts) do
    Keyword.get(opts, :resource_effect_binding) ||
      value(attrs, :resource_effect_binding) ||
      value(attrs, "resource_effect_binding")
  end

  defp gateway_attrs(%RequestContext{} = context, attrs) do
    attrs
    |> Map.new()
    |> Map.put_new(:tenant_id, context.tenant_ref.id)
    |> Map.put_new(:actor_id, context.actor_ref.id)
    |> Map.put_new(:trace_id, context.trace_id)
    |> Map.put_new(:installation_id, installation_id(context))
  end

  defp required_context_id(%{id: id}, _key) when is_binary(id) and id != "", do: {:ok, id}
  defp required_context_id(_ref, key), do: {:error, {:missing_context_ref, key}}

  defp authorized_invocation(%RequestContext{} = context, allowed_operations, subject_hint, opts) do
    case existing_invocation(opts) do
      {:ok, %AuthorizedInvocation{} = invocation} ->
        {:ok, invocation, opts}

      {:error, :missing_authorized_runtime_invocation} ->
        prepare_connection_invocation(context, allowed_operations, subject_hint, opts)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp existing_invocation(opts) do
    case Keyword.get(opts, :authorized_invocation) || Keyword.get(opts, :invocation) do
      %AuthorizedInvocation{} = invocation -> {:ok, invocation}
      nil -> {:error, :missing_authorized_runtime_invocation}
      _other -> {:error, :invalid_authorized_runtime_invocation}
    end
  end

  defp prepare_connection_invocation(context, allowed_operations, subject_hint, opts) do
    case string_opt(opts, :connection_id) do
      nil ->
        prepare_api_key_invocation(context, allowed_operations, subject_hint, opts)

      connection_id ->
        with {:ok, service} <- credential_ingress_service(opts),
             {:ok, prepared} <-
               service.prepare_credential_invocation(
                 credential_request(:connection, connection_id, opts),
                 invocation_ingress_attrs(context, allowed_operations, subject_hint, opts),
                 opts
               ),
             {:ok, %AuthorizedInvocation{} = invocation} <-
               prepared_authorized_invocation(prepared) do
          {:ok, invocation, merge_prepared_runtime_opts(opts, prepared)}
        else
          {:error, reason} -> {:error, reason}
          _other -> {:error, :invalid_prepared_credential_invocation}
        end
    end
  end

  defp prepare_api_key_invocation(context, allowed_operations, subject_hint, opts) do
    with {:ok, secret_source} <- credential_secret_source(opts),
         {:ok, service} <- credential_ingress_service(opts),
         {:ok, prepared} <-
           service.prepare_credential_invocation(
             credential_request(:api_key, secret_source, opts),
             invocation_ingress_attrs(context, allowed_operations, subject_hint, opts),
             credential_ingress_opts(opts, secret_source)
           ),
         {:ok, %AuthorizedInvocation{} = invocation} <- prepared_authorized_invocation(prepared) do
      {:ok, invocation, merge_prepared_runtime_opts(opts, prepared)}
    else
      {:error, reason} -> {:error, reason}
      _other -> {:error, :invalid_prepared_credential_invocation}
    end
  end

  defp runtime_tool_service(opts) do
    service = integration_bridge_service(opts)

    if service_exports?(service, :invoke_runtime_tool, 6) do
      {:ok, service}
    else
      {:error, :runtime_tool_not_configured}
    end
  end

  defp credential_secret_source(opts) do
    cond do
      Keyword.get(opts, :credential_secret_provider) ->
        {:ok,
         %{
           secret_provider: Keyword.fetch!(opts, :credential_secret_provider),
           secret_scope: Keyword.get(opts, :credential_secret_scope, %{}),
           secret_opts: Keyword.get(opts, :credential_secret_opts, [])
         }}

      string_opt(opts, :credential_env_var) ->
        {:ok,
         %{
           secret_source_ref: :env,
           secret_scope: %{
             env_var: string_opt(opts, :credential_env_var),
             secret_key: :api_key
           },
           secret_opts: []
         }}

      string_opt(opts, :linear_api_key_env_var) ->
        {:ok,
         %{
           secret_source_ref: :env,
           secret_scope: %{
             env_var: string_opt(opts, :linear_api_key_env_var),
             secret_key: :api_key
           },
           secret_opts: []
         }}

      true ->
        ephemeral_secret_source(opts)
    end
  end

  defp ephemeral_secret_source(opts) do
    case Keyword.get(opts, :linear_api_key) || Keyword.get(opts, :api_key) do
      api_key when is_binary(api_key) and api_key != "" ->
        {:ok,
         %{
           secret_source_ref: :ephemeral,
           secret_scope: %{provider_ref: "ephemeral://app-kit-runtime", secret_key: :api_key},
           secret_opts: [
             secret_materializer: fn -> %{api_key: api_key} end
           ]
         }}

      _missing ->
        {:error, :missing_authorized_runtime_invocation}
    end
  end

  defp credential_ingress_service(opts) do
    service = integration_bridge_service(opts)

    if service_exports?(service, :prepare_credential_invocation, 3) do
      {:ok, service}
    else
      {:error, :credential_ingress_not_configured}
    end
  end

  defp prepared_authorized_invocation(prepared) do
    case value(prepared, :authorized_invocation) do
      %AuthorizedInvocation{} = invocation -> {:ok, invocation}
      _other -> {:error, :invalid_prepared_credential_invocation}
    end
  end

  defp invocation_ingress_attrs(context, allowed_operations, subject_hint, opts) do
    trace_id = context.trace_id || "trace-app-kit-runtime"

    execution_id =
      Keyword.get(opts, :execution_id) || "exec-app-kit-runtime-#{stable_hash(trace_id)}"

    idempotency_key =
      context.idempotency_key || Keyword.get(opts, :idempotency_key) || execution_id

    %{
      tenant_id: context.tenant_ref.id,
      installation_id: installation_id(context),
      subject_id: Keyword.get(opts, :subject_id) || to_string(subject_hint),
      execution_id: execution_id,
      trace_id: trace_id,
      idempotency_key: idempotency_key,
      submission_dedupe_key: context.causation_id || idempotency_key,
      actor_id: context.actor_ref.id,
      allowed_operations: allowed_operations,
      subject: Keyword.get(opts, :credential_subject) || context.actor_ref.id
    }
  end

  defp installation_id(%RequestContext{installation_ref: %{id: id}})
       when is_binary(id) and id != "",
       do: id

  defp installation_id(%RequestContext{tenant_ref: %{id: tenant_id}}), do: tenant_id

  defp merge_prepared_runtime_opts(opts, prepared) do
    prepared_opts = List.wrap(value(prepared, :source_opts))

    opts
    |> Keyword.drop(secret_option_keys())
    |> Keyword.merge(prepared_opts, fn
      :invoke_opts, left, right -> Keyword.merge(List.wrap(left), List.wrap(right))
      _key, _left, right -> right
    end)
  end

  defp with_credential_adapter(opts, binding) do
    case value(binding, :adapter_ref) || value(binding, :source_adapter_ref) do
      adapter_ref when is_atom(adapter_ref) or is_binary(adapter_ref) ->
        Keyword.put_new(opts, :credential_adapter_ref, adapter_ref)

      _missing ->
        opts
    end
  end

  defp credential_request(:connection, connection_id, opts) do
    %{
      adapter_ref: Keyword.get(opts, :credential_adapter_ref),
      credential_kind: :connection,
      connection_id: connection_id
    }
  end

  defp credential_request(:api_key, secret_source, opts) do
    %{
      adapter_ref: Keyword.get(opts, :credential_adapter_ref),
      credential_kind: :api_key,
      secret_scope: Map.fetch!(secret_source, :secret_scope),
      lease_ref: Keyword.get(opts, :credential_lease_ref)
    }
    |> maybe_put(:secret_provider, Map.get(secret_source, :secret_provider))
    |> maybe_put(:secret_source_ref, Map.get(secret_source, :secret_source_ref))
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp credential_ingress_opts(opts, secret_source) do
    opts
    |> Keyword.drop(secret_option_keys())
    |> Keyword.merge(Map.get(secret_source, :secret_opts, []), fn _key, _left, right -> right end)
  end

  defp secret_option_keys do
    [
      :linear_api_key,
      :api_key,
      :credential_secret_provider,
      :credential_secret_scope,
      :credential_secret_opts,
      :credential_env_var,
      :linear_api_key_env_var
    ]
  end

  defp integration_bridge_service(opts),
    do: Keyword.get(opts, :integration_bridge_service, IntegrationBridge)

  defp service_exports?(service, function, arity) when is_atom(service) do
    Code.ensure_loaded?(service) and function_exported?(service, function, arity)
  end

  defp value(%_{} = struct, key), do: struct |> Map.from_struct() |> value(key)
  defp value(%{} = map, key), do: Map.get(map, key) || Map.get(map, alternate_key(map, key))
  defp value(_map, _key), do: nil

  defp alternate_key(_map, key) when is_atom(key), do: Atom.to_string(key)

  defp alternate_key(map, key) when is_binary(key) do
    Enum.find(Map.keys(map), fn
      existing_key when is_atom(existing_key) -> Atom.to_string(existing_key) == key
      _existing_key -> false
    end)
  end

  defp string_opt(opts, key) do
    case Keyword.get(opts, key) do
      value when is_binary(value) ->
        value = String.trim(value)
        if value == "", do: nil, else: value

      _other ->
        nil
    end
  end

  defp stable_hash(value), do: value |> :erlang.phash2() |> Integer.to_string(36)
end
