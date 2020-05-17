defmodule Galaxy.Topology.ErlDist do
  @moduledoc """
  Native Erlang Distribution interface.
  """
  @behaviour Galaxy.Topology

  def connect_nodes(nodes) do
    Enum.each(nodes, &Node.connect(&1))
  end

  def disconnect_nodes(nodes),
    do: Enum.each(nodes, &Node.disconnect(&1))

  def members,
    do: Node.list()
end
