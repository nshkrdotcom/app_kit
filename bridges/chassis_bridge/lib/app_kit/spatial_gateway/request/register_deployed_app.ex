defmodule AppKit.SpatialGateway.Request.RegisterDeployedApp do
  @moduledoc "Request to register a product deployment with Chassis."
  @enforce_keys [:app_atom, :git_sha]
  defstruct [:app_atom, :git_sha]
end
