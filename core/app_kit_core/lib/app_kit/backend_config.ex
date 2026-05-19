defmodule AppKit.BackendConfig do
  @moduledoc """
  Backend resolver for AppKit surfaces.

  Calls must pass explicit backends, pass an `AppKit.BackendStack`, or use the
  compiled default backend so process config cannot choose AppKit bridge or
  operator behavior.
  """

  @governed_markers [
    :governed?,
    :authority_context,
    :authority_context_ref,
    :authority_materialization,
    :authority_packet_ref,
    :authority_ref
  ]

  @type backend :: term()

  @spec resolve(keyword(), atom(), atom(), backend()) :: backend()
  def resolve(opts, explicit_key, app_env_key, default_backend)
      when is_list(opts) and is_atom(explicit_key) and is_atom(app_env_key) do
    case Keyword.fetch(opts, explicit_key) do
      {:ok, backend} -> backend
      :error -> fallback(opts, app_env_key, default_backend)
    end
  end

  @spec resolve_optional(keyword(), atom(), atom()) :: backend()
  def resolve_optional(opts, explicit_key, app_env_key)
      when is_list(opts) and is_atom(explicit_key) and is_atom(app_env_key) do
    resolve(opts, explicit_key, app_env_key, nil)
  end

  @spec governed?(keyword()) :: boolean()
  def governed?(opts) when is_list(opts) do
    Enum.any?(@governed_markers, fn
      :governed? -> Keyword.get(opts, :governed?, false) == true
      marker -> Keyword.has_key?(opts, marker)
    end)
  end

  defp fallback(opts, app_env_key, default_backend) do
    case fetch_stack_backend(opts, app_env_key) do
      {:ok, backend} ->
        backend

      :error ->
        default_backend
    end
  end

  defp fetch_stack_backend(opts, app_env_key) do
    opts
    |> backend_stacks()
    |> Enum.reduce_while(:error, fn stack, :error ->
      case AppKit.BackendStack.fetch(stack, app_env_key) do
        {:ok, backend} -> {:halt, {:ok, backend}}
        :error -> {:cont, :error}
      end
    end)
  end

  defp backend_stacks(opts) do
    [
      Keyword.get(opts, :backend_stack),
      Keyword.get(opts, :app_kit_backend_stack)
    ]
    |> Enum.filter(&match?(%AppKit.BackendStack{}, &1))
  end
end
