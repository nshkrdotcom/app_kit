defmodule Mezzanine.AppKitBridge.SourceService do
  @moduledoc false

  alias AppKit.Core.{RequestContext, SubjectRef}
  alias Mezzanine.AppKitBridge.{ProgramContextService, WorkQueryService}
  alias Mezzanine.IntegrationBridge
  alias Mezzanine.IntegrationBridge.AuthorizedInvocation

  @type source_role_ref :: atom() | String.t()

  @spec sync_source(RequestContext.t(), source_role_ref(), map(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def sync_source(%RequestContext{} = context, source_role_ref, source_page, opts \\ [])
      when (is_atom(source_role_ref) or is_binary(source_role_ref)) and is_map(source_page) and
             is_list(opts) do
    with {:ok, route} <- route_context(context, opts),
         {:ok, binding} <- source_binding(context, source_page, opts),
         envelope <- source_envelope(context, source_page, binding),
         {:ok, source_intake} <-
           integration_bridge_service(opts).normalize_source_page(
             source_role_ref,
             page_output(source_page),
             envelope,
             binding,
             opts
           ),
         {:ok, subjects, skipped} <-
           ingest_subject_attrs(source_intake.subject_attrs, route, opts) do
      {:ok,
       %{
         operation: source_intake.operation,
         source_role_ref: source_role_ref,
         source_binding_id: source_intake.source_binding_id,
         source_intake: source_intake,
         subjects: subjects,
         skipped_subject_attrs: skipped,
         page_info: source_intake.page_info
       }}
    end
  end

  @spec current_states(RequestContext.t(), source_role_ref(), map(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def current_states(%RequestContext{} = context, source_role_ref, request, opts \\ [])
      when (is_atom(source_role_ref) or is_binary(source_role_ref)) and is_map(request) and
             is_list(opts) do
    with {:ok, source_binding} <- source_binding(context, request, opts),
         {:ok, _tenant_id} <- required_context_id(context.tenant_ref, :tenant_ref),
         {:ok, issue_ids} <- issue_ids(request),
         {:ok, invocation, opts} <-
           authorized_invocation(
             context,
             source_allowed_operations(source_role_ref, source_binding, opts),
             source_role_ref,
             with_credential_adapter(opts, source_binding)
           ) do
      integration_bridge_service(opts).fetch_source_current_states(
        invocation,
        source_role_ref,
        issue_ids,
        source_binding,
        opts
      )
    end
  end

  @spec fetch_candidates(RequestContext.t(), source_role_ref(), map(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def fetch_candidates(%RequestContext{} = context, source_role_ref, request, opts \\ [])
      when (is_atom(source_role_ref) or is_binary(source_role_ref)) and is_map(request) and
             is_list(opts) do
    with {:ok, source_binding} <- source_binding(context, request, opts),
         {:ok, _tenant_id} <- required_context_id(context.tenant_ref, :tenant_ref),
         {:ok, invocation, opts} <-
           authorized_invocation(
             context,
             source_allowed_operations(source_role_ref, source_binding, opts),
             source_role_ref,
             with_credential_adapter(opts, source_binding)
           ) do
      integration_bridge_service(opts).fetch_source_candidates(
        invocation,
        source_role_ref,
        source_binding,
        opts
      )
    end
  end

  @spec publish_source(RequestContext.t(), source_role_ref(), map(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def publish_source(%RequestContext{} = context, publication_role_ref, attrs, opts \\ [])
      when (is_atom(publication_role_ref) or is_binary(publication_role_ref)) and is_map(attrs) and
             is_list(opts) do
    with {:ok, source_binding} <- source_binding(context, attrs, opts),
         {:ok, _tenant_id} <- required_context_id(context.tenant_ref, :tenant_ref),
         {:ok, invocation, opts} <-
           authorized_invocation(
             context,
             source_publication_allowed_operations(
               publication_role_ref,
               source_binding,
               attrs,
               opts
             ),
             value(attrs, :source_ref) || value(attrs, :source_publish_ref) ||
               publication_role_ref,
             with_credential_adapter(opts, source_binding)
           ) do
      attrs =
        attrs
        |> Map.new()
        |> Map.put_new(:trace_id, context.trace_id)

      integration_bridge_service(opts).publish_source(
        invocation,
        publication_role_ref,
        attrs,
        source_binding,
        opts
      )
    end
  end

  defp route_context(%RequestContext{} = context, opts) do
    with {:ok, tenant_id} <- required_context_id(context.tenant_ref, :tenant_ref),
         {:ok, route} <- resolve_route_context(tenant_id, context, opts) do
      {:ok, Map.put(route, :tenant_id, tenant_id)}
    end
  end

  defp required_context_id(%{id: id}, _key) when is_binary(id) and id != "", do: {:ok, id}
  defp required_context_id(_ref, key), do: {:error, {:missing_context_ref, key}}

  defp resolve_route_context(tenant_id, context, opts) do
    case {route_id(context, opts, :program_id), route_id(context, opts, :work_class_id)} do
      {{:ok, program_id}, {:ok, work_class_id}} ->
        {:ok, %{program_id: program_id, work_class_id: work_class_id}}

      _missing ->
        resolve_route_by_slug(tenant_id, context, opts)
    end
  end

  defp resolve_route_by_slug(tenant_id, context, opts) do
    with {:ok, program_slug} <- route_metadata(context, opts, :program_slug),
         {:ok, work_class_name} <- route_metadata(context, opts, :work_class_name),
         {:ok, resolution} <-
           program_context_service(opts).resolve(
             tenant_id,
             %{program_slug: program_slug, work_class_name: work_class_name},
             opts
           ),
         {:ok, program_id} <- resolved_route_id(resolution, :program_id),
         {:ok, work_class_id} <- resolved_route_id(resolution, :work_class_id) do
      {:ok, %{program_id: program_id, work_class_id: work_class_id}}
    end
  end

  defp route_id(%RequestContext{} = context, opts, key) do
    value = Keyword.get(opts, key) || value(context.metadata, key)

    if is_binary(value) and value != "" do
      {:ok, value}
    else
      :missing
    end
  end

  defp route_metadata(%RequestContext{} = context, opts, key) do
    case Keyword.get(opts, key) || value(context.metadata, key) do
      value when is_binary(value) and value != "" -> {:ok, value}
      _missing -> {:error, {:missing_source_route, key}}
    end
  end

  defp resolved_route_id(resolution, key) do
    case value(resolution, key) do
      value when is_binary(value) and value != "" -> {:ok, value}
      _missing -> {:error, {:missing_source_route, key}}
    end
  end

  defp source_binding(context, source_page, opts) do
    explicit_binding =
      Keyword.get(opts, :source_binding) ||
        value(source_page, :source_binding)

    with {:ok, binding} <- normalize_source_binding(explicit_binding),
         :ok <- reject_uncompiled_concrete_binding(binding),
         :ok <- require_source_binding_id(binding),
         :ok <- require_source_adapter_ref(binding) do
      {:ok, Map.put_new(binding, :installation_id, installation_id(context, binding))}
    end
  end

  defp normalize_source_binding(%_{} = struct), do: {:ok, Map.from_struct(struct)}
  defp normalize_source_binding(%{} = binding), do: {:ok, Map.new(binding)}
  defp normalize_source_binding(binding) when is_list(binding), do: {:ok, Map.new(binding)}
  defp normalize_source_binding(_missing), do: {:error, :missing_source_binding}

  defp reject_uncompiled_concrete_binding(binding) do
    if concrete_binding_data?(binding) and not compiled_binding_snapshot?(binding) do
      {:error, :concrete_source_binding_requires_compiled_snapshot}
    else
      :ok
    end
  end

  defp concrete_binding_data?(binding) do
    present?(value(binding, :provider)) or
      present?(value(binding, :operation_id)) or
      present?(value(binding, :capability_id)) or
      is_map(value(binding, :binding))
  end

  defp compiled_binding_snapshot?(binding) do
    truthy?(value(binding, :compiled_binding?)) or
      present?(value(binding, :compiled_binding_ref)) or
      present?(value(binding, :binding_snapshot_ref)) or
      present?(value(binding, :binding_set_id)) or
      present?(value(binding, :binding_epoch))
  end

  defp require_source_binding_id(binding) do
    if present?(value(binding, :source_binding_id)) or present?(value(binding, :binding_ref)) do
      :ok
    else
      {:error, :missing_source_binding_id}
    end
  end

  defp require_source_adapter_ref(binding) do
    if present?(value(binding, :adapter_ref)) or present?(value(binding, :source_adapter_ref)) or
         is_atom(value(binding, :adapter_module)) do
      :ok
    else
      {:error, :missing_source_adapter_ref}
    end
  end

  defp issue_ids(request) do
    request
    |> value(:issue_ids)
    |> List.wrap()
    |> Enum.filter(&is_binary/1)
    |> Enum.reject(&(&1 == ""))
    |> case do
      [] -> {:error, :missing_source_current_state_ids}
      ids -> {:ok, ids}
    end
  end

  defp source_allowed_operations(source_role_ref, source_binding, opts) do
    explicit_operations =
      Keyword.get(opts, :allowed_operations) || value(source_binding, :allowed_operations)

    cond do
      is_list(explicit_operations) and explicit_operations != [] ->
        explicit_operations

      service_exports?(integration_bridge_service(opts), :source_read_allowed_operations, 3) ->
        integration_bridge_service(opts).source_read_allowed_operations(
          source_role_ref,
          source_binding,
          opts
        )

      true ->
        []
    end
  end

  defp source_publication_allowed_operations(publication_role_ref, source_binding, attrs, opts) do
    explicit_operations =
      Keyword.get(opts, :allowed_operations) ||
        value(attrs, :allowed_operations) ||
        value(source_binding, :allowed_operations)

    cond do
      is_list(explicit_operations) and explicit_operations != [] ->
        explicit_operations

      service_exports?(
        integration_bridge_service(opts),
        :source_publication_allowed_operations,
        4
      ) ->
        integration_bridge_service(opts).source_publication_allowed_operations(
          publication_role_ref,
          source_binding,
          attrs,
          opts
        )

      true ->
        []
    end
  end

  defp source_envelope(%RequestContext{} = context, source_page, binding) do
    tenant_id = context.tenant_ref.id
    installation_id = value(binding, :installation_id) || installation_id(context, binding)

    %{
      tenant_id: tenant_id,
      installation_id: installation_id,
      source_binding_id: value(binding, :source_binding_id) || value(binding, :binding_ref),
      authorization_scope: %{"tenant_id" => tenant_id},
      trace_id: context.trace_id,
      causation_id: context.causation_id || context.idempotency_key || context.trace_id,
      actor_ref: actor_ref(context),
      viewer: value(source_page, :viewer)
    }
    |> compact_map()
  end

  defp page_output(source_page) do
    %{
      issues: source_page |> value(:issues) |> List.wrap(),
      page_info: value(source_page, :page_info) || %{},
      auth_binding: value(source_page, :auth_binding) || %{}
    }
  end

  defp ingest_subject_attrs(subject_attrs, route, opts) do
    Enum.reduce_while(subject_attrs, {:ok, [], []}, fn attrs, {:ok, ingested, skipped} ->
      case ingest_subject_attr(attrs, route, opts) do
        :skip -> {:cont, {:ok, ingested, [attrs | skipped]}}
        {:ok, subject} -> {:cont, {:ok, [subject | ingested], skipped}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, ingested, skipped} -> {:ok, Enum.reverse(ingested), Enum.reverse(skipped)}
      error -> error
    end
  end

  defp ingest_subject_attr(%{lifecycle_state: "ignored"}, _route, _opts), do: :skip

  defp ingest_subject_attr(attrs, route, opts) do
    with {:ok, subject} <- WorkQueryService.ingest_subject(work_attrs(attrs, route), opts),
         {:ok, subject_ref} <-
           SubjectRef.new(%{id: subject.subject_id, subject_kind: "work_object"}) do
      {:ok,
       %{
         subject_ref: subject_ref,
         subject_id: subject.subject_id,
         title: subject.title,
         payload: source_payload(attrs)
       }}
    end
  end

  defp work_attrs(attrs, route) do
    %{
      tenant_id: route.tenant_id,
      program_id: route.program_id,
      work_class_id: route.work_class_id,
      external_ref: attrs.source_ref,
      title: attrs.title || attrs.source_ref,
      description: attrs.description,
      priority: attrs.priority || 50,
      source_kind: attrs.provider || "linear",
      payload: source_payload(attrs),
      normalized_payload: normalized_source_payload(attrs)
    }
  end

  defp source_payload(attrs) do
    %{
      external_ref: attrs.source_ref,
      source_ref: attrs.source_ref,
      source_binding_id: attrs.source_binding_id,
      provider: attrs.provider,
      provider_external_ref: attrs.provider_external_ref,
      provider_revision: attrs.provider_revision,
      source_state: attrs.source_state,
      state_mapping: attrs.state_mapping || %{},
      blocker_refs: attrs.blocker_refs || [],
      pre_dispatch_revalidation: value(attrs, :pre_dispatch_revalidation),
      labels: attrs.labels || [],
      branch_ref: attrs.branch_ref,
      source_url: attrs.source_url,
      source_routing: attrs.source_routing || %{},
      issue: attrs.payload || %{}
    }
    |> compact_map()
  end

  defp normalized_source_payload(attrs) do
    attrs
    |> Map.new()
    |> Map.put(:payload, source_payload(attrs))
  end

  defp installation_id(%RequestContext{installation_ref: %{id: id}}, _binding)
       when is_binary(id) and id != "",
       do: id

  defp installation_id(%RequestContext{tenant_ref: %{id: tenant_id}}, binding) do
    value(binding, :installation_id) || tenant_id
  end

  defp actor_ref(%RequestContext{} = context) do
    %{
      "kind" => context.actor_ref.kind |> to_string(),
      "id" => context.actor_ref.id,
      "tenant_id" => context.tenant_ref.id
    }
  end

  defp value(%_{} = struct, key), do: struct |> Map.from_struct() |> value(key)
  defp value(%{} = map, key), do: Map.get(map, key) || Map.get(map, Atom.to_string(key))
  defp value(_map, _key), do: nil

  defp present?(value) when is_binary(value), do: String.trim(value) != ""
  defp present?(value), do: not is_nil(value) and value != false

  defp truthy?(value), do: value in [true, "true", 1, "1"]

  defp compact_map(map) do
    map
    |> Enum.reject(fn {_key, value} -> value in [nil, "", [], %{}] end)
    |> Map.new()
  end

  defp program_context_service(opts),
    do: Keyword.get(opts, :program_context_service, ProgramContextService)

  defp integration_bridge_service(opts),
    do: Keyword.get(opts, :integration_bridge_service, IntegrationBridge)

  defp authorized_invocation(opts) do
    case Keyword.get(opts, :authorized_invocation) || Keyword.get(opts, :invocation) do
      %AuthorizedInvocation{} = invocation -> {:ok, invocation}
      nil -> {:error, :missing_authorized_source_invocation}
      _other -> {:error, :invalid_authorized_source_invocation}
    end
  end

  defp authorized_invocation(%RequestContext{} = context, allowed_operations, subject_hint, opts) do
    case authorized_invocation(opts) do
      {:ok, %AuthorizedInvocation{} = invocation} ->
        {:ok, invocation, opts}

      {:error, :missing_authorized_source_invocation} ->
        prepare_connection_invocation(context, allowed_operations, subject_hint, opts)

      {:error, reason} ->
        {:error, reason}
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
          {:ok, invocation, merge_prepared_source_opts(opts, prepared)}
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
      {:ok, invocation, merge_prepared_source_opts(opts, prepared)}
    else
      {:error, reason} -> {:error, reason}
      _other -> {:error, :invalid_prepared_credential_invocation}
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

      true ->
        ephemeral_secret_source(opts)
    end
  end

  defp ephemeral_secret_source(opts) do
    case Keyword.get(opts, :api_key) do
      api_key when is_binary(api_key) and api_key != "" ->
        {:ok,
         %{
           secret_source_ref: :ephemeral,
           secret_scope: %{provider_ref: "ephemeral://app-kit-source", secret_key: :api_key},
           secret_opts: [
             secret_materializer: fn -> %{api_key: api_key} end
           ]
         }}

      _missing ->
        {:error, :missing_authorized_source_invocation}
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
    trace_id = context.trace_id || "trace-app-kit-source"

    execution_id =
      Keyword.get(opts, :execution_id) || "exec-app-kit-source-#{stable_hash(trace_id)}"

    idempotency_key =
      context.idempotency_key || Keyword.get(opts, :idempotency_key) || execution_id

    %{
      tenant_id: context.tenant_ref.id,
      installation_id: installation_id(context, %{}),
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

  defp merge_prepared_source_opts(opts, prepared) do
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
      :api_key,
      :credential_secret_provider,
      :credential_secret_scope,
      :credential_secret_opts,
      :credential_env_var
    ]
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

  defp service_exports?(service, function, arity) when is_atom(service) do
    Code.ensure_loaded?(service) and function_exported?(service, function, arity)
  end

  defp stable_hash(value), do: value |> :erlang.phash2() |> Integer.to_string(36)
end
