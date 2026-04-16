defmodule Mix.Tasks.AppKit.Gen.Boundary do
  @shortdoc "Generate AppKit opaque-envelope DTO and bridge mapper scaffolding"

  @moduledoc """
  Generates a DTO scaffold plus mezzanine-bridge mapper templates for an
  opaque-envelope boundary type.

      mix app_kit.gen.boundary operator_projection --output tmp/generated
  """

  use Mix.Task

  alias AppKit.Workspace.BoundaryGenerator

  @impl true
  def run(args) do
    {opts, positional, _invalid} =
      OptionParser.parse(args,
        strict: [output: :string, module_namespace: :string]
      )

    name = List.first(positional) || Mix.raise("expected a boundary name")
    output = Keyword.get(opts, :output, File.cwd!())

    case BoundaryGenerator.generate(name, output, opts) do
      :ok ->
        Mix.shell().info("generated boundary scaffolding for #{name} in #{output}")

      {:error, reason} ->
        Mix.raise("failed to generate boundary scaffolding: #{inspect(reason)}")
    end
  end
end
