defmodule AppKit.Bridges.MezzanineBridge.Services do
  @moduledoc false

  def source(opts),
    do: Keyword.get(opts, :source_service, Mezzanine.AppKitBridge.SourceService)

  def work_query(opts),
    do: Keyword.get(opts, :work_query_service, Mezzanine.AppKitBridge.WorkQueryService)

  def work_control(opts),
    do: Keyword.get(opts, :work_control_service, Mezzanine.AppKitBridge.WorkControlService)

  def review_query(opts),
    do: Keyword.get(opts, :review_query_service, Mezzanine.AppKitBridge.ReviewQueryService)

  def review_action(opts),
    do: Keyword.get(opts, :review_action_service, Mezzanine.AppKitBridge.ReviewActionService)

  def installation(opts),
    do: Keyword.get(opts, :installation_service, Mezzanine.AppKitBridge.InstallationService)

  def runtime_profile(opts),
    do: Keyword.get(opts, :runtime_profile_service, Mezzanine.AppKitBridge.RuntimeProfileService)

  def runtime_gateway(opts),
    do: Keyword.get(opts, :runtime_gateway_service, Mezzanine.AppKitBridge.RuntimeGatewayService)

  def program_context(opts),
    do: Keyword.get(opts, :program_context_service, Mezzanine.AppKitBridge.ProgramContextService)

  def operator_query(opts),
    do: Keyword.get(opts, :operator_query_service, Mezzanine.AppKitBridge.OperatorQueryService)

  def operator_action(opts),
    do: Keyword.get(opts, :operator_action_service, Mezzanine.AppKitBridge.OperatorActionService)

  def exports?(service, function_name, arity)
      when is_atom(service) and is_atom(function_name) and is_integer(arity) do
    match?({:module, ^service}, Code.ensure_loaded(service)) and
      function_exported?(service, function_name, arity)
  end

  def exports?(_service, _function_name, _arity), do: false
end
