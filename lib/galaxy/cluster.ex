defmodule Galaxy.Cluster do
  @moduledoc false
  use Supervisor

  @defaults [topology: :erl_dist, polling_interval: 5000, dns_mode: :srv]

  def start_link(options) do
    Supervisor.start_link(__MODULE__, options, name: __MODULE__)
  end

  @impl true
  def init(options) do
    config = Application.get_all_env(:galaxy)
    config = @defaults |> Keyword.merge(config) |> Keyword.merge(options)

    services = Keyword.get(config, :services, [])
    dns_mode = Keyword.fetch!(config, :dns_mode)
    polling_interval = Keyword.fetch!(config, :polling_interval)
    topology = Keyword.fetch!(config, :topology) |> translate_topology()

    children = [
      {Galaxy.Host,
       [
         polling_interval: polling_interval,
         topology: topology
       ]},
      {Galaxy.DNS,
       [
         services: services,
         dns_mode: dns_mode,
         polling_interval: polling_interval,
         topology: topology
       ]}
    ]

    Supervisor.init(children, strategy: :one_for_one, max_restarts: 0)
  end

  defp translate_topology(:erl_dist), do: Galaxy.Topology.ErlDist
  defp translate_topology(topology), do: topology
end
