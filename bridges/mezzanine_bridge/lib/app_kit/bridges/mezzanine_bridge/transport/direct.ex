defmodule AppKit.Bridges.MezzanineBridge.Transport.Direct do
  @moduledoc """
  In-process Mezzanine transport for monolith mode.

  The target facade is supplied explicitly through `:target` or `:module`.
  This keeps runtime authority out of ambient application environment.
  """

  @behaviour AppKit.Bridges.MezzanineBridge.Transport

  @impl true
  def submit_work(request, opts) when is_map(request) and is_list(opts) do
    call(opts, :submit_work, [request, opts])
  end

  @impl true
  def readback(ref, opts) when is_binary(ref) and is_list(opts) do
    call(opts, :readback, [ref, opts])
  end

  defp call(opts, callback, args) do
    with {:ok, target} <- fetch_target(opts),
         {:ok, function} <- fetch_function(opts, callback),
         {:ok, apply_args} <- apply_args(target, function, args) do
      target
      |> apply(function, apply_args)
      |> normalize_result()
    end
  end

  defp fetch_target(opts) do
    case Keyword.get(opts, :target, Keyword.get(opts, :module)) do
      target when is_atom(target) -> {:ok, target}
      _other -> {:error, error(:missing_direct_target)}
    end
  end

  defp fetch_function(opts, callback) do
    function = Keyword.get(opts, function_option(callback), callback)

    if is_atom(function) do
      {:ok, function}
    else
      {:error, error(:invalid_direct_function)}
    end
  end

  defp apply_args(target, function, args) do
    args_without_opts = Enum.drop(args, -1)

    cond do
      function_exported?(target, function, length(args)) ->
        {:ok, args}

      function_exported?(target, function, length(args_without_opts)) ->
        {:ok, args_without_opts}

      true ->
        {:error,
         error(:direct_target_unavailable, %{
           "target" => inspect(target),
           "function" => Atom.to_string(function)
         })}
    end
  end

  defp function_option(:submit_work), do: :submit_work_function
  defp function_option(:readback), do: :readback_function

  defp normalize_result({:ok, result}) when is_map(result), do: {:ok, result}
  defp normalize_result({:error, reason}) when is_map(reason), do: {:error, reason}
  defp normalize_result(result) when is_map(result), do: {:ok, result}

  defp normalize_result(reason),
    do: {:error, error(:invalid_direct_response, %{"reason" => inspect(reason)})}

  defp error(code, attrs \\ %{}) do
    Map.merge(%{"code" => Atom.to_string(code), "transport" => "direct"}, attrs)
  end
end
