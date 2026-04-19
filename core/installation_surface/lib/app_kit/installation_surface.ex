defmodule AppKit.InstallationSurface do
  @moduledoc """
  Typed app-facing installation lifecycle surface.
  """

  alias AppKit.Core.{
    ActionResult,
    InstallationBinding,
    InstallationRef,
    InstallResult,
    InstallTemplate,
    PageRequest,
    PageResult,
    RequestContext,
    SurfaceError
  }

  @spec create_installation(RequestContext.t(), InstallTemplate.t(), keyword()) ::
          {:ok, InstallResult.t()} | {:error, SurfaceError.t()}
  def create_installation(%RequestContext{} = context, %InstallTemplate{} = template, opts \\ []) do
    backend(opts).create_installation(context, template, opts)
  end

  @spec get_installation(RequestContext.t(), InstallationRef.t(), keyword()) ::
          {:ok, InstallationRef.t()} | {:error, SurfaceError.t()}
  def get_installation(
        %RequestContext{} = context,
        %InstallationRef{} = installation_ref,
        opts \\ []
      ) do
    backend(opts).get_installation(context, installation_ref, opts)
  end

  @spec update_bindings(
          RequestContext.t(),
          InstallationRef.t(),
          [InstallationBinding.t()],
          keyword()
        ) ::
          {:ok, ActionResult.t()} | {:error, SurfaceError.t()}
  def update_bindings(
        %RequestContext{} = context,
        %InstallationRef{} = installation_ref,
        bindings,
        opts \\ []
      )
      when is_list(bindings) do
    backend(opts).update_bindings(context, installation_ref, bindings, opts)
  end

  @spec list_installations(RequestContext.t(), PageRequest.t(), keyword()) ::
          {:ok, PageResult.t()} | {:error, SurfaceError.t()}
  def list_installations(%RequestContext{} = context, %PageRequest{} = page_request, opts \\ []) do
    backend(opts).list_installations(context, page_request, opts)
  end

  @spec suspend_installation(RequestContext.t(), InstallationRef.t(), keyword()) ::
          {:ok, ActionResult.t()} | {:error, SurfaceError.t()}
  def suspend_installation(
        %RequestContext{} = context,
        %InstallationRef{} = installation_ref,
        opts \\ []
      ) do
    backend(opts).suspend_installation(context, installation_ref, opts)
  end

  @spec reactivate_installation(RequestContext.t(), InstallationRef.t(), keyword()) ::
          {:ok, ActionResult.t()} | {:error, SurfaceError.t()}
  def reactivate_installation(
        %RequestContext{} = context,
        %InstallationRef{} = installation_ref,
        opts \\ []
      ) do
    backend(opts).reactivate_installation(context, installation_ref, opts)
  end

  defp backend(opts) do
    Keyword.get(opts, :installation_backend) ||
      Application.get_env(
        :app_kit_core,
        :installation_backend,
        AppKit.Bridges.MezzanineBridge
      )
  end
end
