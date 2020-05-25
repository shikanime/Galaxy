defmodule Galaxy.Topology.Dist do
  @moduledoc """
  Native Erlang Distribution interface.
  """
  @behaviour Galaxy.Topology

  def connect_nodes(nodes) do
    Enum.reduce(nodes, {[], []}, fn node, {good, bad} ->
      if Node.connect(node),
        do: {[node | good], bad},
        else: {good, [node | bad]}
    end)
  end

  def disconnect_nodes(nodes) do
    Enum.reduce(nodes, {[], []}, fn node, {good, bad} ->
      if Node.disconnect(node),
        do: {[node | good], bad},
        else: {good, [node | bad]}
    end)
  end

  def members,
    do: Node.list()
end
