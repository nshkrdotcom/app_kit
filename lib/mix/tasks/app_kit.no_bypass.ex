defmodule Mix.Tasks.AppKit.NoBypass do
  @shortdoc "Scan source files for AppKit product-boundary bypasses"

  @moduledoc """
  Scans source files for direct lower runtime/governance imports.

      mix app_kit.no_bypass --profile product --include "apps/my_product/lib/**/*.ex"
      mix app_kit.no_bypass.scan --root ../extravaganza --profile product --profile hazmat
  """

  use Mix.Task

  alias AppKit.Boundary.NoBypass

  @impl true
  def run(args) do
    {opts, _positional, invalid} =
      OptionParser.parse(args,
        strict: [root: :string, profile: :keep, include: :keep, exclude: :keep],
        aliases: [r: :root, p: :profile]
      )

    if invalid != [] do
      Mix.raise("invalid app_kit.no_bypass options: #{inspect(invalid)}")
    end

    scan_opts = [
      root: Keyword.get(opts, :root, File.cwd!()),
      profiles: Keyword.get_values(opts, :profile),
      include: include_opts(opts),
      exclude: Keyword.get_values(opts, :exclude)
    ]

    case NoBypass.scan(scan_opts) do
      {:ok, report} ->
        Mix.shell().info(
          "app_kit.no_bypass passed #{report.checked_files} files for #{inspect(report.profiles)}"
        )

      {:error, report} ->
        Enum.each(report.violations, fn violation ->
          Mix.shell().error(NoBypass.format_violation(violation))
        end)

        Mix.raise("app_kit.no_bypass found #{length(report.violations)} boundary violation(s)")
    end
  end

  defp include_opts(opts) do
    case Keyword.get_values(opts, :include) do
      [] -> ["lib/**/*.ex"]
      includes -> includes
    end
  end
end
