defmodule AppKit.InstallationSurfaceTest do
  use ExUnit.Case, async: true

  defmodule FakeInstallationBackend do
    @behaviour AppKit.Core.Backends.InstallationBackend

    alias AppKit.Core.{
      ActionResult,
      InstallationRef,
      InstallResult,
      PageRequest,
      PageResult,
      RequestContext
    }

    @impl true
    def create_installation(%RequestContext{} = _context, template, _opts) do
      InstallResult.new(%{
        installation_ref: %{id: "inst-1", pack_slug: template.pack_slug, status: :active},
        status: :created,
        message: "created"
      })
    end

    @impl true
    def get_installation(
          %RequestContext{} = _context,
          %InstallationRef{} = installation_ref,
          _opts
        ) do
      {:ok, installation_ref}
    end

    @impl true
    def update_bindings(
          %RequestContext{} = _context,
          %InstallationRef{} = installation_ref,
          _bindings,
          _opts
        ) do
      ActionResult.new(%{
        status: :completed,
        action_ref: %{id: "#{installation_ref.id}:update", action_kind: "update_bindings"},
        message: "updated",
        metadata: %{backend: :fake}
      })
    end

    @impl true
    def list_installations(%RequestContext{} = _context, %PageRequest{} = _page_request, _opts) do
      with {:ok, installation_ref} <-
             InstallationRef.new(%{
               id: "inst-1",
               pack_slug: "expense_approval",
               status: :active
             }) do
        PageResult.new(%{
          entries: [installation_ref],
          total_count: 1,
          has_more: false,
          metadata: %{backend: :fake}
        })
      end
    end

    @impl true
    def suspend_installation(
          %RequestContext{} = _context,
          %InstallationRef{} = installation_ref,
          _opts
        ) do
      ActionResult.new(%{
        status: :completed,
        action_ref: %{id: "#{installation_ref.id}:suspend", action_kind: "suspend_installation"},
        message: "suspended",
        metadata: %{backend: :fake}
      })
    end

    @impl true
    def reactivate_installation(
          %RequestContext{} = _context,
          %InstallationRef{} = installation_ref,
          _opts
        ) do
      ActionResult.new(%{
        status: :completed,
        action_ref: %{
          id: "#{installation_ref.id}:reactivate",
          action_kind: "reactivate_installation"
        },
        message: "reactivated",
        metadata: %{backend: :fake}
      })
    end
  end

  alias AppKit.Core.{
    InstallationBinding,
    InstallationRef,
    InstallTemplate,
    PageRequest,
    RequestContext
  }

  alias AppKit.InstallationSurface

  test "delegates installation lifecycle flows" do
    context = request_context()

    assert {:ok, template} =
             InstallTemplate.new(%{
               template_key: "expense/default",
               pack_slug: "expense_approval",
               pack_version: "1.0.0"
             })

    assert {:ok, install_result} =
             InstallationSurface.create_installation(
               context,
               template,
               installation_backend: FakeInstallationBackend
             )

    assert {:ok, installation_ref} =
             InstallationRef.new(%{
               id: "inst-1",
               pack_slug: "expense_approval",
               status: :active
             })

    assert {:ok, fetched_ref} =
             InstallationSurface.get_installation(
               context,
               installation_ref,
               installation_backend: FakeInstallationBackend
             )

    assert {:ok, binding} =
             InstallationBinding.new(%{
               binding_key: "expense_capture",
               binding_kind: :execution,
               config: %{"placement_ref" => "local_runner"}
             })

    assert {:ok, update_result} =
             InstallationSurface.update_bindings(
               context,
               installation_ref,
               [binding],
               installation_backend: FakeInstallationBackend
             )

    assert {:ok, page_request} = PageRequest.new(%{limit: 10})

    assert {:ok, list_result} =
             InstallationSurface.list_installations(
               context,
               page_request,
               installation_backend: FakeInstallationBackend
             )

    assert {:ok, suspend_result} =
             InstallationSurface.suspend_installation(
               context,
               installation_ref,
               installation_backend: FakeInstallationBackend
             )

    assert {:ok, reactivate_result} =
             InstallationSurface.reactivate_installation(
               context,
               installation_ref,
               installation_backend: FakeInstallationBackend
             )

    assert install_result.installation_ref.id == "inst-1"
    assert fetched_ref.id == "inst-1"
    assert update_result.metadata.backend == :fake
    assert list_result.metadata.backend == :fake
    assert suspend_result.metadata.backend == :fake
    assert reactivate_result.metadata.backend == :fake
  end

  defp request_context do
    {:ok, context} =
      RequestContext.new(%{
        trace_id: "trace-install-surface",
        actor_ref: %{id: "installer-1", kind: :human},
        tenant_ref: %{id: "tenant-1"}
      })

    context
  end
end
