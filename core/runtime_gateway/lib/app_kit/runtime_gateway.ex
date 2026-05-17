defmodule AppKit.RuntimeGateway do
  @moduledoc """
  App-facing runtime gateway descriptors above lower runtime mechanics.
  """

  alias AppKit.Core.{Context, GenericSurfaceSupport}
  alias AppKit.ScopeObjects.ManagedTarget

  @backend_key :generic_backend

  @enforce_keys [:target, :mode, :transport]
  defstruct [:target, :mode, :transport]

  @type t :: %__MODULE__{
          target: ManagedTarget.t(),
          mode: :attached | :detached,
          transport: :session | :job
        }

  @spec open(ManagedTarget.t(), keyword()) :: {:ok, t()} | {:error, atom()}
  def open(%ManagedTarget{} = target, opts \\ []) do
    mode = Keyword.get(opts, :mode, :attached)
    transport = Keyword.get(opts, :transport, :session)

    if mode in [:attached, :detached] and transport in [:session, :job] do
      {:ok, %__MODULE__{target: target, mode: mode, transport: transport}}
    else
      {:error, :invalid_runtime_gateway}
    end
  end

  def invoke_runtime_operation(
        %Context{} = context,
        runtime_role_ref,
        operation_role_ref,
        request,
        opts \\ []
      ) do
    GenericSurfaceSupport.dispatch(opts, @backend_key, :invoke_runtime_operation, [
      context,
      runtime_role_ref,
      operation_role_ref,
      request
    ])
  end

  def invoke_runtime_tool(
        %Context{} = context,
        tool_role_ref,
        operation_role_ref,
        request,
        opts \\ []
      ) do
    GenericSurfaceSupport.dispatch(opts, @backend_key, :invoke_runtime_tool, [
      context,
      tool_role_ref,
      operation_role_ref,
      request
    ])
  end

  def collect_evidence(%Context{} = context, evidence_role_ref, request, opts \\ []) do
    GenericSurfaceSupport.dispatch(opts, @backend_key, :collect_evidence, [
      context,
      evidence_role_ref,
      request
    ])
  end

  def invoke_resource_effect(%Context{} = context, resource_effect_role_ref, request, opts \\ []) do
    GenericSurfaceSupport.dispatch(opts, @backend_key, :invoke_resource_effect, [
      context,
      resource_effect_role_ref,
      request
    ])
  end

  def get_receipt(%Context{} = context, receipt_ref, opts \\ []) do
    GenericSurfaceSupport.dispatch(opts, @backend_key, :collect_evidence, [
      context,
      :receipt_readback,
      %{receipt_ref: receipt_ref}
    ])
  end
end
