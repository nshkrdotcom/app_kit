defmodule AppKit.Bridges.MezzanineBridge.Services do
  @moduledoc false

  def source(opts),
    do: Keyword.get(opts, :source_service, Mezzanine.AppKitBridge.SourceService)

  def exports?(service, function_name, arity)
      when is_atom(service) and is_atom(function_name) and is_integer(arity) do
    match?({:module, ^service}, Code.ensure_loaded(service)) and
      function_exported?(service, function_name, arity)
  end

  def exports?(_service, _function_name, _arity), do: false
end
