defmodule AppKit.SpatialGateway.Request.TriggerRollback do
  @moduledoc "Request to trigger a Chassis rollback."
  @enforce_keys [:previous_receipt_ref]
  defstruct [:previous_receipt_ref]
end
