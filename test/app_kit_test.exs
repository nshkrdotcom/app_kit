defmodule AppKitTest do
  use ExUnit.Case
  doctest AppKit

  test "hello/0 returns the starter marker" do
    assert AppKit.hello() == :world
  end
end
