defmodule Galaxy.Topology do
  @moduledoc """
  Topology interface for cluster formation.
  """

  @callback connect_nodes([node]) :: :ok

  @callback disconnect_nodes([node]) :: :ok

  @callback members() :: [node]
end
