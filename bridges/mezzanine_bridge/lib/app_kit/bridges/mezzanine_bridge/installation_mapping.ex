defmodule AppKit.Bridges.MezzanineBridge.InstallationMapping do
  @moduledoc false

  alias AppKit.Bridges.MezzanineBridge.{Common, WorkContext}

  alias AppKit.Core.{
    BindingDescriptor,
    BindingEnvelope,
    BindingFailurePosture,
    BindingOwnership,
    FilterSet,
    InstallationBinding,
    InstallationRef,
    InstallResult,
    RequestContext
  }

  def install_template_attrs(template, tenant_id, %RequestContext{} = context) do
    template
    |> Map.from_struct()
    |> Map.put(:tenant_id, tenant_id)
    |> maybe_put_runtime_profile(context)
    |> Map.put_new(:metadata, %{})
  end

  def authoring_bundle_attrs(bundle_import, tenant_id) do
    bundle_import
    |> Map.from_struct()
    |> Map.put(:tenant_id, tenant_id)
  end

  def installation_filters(nil), do: %{}

  def installation_filters(%FilterSet{clauses: clauses}) do
    Enum.reduce(clauses, %{}, fn clause, acc ->
      field = Common.fetch_value(clause, :field)
      op = Common.fetch_value(clause, :op)
      value = Common.fetch_value(clause, :value)

      case {field, op, value} do
        {"status", "eq", filter_value} ->
          Map.put(acc, :status, Common.normalize_atomish(filter_value))

        {"environment", "eq", filter_value} when is_binary(filter_value) ->
          Map.put(acc, :environment, filter_value)

        {"pack_slug", "eq", filter_value} when is_binary(filter_value) ->
          Map.put(acc, :pack_slug, filter_value)

        _other ->
          acc
      end
    end)
  end

  def binding_config(bindings) do
    Enum.reduce(bindings, %{}, fn %InstallationBinding{} = binding, acc ->
      kind_key = "#{binding.binding_kind}_bindings"

      config =
        binding.config
        |> Map.new()
        |> Common.maybe_put("credential_ref", binding.credential_ref)
        |> Common.maybe_put("descriptor", serialize_binding_descriptor(binding.descriptor))

      Map.update(acc, kind_key, %{binding.binding_key => config}, fn grouped ->
        Map.put(grouped, binding.binding_key, config)
      end)
    end)
  end

  def install_result_from_bridge(bridge_result) do
    with {:ok, installation_ref} <-
           installation_ref_from_map(Common.fetch_value(bridge_result, :installation_ref)) do
      InstallResult.new(%{
        installation_ref: installation_ref,
        status: Common.fetch_value(bridge_result, :status),
        message: Common.fetch_value(bridge_result, :message),
        metadata: Common.fetch_value(bridge_result, :metadata) || %{}
      })
    end
  end

  def installation_ref_from_detail(detail) do
    installation_ref_from_map(Common.fetch_value(detail, :installation_ref))
  end

  defp installation_ref_from_map(raw_installation_ref) when is_map(raw_installation_ref) do
    InstallationRef.new(%{
      id: Common.fetch_value(raw_installation_ref, :id),
      pack_slug: Common.fetch_value(raw_installation_ref, :pack_slug),
      pack_version: Common.fetch_value(raw_installation_ref, :pack_version),
      compiled_pack_revision: Common.fetch_value(raw_installation_ref, :compiled_pack_revision),
      status: Common.normalize_atomish(Common.fetch_value(raw_installation_ref, :status))
    })
  end

  defp installation_ref_from_map(_raw_installation_ref), do: {:error, :invalid_installation_ref}

  defp maybe_put_runtime_profile(attrs, %RequestContext{} = context) do
    case WorkContext.context_metadata(context, :runtime_profile) do
      runtime_profile when is_map(runtime_profile) ->
        Map.put(attrs, :runtime_profile, runtime_profile)

      _other ->
        attrs
    end
  end

  defp serialize_binding_descriptor(nil), do: nil

  defp serialize_binding_descriptor(%BindingDescriptor{} = descriptor) do
    %{
      "attachment" => descriptor.attachment,
      "contract" => Atom.to_string(descriptor.contract),
      "envelope" => serialize_binding_envelope(descriptor.envelope),
      "failure" => serialize_binding_failure(descriptor.failure),
      "ownership" => serialize_binding_ownership(descriptor.ownership)
    }
  end

  defp serialize_binding_envelope(%BindingEnvelope{} = envelope) do
    %{
      "staleness_class" => Atom.to_string(envelope.staleness_class),
      "trace_propagation" => Atom.to_string(envelope.trace_propagation),
      "tenant_scope" => Atom.to_string(envelope.tenant_scope),
      "blast_radius" => Atom.to_string(envelope.blast_radius),
      "timeout_ms" => envelope.timeout_ms,
      "runbook_ref" => envelope.runbook_ref
    }
  end

  defp serialize_binding_failure(%BindingFailurePosture{} = failure) do
    %{
      "on_unavailable" => Atom.to_string(failure.on_unavailable),
      "on_timeout" => Atom.to_string(failure.on_timeout)
    }
  end

  defp serialize_binding_ownership(%BindingOwnership{} = ownership) do
    %{
      "external_system" => ownership.external_system,
      "external_system_ref" => ownership.external_system_ref,
      "operator_owner" => ownership.operator_owner
    }
  end
end
