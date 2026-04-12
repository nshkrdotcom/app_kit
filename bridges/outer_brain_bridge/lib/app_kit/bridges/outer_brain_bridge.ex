defmodule AppKit.Bridges.OuterBrainBridge do
  @moduledoc """
  App-facing bridge for semantic-turn compilation above the outer brain.
  """

  alias AppKit.ScopeObjects.HostScope

  @spec compile_turn(HostScope.t(), String.t(), keyword()) :: {:ok, map()} | {:error, atom()}
  def compile_turn(%HostScope{} = scope, text, opts \\ []) when is_binary(text) do
    trimmed = String.trim(text)

    if trimmed == "" do
      {:error, :blank_turn}
    else
      {:ok,
       %{
         session_id: scope.scope_id,
         actor_id: scope.actor_id,
         turn: trimmed,
         strategy: Keyword.get(opts, :strategy, :default),
         follow_up_mode: Keyword.get(opts, :follow_up_mode, :auto)
       }}
    end
  end
end
