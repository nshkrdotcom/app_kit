defmodule AppKit.Bridges.MezzanineBridge.InstallationAdapter do
  @moduledoc """
  Installation backend adapter for the Mezzanine bridge.
  """

  @behaviour AppKit.Core.Backends.InstallationBackend

  alias AppKit.Bridges.MezzanineBridge.{
    ActionMapping,
    Common,
    Errors,
    InstallationMapping,
    Services,
    WorkContext
  }

  alias AppKit.Core.{
    AuthoringBundleImport,
    InstallationRef,
    InstallTemplate,
    PageRequest,
    RequestContext
  }

  @impl true
  def create_installation(%RequestContext{} = context, %InstallTemplate{} = template, opts)
      when is_list(opts) do
    with {:ok, tenant_id} <- WorkContext.tenant_id(context),
         attrs <- InstallationMapping.install_template_attrs(template, tenant_id, context),
         {:ok, bridge_result} <- Services.installation(opts).create_installation(attrs, opts),
         {:ok, install_result} <- InstallationMapping.install_result_from_bridge(bridge_result) do
      {:ok, install_result}
    else
      {:error, reason} -> Errors.normalize(reason)
    end
  end

  @impl true
  def import_authoring_bundle(
        %RequestContext{} = context,
        %AuthoringBundleImport{} = bundle_import,
        opts
      )
      when is_list(opts) do
    with {:ok, tenant_id} <- WorkContext.tenant_id(context),
         attrs <- InstallationMapping.authoring_bundle_attrs(bundle_import, tenant_id),
         {:ok, bridge_result} <- Services.installation(opts).import_authoring_bundle(attrs, opts),
         {:ok, install_result} <- InstallationMapping.install_result_from_bridge(bridge_result) do
      {:ok, install_result}
    else
      {:error, reason} -> Errors.normalize(reason)
    end
  end

  @impl true
  def get_installation(%RequestContext{} = _context, %InstallationRef{} = installation_ref, opts)
      when is_list(opts) do
    with {:ok, detail} <- Services.installation(opts).get_installation(installation_ref.id, opts),
         {:ok, normalized_ref} <- InstallationMapping.installation_ref_from_detail(detail) do
      {:ok, normalized_ref}
    else
      {:error, reason} -> Errors.normalize(reason)
    end
  end

  @impl true
  def update_bindings(
        %RequestContext{} = _context,
        %InstallationRef{} = installation_ref,
        bindings,
        opts
      )
      when is_list(bindings) and is_list(opts) do
    with {:ok, bridge_result} <-
           Services.installation(opts).update_bindings(
             installation_ref.id,
             InstallationMapping.binding_config(bindings),
             opts
           ),
         {:ok, action_result} <- ActionMapping.action_result_from_bridge(bridge_result) do
      {:ok, action_result}
    else
      {:error, reason} -> Errors.normalize(reason)
    end
  end

  @impl true
  def list_installations(%RequestContext{} = context, %PageRequest{} = page_request, opts)
      when is_list(opts) do
    with {:ok, tenant_id} <- WorkContext.tenant_id(context),
         {:ok, rows} <-
           Services.installation(opts).list_installations(
             tenant_id,
             InstallationMapping.installation_filters(page_request.filters),
             opts
           ),
         {:ok, entries} <-
           Common.map_each(rows, &InstallationMapping.installation_ref_from_detail/1),
         {:ok, page_result} <- Common.page_result(entries, page_request) do
      {:ok, page_result}
    else
      {:error, reason} -> Errors.normalize(reason)
    end
  end

  @impl true
  def suspend_installation(
        %RequestContext{} = _context,
        %InstallationRef{} = installation_ref,
        opts
      )
      when is_list(opts) do
    with {:ok, bridge_result} <-
           Services.installation(opts).suspend_installation(installation_ref.id, opts),
         {:ok, action_result} <- ActionMapping.action_result_from_bridge(bridge_result) do
      {:ok, action_result}
    else
      {:error, reason} -> Errors.normalize(reason)
    end
  end

  @impl true
  def reactivate_installation(
        %RequestContext{} = _context,
        %InstallationRef{} = installation_ref,
        opts
      )
      when is_list(opts) do
    with {:ok, bridge_result} <-
           Services.installation(opts).reactivate_installation(installation_ref.id, opts),
         {:ok, action_result} <- ActionMapping.action_result_from_bridge(bridge_result) do
      {:ok, action_result}
    else
      {:error, reason} -> Errors.normalize(reason)
    end
  end
end
