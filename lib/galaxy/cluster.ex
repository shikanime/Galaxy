defmodule Galaxy.Cluster do
  @callback connects(list(node)) :: :ok

  @callback disconnects(list(node)) :: :ok

  @callback members() :: list(node)
end
