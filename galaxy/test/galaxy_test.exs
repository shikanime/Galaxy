defmodule GalaxyTest do
  use ExUnit.Case
  doctest Galaxy

  test "greets the world" do
    assert Galaxy.hello() == :world
  end
end
