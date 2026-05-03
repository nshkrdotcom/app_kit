defmodule AppKit.BackendConfigTest do
  use ExUnit.Case, async: false

  alias AppKit.BackendConfig

  defmodule AppEnvBackend, do: nil
  defmodule AppEnvRuntime, do: nil
  defmodule DefaultBackend, do: nil
  defmodule ExplicitBackend, do: nil

  setup do
    previous_backend = Application.get_env(:app_kit_core, :work_backend, :unset)
    previous_runtime = Application.get_env(:app_kit_core, :agent_runtime, :unset)

    Application.put_env(:app_kit_core, :work_backend, AppEnvBackend)
    Application.put_env(:app_kit_core, :agent_runtime, AppEnvRuntime)

    on_exit(fn ->
      restore_env(:work_backend, previous_backend)
      restore_env(:agent_runtime, previous_runtime)
    end)

    :ok
  end

  test "standalone compatibility can still resolve backend from application env" do
    assert BackendConfig.resolve([], :work_backend, :work_backend, DefaultBackend) ==
             AppEnvBackend
  end

  test "governed calls ignore application env backend fallback" do
    assert BackendConfig.resolve([governed?: true], :work_backend, :work_backend, DefaultBackend) ==
             DefaultBackend

    assert BackendConfig.resolve(
             [authority_context_ref: "authority-context://one"],
             :work_backend,
             :work_backend,
             DefaultBackend
           ) == DefaultBackend
  end

  test "explicit governed backend selection wins over application env" do
    assert BackendConfig.resolve(
             [governed?: true, work_backend: ExplicitBackend],
             :work_backend,
             :work_backend,
             DefaultBackend
           ) == ExplicitBackend
  end

  test "optional runtimes fail closed for governed calls without explicit runtime" do
    assert BackendConfig.resolve_optional([], :agent_loop_runtime, :agent_runtime) ==
             AppEnvRuntime

    assert BackendConfig.resolve_optional(
             [authority_packet_ref: "authority-packet://one"],
             :agent_loop_runtime,
             :agent_runtime
           ) == nil

    assert BackendConfig.resolve_optional(
             [governed?: true, agent_loop_runtime: ExplicitBackend],
             :agent_loop_runtime,
             :agent_runtime
           ) == ExplicitBackend
  end

  defp restore_env(key, :unset), do: Application.delete_env(:app_kit_core, key)
  defp restore_env(key, value), do: Application.put_env(:app_kit_core, key, value)
end
