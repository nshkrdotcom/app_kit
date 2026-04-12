defmodule AppKit.Bridges.ProjectionBridge do
  @moduledoc """
  App-facing bridge for operator-facing projection reads.
  """

  alias AppKit.Core.RunRef
  alias AppKit.ScopeObjects

  @spec operator_projection(RunRef.t(), map()) :: {:ok, map()} | {:error, atom()}
  def operator_projection(%RunRef{} = run_ref, attrs) when is_map(attrs) do
    with {:ok, route_status} <-
           ScopeObjects.route_status(%{
             route_name: Map.get(attrs, :route_name, :unknown),
             state: Map.get(attrs, :state, :pending),
             details: Map.get(attrs, :details, %{})
           }) do
      {:ok,
       %{
         run_id: run_ref.run_id,
         route_status: route_status,
         last_event: Map.get(attrs, :last_event, :none)
       }}
    end
  end
end
