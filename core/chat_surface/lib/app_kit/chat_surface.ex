defmodule AppKit.ChatSurface do
  @moduledoc """
  Host-facing chat entrypoints above the conversation and outer-brain bridges.
  """

  alias AppKit.AgentIntake
  alias AppKit.AppConfig
  alias AppKit.ConversationBridge
  alias AppKit.Core.AgentIntake.TurnSubmission
  alias AppKit.Core.Result
  alias AppKit.Core.RuntimeReadback.CommandResult
  alias AppKit.ScopeObjects.HostScope

  @spec submit_turn(HostScope.t(), String.t(), keyword()) ::
          {:ok, AppKit.Core.Result.t()} | {:error, atom()}
  def submit_turn(%HostScope{} = scope, text, opts \\ []) do
    with {:ok, config} <- AppConfig.normalize(Keyword.get(opts, :config)),
         true <- config.chat_surface?,
         {:ok, result} <- submit_turn_backend(scope, text, opts) do
      {:ok, %{result | meta: Map.put(result.meta, :review_mode, config.review_mode)}}
    else
      false -> {:error, :chat_surface_disabled}
      {:error, reason} -> {:error, reason}
    end
  end

  defp submit_turn_backend(%HostScope{} = scope, text, opts) do
    if Keyword.has_key?(opts, :agent_intake_payload_ref) do
      with {:ok, context} <- Keyword.fetch(opts, :request_context),
           {:ok, run_ref} <- Keyword.fetch(opts, :agent_run_ref),
           {:ok, payload_ref} <- Keyword.fetch(opts, :agent_intake_payload_ref),
           {:ok, actor_ref} <- Keyword.fetch(opts, :actor_ref),
           {:ok, idempotency_key} <- Keyword.fetch(opts, :idempotency_key),
           {:ok, submission} <-
             TurnSubmission.new(%{
               idempotency_key: idempotency_key,
               actor_ref: actor_ref,
               run_ref: run_ref,
               kind: Keyword.get(opts, :turn_kind, :user_input),
               payload_ref: payload_ref,
               params: Keyword.get(opts, :agent_intake_params, %{})
             }),
           {:ok, command_result} <- AgentIntake.submit_turn(context, submission, opts) do
        Result.new(%{
          surface: :chat,
          state: :accepted,
          payload: %{"agent_command" => CommandResult.dump(command_result)}
        })
      else
        :error -> {:error, :missing_agent_intake_option}
        {:error, reason} -> {:error, reason}
      end
    else
      ConversationBridge.compose_follow_up(scope, text, opts)
    end
  end
end
