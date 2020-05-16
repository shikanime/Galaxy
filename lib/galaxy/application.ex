defmodule Galaxy.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      {Galaxy.Cluster, []}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Galaxy.Supervisor)
  end
end
