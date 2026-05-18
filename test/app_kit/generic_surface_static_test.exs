defmodule AppKit.GenericSurfaceStaticTest do
  use ExUnit.Case, async: true

  @surface_roots [
    "core/app_kit_core/lib",
    "core/work_surface/lib",
    "core/runtime_gateway/lib",
    "bridges/mezzanine_bridge/lib"
  ]

  @provider_shaped_api_tokens [
    "sync_linear_source",
    "sync_linear_issue",
    "sync_linear_issues",
    "current_linear_issue_states",
    "fetch_linear_candidates",
    "publish_linear_source",
    "execute_linear_graphql_tool",
    "fetch_github_pr_evidence",
    "cleanup_github_pr_branch",
    "linear_api_key",
    "linear_api_key_env_var"
  ]

  test "generic AppKit surfaces do not expose provider-shaped implementation APIs" do
    offenders =
      for path <- source_files(),
          content = File.read!(path),
          token <- @provider_shaped_api_tokens,
          String.contains?(content, token) do
        {path, token}
      end

    assert offenders == []
  end

  defp source_files do
    @surface_roots
    |> Enum.flat_map(&Path.wildcard(Path.join(&1, "**/*.{ex,exs}")))
    |> Enum.sort()
  end
end
