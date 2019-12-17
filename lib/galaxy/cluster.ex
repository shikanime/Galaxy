defmodule Galaxy.Cluster do
  @callback connect(any) :: boolean() | :ignored

  @callback disconnect(any) :: boolean() | :ignored

  @callback list :: list(:visible | :hidden | :connected | :this | :known)
end
