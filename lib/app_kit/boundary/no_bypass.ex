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
    {"Citadel", ~r/\bCitadel\./},
    {"Jido.Integration", ~r/\bJido\.Integration\b/},
    {"ExecutionPlane", ~r/\bExecutionPlane\b/},
    {"HostIngress", ~r/\bHostIngress\b/},
    {"InvocationBridge", ~r/\bInvocationBridge\b/},
    {"Mezzanine", ~r/\bMezzanine\.(?!Pack\b)/}
  ]

  @hazmat_forbidden [
    {"ExecutionPlane", ~r/\bExecutionPlane\b/}
  ]

  @default_includes ["lib/**/*.ex"]
  @default_excludes [
    "**/_build/**",
    "**/deps/**",
    "**/doc/**",
    "**/dist/**"
  ]

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
    excluded =
      excludes
      |> Enum.flat_map(&Path.wildcard(Path.join(root, &1), match_dot: true))
      |> MapSet.new()

    includes
    |> Enum.flat_map(&Path.wildcard(Path.join(root, &1), match_dot: true))
    |> Enum.uniq()
    |> Enum.reject(fn path -> File.dir?(path) or MapSet.member?(excluded, path) end)
    |> Enum.sort()
  end

  defp scan_file(profile, path) do
    path
    |> File.read!()
    |> source_lines()
    |> Enum.flat_map(fn {line, line_number} ->
      profile
      |> forbidden_patterns()
      |> Enum.filter(fn {_name, pattern} -> Regex.match?(pattern, line) end)
      |> Enum.map(fn {name, _pattern} ->
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
end
