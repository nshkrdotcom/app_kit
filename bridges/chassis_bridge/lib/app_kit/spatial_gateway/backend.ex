defmodule AppKit.SpatialGateway.Backend do
  @moduledoc "Adapter behaviour for AppKit.SpatialGateway dispatch."

  alias AppKit.SpatialGateway.Request

  @type request ::
          %Request.GetActiveProfile{}
          | %Request.RegisterDeployedApp{}
          | %Request.GetHealthStatus{}
          | %Request.TriggerRollback{}

  @callback handle(request(), keyword()) :: {:ok, term()} | {:error, term()}
end
