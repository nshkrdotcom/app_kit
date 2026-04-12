defmodule AppKit.AppConfigTest do
  use ExUnit.Case, async: true

  alias AppKit.AppConfig

  test "normalizes app-facing defaults" do
    assert {:ok, config} = AppConfig.normalize(%{review_mode: :batched})
    assert config.chat_surface?
    assert config.review_mode == :batched
  end
end
