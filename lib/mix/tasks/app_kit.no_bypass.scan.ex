defmodule Mix.Tasks.AppKit.NoBypass.Scan do
  @shortdoc "Scan source files for AppKit product-boundary bypasses"

  @moduledoc """
  Alias task for the AppKit no-bypass scanner.

      mix app_kit.no_bypass.scan --root ../extravaganza --profile product --profile hazmat
  """

  use Mix.Task

  alias Mix.Tasks.AppKit.NoBypass

  @impl true
  def run(args) do
    NoBypass.run(args)
  end
end
