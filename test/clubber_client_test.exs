defmodule ClubberClientTest do
  use ExUnit.Case
  doctest ClubberClient

  test "greets the world" do
    assert ClubberClient.hello() == :world
  end
end
