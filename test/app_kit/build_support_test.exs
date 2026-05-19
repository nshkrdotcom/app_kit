defmodule AppKit.BuildSupportTest do
  use ExUnit.Case, async: true

  @repo_root Path.expand("../..", __DIR__)
  @dependency_sources Path.join(@repo_root, "build_support/dependency_sources.exs")
  @weld Path.join(@repo_root, "build_support/weld.exs")

  unless Code.ensure_loaded?(DependencySources) do
    Code.require_file(@dependency_sources)
  end

  test "dependency source config is loaded as literal data without eval or dynamic atom creation" do
    config = DependencySources.config!(@repo_root)

    assert is_map(config)
    assert is_map(config[:deps])
    assert Map.has_key?(config[:deps], :mezzanine_core)

    assert {:mezzanine_core, opts} = DependencySources.dep("mezzanine_core", @repo_root)

    assert Keyword.fetch!(opts, :path) ==
             Path.expand("../mezzanine/core/mezzanine_core", @repo_root)

    assert_raise ArgumentError, fn ->
      DependencySources.dep("not_configured", @repo_root)
    end

    for file <- [@dependency_sources, @weld] do
      source = File.read!(file)
      refute String.contains?(source, "Code.eval_file")
      refute String.contains?(source, "String.to_atom")
    end
  end

  test "dependency source config supports bounded legacy helper config without eval" do
    tmp_root =
      Path.join(
        System.tmp_dir!(),
        "app_kit_dependency_sources_" <> Integer.to_string(System.unique_integer([:positive]))
      )

    build_support = Path.join(tmp_root, "build_support")
    config_path = Path.join(build_support, "dependency_sources.config.exs")

    try do
      File.mkdir_p!(build_support)

      File.write!(config_path, ~S"""
      repo_root = Path.expand("..", __DIR__)
      siblings_root = Path.expand("..", repo_root)

      dep = fn repo, subdir, hex ->
        %{
          path: Path.join(siblings_root, "#{repo}/#{subdir}"),
          github: %{repo: "nshkrdotcom/#{repo}", branch: "main", subdir: subdir},
          hex: hex,
          opts: [override: true],
          default_order: [:path, :github, :hex],
          publish_order: [:hex]
        }
      end

      root_dep = fn repo, hex ->
        %{
          path: Path.join(siblings_root, repo),
          github: %{repo: "nshkrdotcom/#{repo}", branch: "main"},
          hex: hex,
          default_order: [:path, :github, :hex],
          publish_order: [:hex]
        }
      end

      %{
        deps: %{
          sample_dep: dep.("sample_repo", "core/sample", "~> 0.1.0"),
          root_sample: root_dep.("root_repo", "~> 0.2.0"),
          direct_dep: %{
            path: Path.join(siblings_root, "direct/repo"),
            github: %{repo: "nshkrdotcom/direct", branch: "main", subdir: "direct/repo"},
            hex: "~> 0.3.0",
            default_order: [:path, :github, :hex],
            publish_order: [:hex]
          },
          repo_dep: %{
            path: repo_root,
            github: %{repo: "nshkrdotcom/repo_dep", branch: "main"},
            hex: "~> 0.4.0",
            default_order: [:path, :github, :hex],
            publish_order: [:hex]
          }
        }
      }
      """)

      config = DependencySources.config!(tmp_root)
      siblings_root = Path.dirname(tmp_root)

      assert get_in(config, [:deps, :sample_dep, :path]) ==
               Path.join(siblings_root, "sample_repo/core/sample")

      assert get_in(config, [:deps, :sample_dep, :github, :repo]) ==
               "nshkrdotcom/sample_repo"

      assert get_in(config, [:deps, :sample_dep, :github, :subdir]) == "core/sample"
      assert get_in(config, [:deps, :sample_dep, :opts]) == [override: true]
      assert get_in(config, [:deps, :root_sample, :path]) == Path.join(siblings_root, "root_repo")

      assert get_in(config, [:deps, :direct_dep, :path]) ==
               Path.join(siblings_root, "direct/repo")

      assert get_in(config, [:deps, :repo_dep, :path]) == tmp_root
    after
      File.rm_rf!(tmp_root)
    end
  end

  test "package persistence and no-bypass README text is anchored to the common source" do
    common =
      @repo_root
      |> Path.join("docs/common_persistence_no_bypass.md")
      |> File.read!()
      |> String.trim()

    for package_root <- persistence_doc_package_roots() do
      readme = package_root |> Path.join("README.md") |> File.read!()

      assert String.contains?(readme, common),
             "#{Path.relative_to(package_root, @repo_root)} README drifted from common persistence/no-bypass text"
    end
  end

  defp persistence_doc_package_roots do
    [
      @repo_root,
      Path.join(@repo_root, "bridges/mezzanine_bridge"),
      Path.join(@repo_root, "bridges/outer_brain_bridge"),
      Path.join(@repo_root, "bridges/projection_bridge"),
      Path.join(@repo_root, "core/app_kit_core"),
      Path.join(@repo_root, "core/authority_projections"),
      Path.join(@repo_root, "core/headless_surface"),
      Path.join(@repo_root, "core/memory_surface"),
      Path.join(@repo_root, "core/replay_surface"),
      Path.join(@repo_root, "core/runtime_gateway")
    ]
  end
end
