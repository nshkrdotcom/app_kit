defmodule AppKit.ChatSurface do
  @moduledoc """
  Host-facing chat entrypoints above the conversation and outer-brain bridges.
  """

  alias AppKit.AppConfig
  alias AppKit.ConversationBridge
  alias AppKit.ScopeObjects.HostScope

  @spec submit_turn(HostScope.t(), String.t(), keyword()) ::
          {:ok, AppKit.Core.Result.t()} | {:error, atom()}
  def submit_turn(%HostScope{} = scope, text, opts \\ []) do
    with {:ok, config} <- AppConfig.normalize(Keyword.get(opts, :config)),
         true <- config.chat_surface?,
         {:ok, result} <- ConversationBridge.compose_follow_up(scope, text, opts) do
      {:ok, %{result | meta: Map.put(result.meta, :review_mode, config.review_mode)}}
    else
      false -> {:error, :chat_surface_disabled}
      {:error, reason} -> {:error, reason}
    end
  end
end
