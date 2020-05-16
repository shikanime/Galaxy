defmodule Galaxy.Topology.ErlDist do
  @moduledoc """
  Native Erlang Distribution interface.
  """
  @behaviour Galaxy.Topology

  def connect_nodes(nodes) do
    knowns = [Node.self() | members()]
    news = nodes -- knowns
    Enum.each(news, &Node.connect(&1))
  end

  def disconnect_nodes(nodes),
    do: Enum.each(nodes, &Node.disconnect(&1))

  def members,
    do: Node.list()
end
