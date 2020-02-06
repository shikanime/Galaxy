defmodule Galaxy.Cluster do
  @callback connect(node) :: boolean() | :ignored

  @callback disconnect(node) :: boolean() | :ignored

  @callback members() :: list(node)
end
