defmodule Galaxy.Cluster.Supervisor do
  @moduledoc false
  use Supervisor

  @defaults [polling: 5000, mode: :srv]

  def start_link(cluster, otp_app, topology, opts \\ []) do
    sup_opts = if name = Keyword.get(opts, :name, cluster), do: [name: name], else: []
    Supervisor.start_link(__MODULE__, {name, cluster, otp_app, topology, opts}, sup_opts)
  end

  @doc """
  Retrieves the runtime configuration.
  """
  def runtime_config(type, cluster, otp_app, opts) do
    config = Application.get_env(otp_app, cluster, [])
    config = [otp_app: otp_app] ++ (@defaults |> Keyword.merge(config) |> Keyword.merge(opts))
    cluster_init(type, cluster, config)
  end

  @doc """
  Retrieves the compile time configuration.
  """
  def compile_config(_cluster, opts) do
    otp_app = Keyword.fetch!(opts, :otp_app)
    topology = opts[:topology]

    unless topology do
      raise ArgumentError, "missing :topology option on use Galaxy.Cluster"
    end

    if Code.ensure_compiled(topology) != {:module, topology} do
      raise ArgumentError, "topology #{inspect topology} was not compiled, " <>
                           "ensure it is correct and it is included as a project dependency"
    end

    {otp_app, topology}
  end

  @impl true
  def init({name, cluster, otp_app, topology, opts}) do
    case runtime_config(:supervisor, cluster, otp_app, opts) do
      {:ok, opts} ->
        mode = Keyword.fetch!(opts, :mode)
        polling = Keyword.fetch!(opts, :polling)
        services = Keyword.get(opts, :services, [])

        host_name = Module.concat(name, Host)
        dns_name = Module.concat(name, DNS)

        children = [
          {Galaxy.Host, [name: host_name, topology: topology, polling: polling]},
          {Galaxy.DNS, [name: dns_name, topology: topology, services: services, mode: mode, polling: polling]},
        ]

        Supervisor.init(children, strategy: :one_for_one, max_restarts: 0)

      :ignore ->
        :ignore
    end
  end

  defp cluster_init(type, cluster, config) do
    if Code.ensure_loaded?(cluster) and function_exported?(cluster, :init, 2) do
      cluster.init(type, config)
    else
      {:ok, config}
    end
  end
end