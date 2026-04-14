defmodule AppKit.WorkControl do
  @moduledoc """
  Reusable governed-run and work-submission helpers.
  """

  alias AppKit.Core.Result

  @spec start_run(map(), keyword()) :: {:ok, Result.t()} | {:error, atom()}
  def start_run(domain_call, opts \\ []) when is_map(domain_call) do
    backend(opts).start_run(domain_call, opts)
  end

  defp backend(opts) do
    Keyword.get(opts, :work_backend) ||
      Application.get_env(:app_kit, :work_backend, AppKit.WorkControl.DefaultBackend)
  end
end
