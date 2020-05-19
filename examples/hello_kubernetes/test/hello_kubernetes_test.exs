defmodule HelloKubernetesTest do
  use ExUnit.Case
  doctest HelloKubernetes

  test "greets the world" do
    assert HelloKubernetes.hello() == :world
  end
end
