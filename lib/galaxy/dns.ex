defmodule Galaxy.DNS do
  @moduledoc """
  This topologying strategy works by loading all your Erlang nodes (within Pods) in the current [DNS
  namespace](https://kubernetes.io/docs/concepts/service-networking/dns-pod-service/).
  It will fetch the targets of all pods under a shared headless service and attempt to connect.
  It will continually monitor and update its connections every 5s.

  It assumes that all Erlang nodes were launched under a base name, are using longnames, and are unique
  based on their FQDN, rather than the base hostname. In other words, in the following
  longname, `<basename>@<ip>`, `basename` would be the value configured through
  `application_name`.
  """
  use GenServer
  require Logger

  @default_polling_interval 5000
  @default_epmd_port 4369

  def start_link(options) do
    {sup_opts, opts} = Keyword.split(options, [:name])
    GenServer.start_link(__MODULE__, opts, sup_opts)
  end

  @impl true
  def init(options) do
    case Keyword.get(options, :hosts) do
      [] ->
        :ignore

      hosts ->
        unless topology = options[:topology] do
          raise ArgumentError, "expected :topology option to be given"
        end

        polling_interval = Keyword.get(options, :polling_interval, @default_polling_interval)
        epmd_port = Keyword.get(options, :epmd_port, @default_epmd_port)

        state = %{
          topology: topology,
          hosts: hosts,
          epmd_port: epmd_port,
          polling_interval: polling_interval
        }

        send(self(), :poll)

        {:ok, state}
    end
  end

  @impl true
  def handle_info(:poll, state) do
    knowns_hosts = [node() | state.topology.members()]
    discovered_hosts = poll_services_hosts(state.hosts, state.epmd_port)
    new_hosts = discovered_hosts -- knowns_hosts

    {nodes, _} = state.topology.connect_nodes(new_hosts)

    Enum.each(nodes, &Logger.debug(["DNS connected ", &1 |> to_string(), " node"]))

    Process.send_after(self(), :poll, state.polling_interval)

    {:noreply, state}
  end

  defp poll_services_hosts(hosts, port) do
    hosts
    |> Enum.flat_map(&resolve_service_nodes/1)
    |> Enum.filter(&filter_epmd_hosts(&1, port))
    |> Enum.map(&normalize_node_hosts/1)
    |> :net_adm.world_list()
  end

  defp resolve_service_nodes(service) do
    case :inet_res.getbyname(service |> to_charlist(), :srv) do
      {:ok, {:hostent, _, _, _, _, hosts}} ->
        hosts

      {:error, :nxdomain} ->
        Logger.error(["Can't resolve DNS for ", service])
        []

      {:error, :timeout} ->
        Logger.error(["DNS timeout for ", service])
        []

      _ ->
        []
    end
  end

  defp filter_epmd_hosts(host, port),
    do: match?({_, _, ^port, _}, host)

  defp normalize_node_hosts({_, _, _, host}),
    do: host |> List.to_atom()
end
