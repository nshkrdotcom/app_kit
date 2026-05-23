defmodule AppKit.Boundary.NoBypass do
  @moduledoc """
  Static product-boundary scanner for AppKit-governed product repos.

  The scanner is intentionally conservative and source-based. It enforces the
  architectural boundary before runtime: product code may call AppKit and
  product-local modules, but it must not import lower write/governance/runtime
  APIs directly.
  """

  defmodule Violation do
    @moduledoc """
    One no-bypass violation found in a source file.
    """

    @enforce_keys [:profile, :path, :line, :forbidden, :snippet]
    defstruct [:profile, :path, :line, :forbidden, :snippet]

    @type t :: %__MODULE__{
            profile: atom(),
            path: Path.t(),
            line: pos_integer(),
            forbidden: String.t(),
            snippet: String.t()
          }
  end

  @type profile :: :product | :hazmat
  @type scan_option ::
          {:root, Path.t()}
          | {:profile, profile() | String.t()}
          | {:profiles, [profile() | String.t()]}
          | {:include, [String.t()] | String.t()}
          | {:exclude, [String.t()] | String.t()}

  @product_forbidden [
    "AppKit.Bridges",
    "Citadel",
    "GepaFramework",
    "GepaBuildout",
    "TrinityFramework",
    "TrinityCoordinator",
    "Trinity.Coordinator",
    "Pristine",
    "Prismatic",
    "GitHubEx",
    "Notion",
    "Linear",
    "ReqLlmNext",
    "ReqLLM",
    "GeminiEx",
    "Gemini",
    "ClaudeAgent",
    "Codex",
    "Amp",
    "LlamaCpp",
    "Inference",
    "SelfHostedInferenceCore",
    "SelfHostedInferenceBumblebee",
    "CrucibleSafetensors",
    "CrucibleFactorization",
    "CrucibleTensorPatch",
    "CrucibleModelRegistry",
    "Jido.Integration",
    "GroundPlane",
    "OuterBrain",
    "AITrace",
    "AshPostgres",
    "Ecto",
    "ExecutionPlane",
    "HostIngress",
    "InvocationBridge",
    "Mezzanine",
    "Oban",
    "Postgrex",
    "Repo",
    "Temporalex",
    "AgentInterop",
    "AgentRuntimeReceipt",
    "AgentTurnLedger",
    "System.cmd",
    "Port.open",
    "script_path",
    "skill_path",
    "AxRuntime",
    "AxSidecar",
    "AxGrpc",
    "AXGrpc",
    "ControllerService.Exec",
    "System.cmd(\"ax\"",
    "ax serve",
    "A2ABridge",
    "A2A.",
    "generated A2A",
    "generated AX proto"
  ]

  @hazmat_forbidden [
    "ExecutionPlane"
  ]

  @default_includes ["lib/**/*.ex"]
  @default_excludes [
    "**/_build/**",
    "**/deps/**",
    "**/doc/**",
    "**/dist/**"
  ]
  @default_exclude_files MapSet.new([
                           "lib/app_kit/boundary/no_bypass.ex"
                         ])
  @default_exclude_segments MapSet.new(["_build", "deps", "doc", "dist"])

  @spec scan([scan_option()]) :: {:ok, map()} | {:error, map()}
  def scan(opts \\ []) when is_list(opts) do
    root = opts |> Keyword.get(:root, File.cwd!()) |> Path.expand()
    profiles = normalize_profiles(opts)
    includes = opts |> Keyword.get(:include, @default_includes) |> List.wrap()
    excludes = @default_excludes ++ (opts |> Keyword.get(:exclude, []) |> List.wrap())
    files = source_files(root, includes, excludes)

    violations =
      for profile <- profiles,
          path <- files,
          violation <- scan_file(profile, path),
          do: violation

    report = %{
      root: root,
      profiles: profiles,
      checked_files: length(files),
      violations: violations
    }

    if violations == [] do
      {:ok, report}
    else
      {:error, report}
    end
  end

  @spec format_violation(Violation.t()) :: String.t()
  def format_violation(%Violation{} = violation) do
    "#{violation.path}:#{violation.line}: #{violation.profile} profile forbids " <>
      "#{violation.forbidden}: #{violation.snippet}"
  end

  defp normalize_profiles(opts) do
    opts
    |> Keyword.get(:profiles, Keyword.get(opts, :profile, [:product]))
    |> List.wrap()
    |> default_profiles()
    |> Enum.map(&normalize_profile!/1)
    |> Enum.uniq()
  end

  defp default_profiles([]), do: [:product]
  defp default_profiles(profiles), do: profiles

  defp normalize_profile!(:product), do: :product
  defp normalize_profile!("product"), do: :product
  defp normalize_profile!(:hazmat), do: :hazmat
  defp normalize_profile!("hazmat"), do: :hazmat

  defp normalize_profile!(profile),
    do: raise(ArgumentError, "unknown no-bypass profile #{inspect(profile)}")

  defp source_files(root, includes, excludes) do
    explicit_excludes =
      excludes
      |> Enum.reject(&default_exclude?/1)
      |> Enum.flat_map(&Path.wildcard(Path.join(root, &1), match_dot: true))
      |> MapSet.new()

    includes
    |> Enum.flat_map(&expand_include(root, &1))
    |> Enum.uniq()
    |> Enum.reject(fn path ->
      File.dir?(path) or generated_path?(root, path) or default_excluded_file?(root, path) or
        MapSet.member?(explicit_excludes, path)
    end)
    |> Enum.sort()
  end

  defp default_exclude?(exclude), do: exclude in @default_excludes

  defp expand_include(root, include) do
    case recursive_source_include(include) do
      {:ok, base_relative, extension} ->
        root
        |> Path.join(base_relative)
        |> walk_source_files(extension)

      :error ->
        Path.wildcard(Path.join(root, include), match_dot: true)
    end
  end

  defp recursive_source_include(include) do
    case String.split(include, "/**/", parts: 2) do
      [base_relative, "*.ex"] -> simple_recursive_include(base_relative, ".ex")
      [base_relative, "*.exs"] -> simple_recursive_include(base_relative, ".exs")
      _other -> :error
    end
  end

  defp simple_recursive_include(base_relative, extension) do
    if String.contains?(base_relative, ["*", "?", "{", "}"]) do
      :error
    else
      {:ok, base_relative, extension}
    end
  end

  defp walk_source_files(root, extension) do
    root = Path.expand(root)

    cond do
      not File.dir?(root) ->
        []

      generated_path?(Path.dirname(root), root) ->
        []

      true ->
        root
        |> File.ls!()
        |> Enum.flat_map(&walk_source_entry(&1, root, extension))
    end
  end

  defp walk_source_entry(entry, root, extension) do
    path = Path.join(root, entry)

    cond do
      File.dir?(path) ->
        walk_source_files(path, extension)

      String.ends_with?(path, extension) ->
        [path]

      true ->
        []
    end
  end

  defp generated_path?(root, path) do
    path
    |> Path.relative_to(root)
    |> Path.split()
    |> Enum.any?(&MapSet.member?(@default_exclude_segments, &1))
  end

  defp default_excluded_file?(root, path) do
    path
    |> Path.relative_to(root)
    |> then(&MapSet.member?(@default_exclude_files, &1))
  end

  defp scan_file(profile, path) do
    path
    |> File.read!()
    |> source_lines()
    |> Enum.flat_map(fn {line, line_number} ->
      profile
      |> forbidden_patterns()
      |> Enum.filter(&forbidden_line?(&1, line))
      |> Enum.map(fn name ->
        %Violation{
          profile: profile,
          path: path,
          line: line_number,
          forbidden: name,
          snippet: String.trim(line)
        }
      end)
    end)
  end

  defp source_lines(contents) do
    contents
    |> String.split("\n")
    |> Enum.with_index(1)
    |> Enum.map(fn {line, line_number} -> {strip_comment(line), line_number} end)
    |> Enum.reject(fn {line, _line_number} -> String.trim(line) == "" end)
  end

  defp strip_comment(line) do
    line
    |> String.split("#", parts: 2)
    |> List.first()
  end

  defp forbidden_patterns(:product), do: @product_forbidden
  defp forbidden_patterns(:hazmat), do: @hazmat_forbidden

  defp forbidden_line?("AppKit.Bridges", line),
    do: String.contains?(line, ["AppKit.Bridge.", "AppKit.Bridges."])

  defp forbidden_line?("Citadel", line), do: String.contains?(line, "Citadel.")
  defp forbidden_line?("GepaFramework", line), do: String.contains?(line, "GepaFramework.")
  defp forbidden_line?("GepaBuildout", line), do: String.contains?(line, "GepaBuildout.")
  defp forbidden_line?("TrinityFramework", line), do: String.contains?(line, "TrinityFramework.")

  defp forbidden_line?("TrinityCoordinator", line),
    do: String.contains?(line, "TrinityCoordinator.")

  defp forbidden_line?("Trinity.Coordinator", line),
    do: String.contains?(line, "Trinity.Coordinator")

  defp forbidden_line?("Pristine", line), do: String.contains?(line, "Pristine.")
  defp forbidden_line?("Prismatic", line), do: String.contains?(line, "Prismatic.")
  defp forbidden_line?("GitHubEx", line), do: String.contains?(line, "GitHubEx.")
  defp forbidden_line?("Notion", line), do: String.contains?(line, "Notion.")
  defp forbidden_line?("Linear", line), do: String.contains?(line, "Linear.")
  defp forbidden_line?("ReqLlmNext", line), do: String.contains?(line, "ReqLlmNext.")
  defp forbidden_line?("ReqLLM", line), do: String.contains?(line, "ReqLLM.")
  defp forbidden_line?("GeminiEx", line), do: String.contains?(line, "GeminiEx.")
  defp forbidden_line?("Gemini", line), do: String.contains?(line, "Gemini.")
  defp forbidden_line?("ClaudeAgent", line), do: String.contains?(line, "ClaudeAgent.")
  defp forbidden_line?("Codex", line), do: String.contains?(line, "Codex.")
  defp forbidden_line?("Amp", line), do: String.contains?(line, "Amp.")
  defp forbidden_line?("LlamaCpp", line), do: String.contains?(line, "LlamaCpp.")
  defp forbidden_line?("Inference", line), do: String.contains?(line, "Inference.")

  defp forbidden_line?("SelfHostedInferenceCore", line),
    do: String.contains?(line, "SelfHostedInferenceCore.")

  defp forbidden_line?("SelfHostedInferenceBumblebee", line),
    do: String.contains?(line, "SelfHostedInferenceBumblebee.")

  defp forbidden_line?("CrucibleSafetensors", line),
    do: String.contains?(line, ["CrucibleSafetensors.", "Crucible.Safetensors"])

  defp forbidden_line?("CrucibleFactorization", line),
    do: String.contains?(line, ["CrucibleFactorization.", "Crucible.Factorization"])

  defp forbidden_line?("CrucibleTensorPatch", line),
    do: String.contains?(line, ["CrucibleTensorPatch.", "Crucible.TensorPatch"])

  defp forbidden_line?("CrucibleModelRegistry", line),
    do: String.contains?(line, ["CrucibleModelRegistry.", "Crucible.ModelRegistry"])

  defp forbidden_line?("Jido.Integration", line), do: String.contains?(line, "Jido.Integration")
  defp forbidden_line?("GroundPlane", line), do: String.contains?(line, "GroundPlane.")
  defp forbidden_line?("OuterBrain", line), do: String.contains?(line, "OuterBrain.")
  defp forbidden_line?("AITrace", line), do: String.contains?(line, "AITrace.")
  defp forbidden_line?("AshPostgres", line), do: String.contains?(line, "AshPostgres")
  defp forbidden_line?("Ecto", line), do: String.contains?(line, ["Ecto.", "use Ecto"])
  defp forbidden_line?("ExecutionPlane", line), do: String.contains?(line, "ExecutionPlane")
  defp forbidden_line?("HostIngress", line), do: String.contains?(line, "HostIngress")
  defp forbidden_line?("InvocationBridge", line), do: String.contains?(line, "InvocationBridge")

  defp forbidden_line?("Mezzanine", line),
    do: String.contains?(line, "Mezzanine.") and not String.contains?(line, "Mezzanine.Pack")

  defp forbidden_line?("Repo", line),
    do: String.contains?(line, [".Repo", " Repo", "Repo."])

  defp forbidden_line?("Oban", line), do: String.contains?(line, "Oban.")
  defp forbidden_line?("Postgrex", line), do: String.contains?(line, "Postgrex")
  defp forbidden_line?("Temporalex", line), do: String.contains?(line, "Temporalex.")
  defp forbidden_line?("AgentInterop", line), do: String.contains?(line, "AgentInterop.")

  defp forbidden_line?("AgentRuntimeReceipt", line),
    do: String.contains?(line, "AgentRuntimeReceipt")

  defp forbidden_line?("AgentTurnLedger", line), do: String.contains?(line, "AgentTurnLedger")
  defp forbidden_line?("System.cmd", line), do: String.contains?(line, "System.cmd(")
  defp forbidden_line?("Port.open", line), do: String.contains?(line, "Port.open(")
  defp forbidden_line?("script_path", line), do: String.contains?(line, "script_path")
  defp forbidden_line?("skill_path", line), do: String.contains?(line, "skill_path")
  defp forbidden_line?("AxRuntime", line), do: String.contains?(line, "AxRuntime.")
  defp forbidden_line?("AxSidecar", line), do: String.contains?(line, "AxSidecar.")
  defp forbidden_line?("AxGrpc", line), do: String.contains?(line, "AxGrpc.")
  defp forbidden_line?("AXGrpc", line), do: String.contains?(line, "AXGrpc.")

  defp forbidden_line?("ControllerService.Exec", line),
    do: String.contains?(line, "ControllerService.Exec")

  defp forbidden_line?("System.cmd(\"ax\"", line), do: String.contains?(line, "System.cmd(\"ax\"")
  defp forbidden_line?("ax serve", line), do: String.contains?(line, "ax serve")
  defp forbidden_line?("A2ABridge", line), do: String.contains?(line, "A2ABridge.")
  defp forbidden_line?("A2A.", line), do: String.contains?(line, "A2A.")
  defp forbidden_line?("generated A2A", line), do: String.contains?(line, "generated A2A")

  defp forbidden_line?("generated AX proto", line),
    do: String.contains?(line, "generated AX proto")

  defp forbidden_line?(_name, _line), do: false
end
