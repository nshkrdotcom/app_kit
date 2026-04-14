defmodule AppKit.OperatorSurface do
  @moduledoc """
  Operator-facing composition around lower review and projection reads.
  """

  alias AppKit.AppConfig
  alias AppKit.Core.RunRef

  @spec run_status(RunRef.t(), map(), keyword()) :: {:ok, map()} | {:error, atom()}
  def run_status(%RunRef{} = run_ref, attrs, opts \\ []) do
    with {:ok, config} <- AppConfig.normalize(Keyword.get(opts, :config)),
         true <- config.operator_surface? do
      backend(opts).run_status(run_ref, attrs, opts)
    else
      false -> {:error, :operator_surface_disabled}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec review_run(RunRef.t(), map(), keyword()) :: {:ok, map()} | {:error, atom()}
  def review_run(%RunRef{} = run_ref, evidence_attrs, opts \\ []) do
    with {:ok, config} <- AppConfig.normalize(Keyword.get(opts, :config)),
         true <- config.operator_surface? do
      backend(opts).review_run(run_ref, evidence_attrs, opts)
    else
      false -> {:error, :operator_surface_disabled}
      {:error, reason} -> {:error, reason}
    end
  end

  defp backend(opts) do
    Keyword.get(opts, :operator_backend) ||
      Application.get_env(:app_kit, :operator_backend, AppKit.OperatorSurface.DefaultBackend)
  end
end
