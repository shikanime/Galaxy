defmodule Galaxy.Cluster.Erldist do
  @behaviour Galaxy.Cluster

  def connect(node) do
    Node.connect(node)
  end

  def disconnect(node) do
    Node.disconnect(node)
  end

  def members do
    Node.list()
  end
end
