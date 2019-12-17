defmodule Galaxy.Cluster.Partisan do
  @behaviour Galaxy.Cluster

  def connect(node) do
    :partisan.join(node)
  end

  def disconnect(node) do
    :partisan.leave(node)
  end

  def members do
    :partisan.members()
  end
end
