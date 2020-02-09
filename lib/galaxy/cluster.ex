defmodule Galaxy.Cluster do
  @moduledoc """
  Cluster interface for cluster formation.
  """

  @callback connects(list(node)) :: :ok

  @callback disconnects(list(node)) :: :ok

  @callback members() :: list(node)
end
