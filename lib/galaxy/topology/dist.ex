defmodule Galaxy.Topology.Dist do
  @moduledoc """
  Native Erlang Distribution interface.
  """
  @behaviour Galaxy.Topology

  def connect_nodes(nodes),
    do: Enum.each(nodes, &Node.connect(&1))

  def disconnect_nodes(nodes),
    do: Enum.each(nodes, &Node.disconnect(&1))

  def members,
    do: Node.list()
end
