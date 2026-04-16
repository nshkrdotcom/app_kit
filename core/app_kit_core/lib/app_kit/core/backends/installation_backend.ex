defmodule AppKit.Core.Backends.InstallationBackend do
  @moduledoc """
  Frozen northbound backend contract for installation lifecycle operations.
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

  @callback create_installation(RequestContext.t(), InstallTemplate.t(), keyword()) ::
              {:ok, InstallResult.t()} | {:error, SurfaceError.t()}

  @callback get_installation(RequestContext.t(), InstallationRef.t(), keyword()) ::
              {:ok, InstallationRef.t()} | {:error, SurfaceError.t()}

  @callback update_bindings(
              RequestContext.t(),
              InstallationRef.t(),
              [InstallationBinding.t()],
              keyword()
            ) ::
              {:ok, ActionResult.t()} | {:error, SurfaceError.t()}

  @callback list_installations(RequestContext.t(), PageRequest.t(), keyword()) ::
              {:ok, PageResult.t()} | {:error, SurfaceError.t()}

  @callback suspend_installation(RequestContext.t(), InstallationRef.t(), keyword()) ::
              {:ok, ActionResult.t()} | {:error, SurfaceError.t()}

  @callback reactivate_installation(RequestContext.t(), InstallationRef.t(), keyword()) ::
              {:ok, ActionResult.t()} | {:error, SurfaceError.t()}
end
