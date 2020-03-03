defmodule Galaxy.Cluster.Supervisor do
  use Supervisor

  @defaults [polling: 2000, refresh: 5000, mode: :srv]

  def start_link(cluster, otp_app, topology, opts \\ []) do
    Supervisor.start_link(__MODULE__, {cluster, otp_app, topology, opts}, name: __MODULE__)
  end

  @impl true
  def init({cluster, otp_app, topology, opts}) do
    config = Application.get_env(otp_app, cluster, [])
    config = [otp_app: otp_app] ++ (@defaults |> Keyword.merge(config) |> Keyword.merge(opts))

    mode = Keyword.fetch!(config, :mode)
    polling = Keyword.fetch!(config, :polling)
    refresh = Keyword.fetch!(config, :refresh)
    services = Keyword.get(config, :services, [])
    hosts = Keyword.get(config, :hosts, [])

    children = [
      {Galaxy.Erlhosts, [topology: topology, hosts: hosts, refresh: refresh]},
      {Galaxy.DNS, [topology: topology, services: services, mode: mode, polling: polling]},
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end