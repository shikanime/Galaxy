defmodule Galaxy.Cluster.Erldist do
  @behaviour Galaxy.Cluster

  def connects(nodes) do
    nodes
    |> keep_remote_nodes()
    |> Enum.each(&Node.connect(&1))
  end

  def disconnects(nodes) do
    nodes
    |> keep_remote_nodes()
    |> Enum.each(&Node.disconnect(&1))
  end

  def members do
    Node.list()
  end

  defp keep_remote_nodes(nodes) do
    self = Node.self()
    nodes |> Enum.reject(&(&1 == self))
  end
end
