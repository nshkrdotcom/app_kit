defmodule AppKit.ConversationBridge do
  @moduledoc """
  Reusable follow-up and live-update helpers above the outer brain seam.
  """

  alias AppKit.Bridges.OuterBrainBridge
  alias AppKit.Bridges.ProjectionBridge
  alias AppKit.Core.{Result, RunRef}
  alias AppKit.ScopeObjects.HostScope

  @spec compose_follow_up(HostScope.t(), String.t(), keyword()) ::
          {:ok, Result.t()} | {:error, atom()}
  def compose_follow_up(%HostScope{} = scope, text, opts \\ []) do
    with {:ok, turn} <- OuterBrainBridge.compile_turn(scope, text, opts) do
      Result.new(%{surface: :conversation, state: :accepted, payload: %{turn: turn}})
    end
  end

  @spec live_update(RunRef.t(), map()) :: {:ok, map()} | {:error, atom()}
  def live_update(%RunRef{} = run_ref, attrs) do
    ProjectionBridge.operator_projection(run_ref, attrs)
  end
end
