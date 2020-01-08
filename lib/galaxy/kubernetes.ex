defmodule Galaxy.Kubernetes do
  @moduledoc """
  This clustering strategy works by loading all your Erlang nodes (within Pods) in the current [Kubernetes
  namespace](https://kubernetes.io/docs/concepts/service-networking/dns-pod-service/).
  It will fetch the hosts of all pods under a shared headless service and attempt to connect.
  It will continually monitor and update its connections every 5s.

  It assumes that all Erlang nodes were launched under a base name, are using longnames, and are unique
  based on their FQDN, rather than the base hostname. In other words, in the following
  longname, `<basename>@<ip>`, `basename` would be the value configured through
  `application_name`.
  """
  use GenServer
  require Logger

  @default_polling_interval 5000

  def start_link(options) do
    {sup_opts, start_opts} = Keyword.split(options, [:name])
    GenServer.start_link(__MODULE__, start_opts, sup_opts)
  end

  def child_spec(init_arg) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [init_arg]},
      restart: :transient
    }
  end

  @impl true
  def init(options) do
    cluster = Keyword.get(options, :cluster, Galaxy.Cluster.Erldist)
    polling = Keyword.get(options, :polling, @default_polling_interval)
    mode = System.get_env("POD_ADDRESS_TYPE", "hostname") |> String.to_atom()
    {:ok, %{cluster: cluster, polling: polling, mode: mode}, {:continue, :connect}}
  end

  @impl true
  def handle_continue(:connect, state) do
    case System.get_env("POD_SERVICE_NAME") do
      nil ->
        Logger.debug("Couldn't find POD_SERVICE_NAME environment variable")
        {:stop, {:shutdown, :not_found}, state}

      service ->
        {:noreply, polling_nodes(%{state | service: service})}
    end
  end

  @impl true
  def handle_info(:reconnect, state) do
    {:noreply, polling_nodes(state)}
  end

  defp polling_nodes(%{cluster: cluster, polling: polling, service: service} = state) do
    Enum.each(service, fn service ->
      case :inet_res.getbyname(to_charlist(service), :a) do
        {:ok, {:hostent, _fqdn, [], :inet, _value, hosts}} ->
          hosts
          |> Enum.map(&List.to_atom(:inet.ntoa(&1)))
          |> :net_adm.world_list()
          |> Enum.uniq()
          |> List.myers_difference(cluster.members())
          |> Enum.each(&sync_cluster(cluster, &1))

        {:error, :nxdomain} ->
          Logger.error("Cannot be resolve DNS")

        {:error, :timeout} ->
          Logger.error("DNS timeout")

        {:error, :refused} ->
          Logger.error("DNS respond with unauthorized request")
      end
    end)

    Process.send_after(self(), :reconnect, polling)

    state
  end

  defp sync_cluster(%{cluster: cluster}, {:del, nodes}) do
    Enum.each(nodes, fn node ->
      case cluster.connect(node) do
        true ->
          Logger.info(["Node ", to_string(node), " joined the cluster"])

        false ->
          Logger.info(["Node ", to_string(node), " fail to connect the cluster"])

        :ignored ->
          Logger.info(["Node ", to_string(node), " was not able to connect the cluster"])
      end
    end)
  end

  defp sync_cluster(_state, {:eq, nodes}) do
    Enum.each(nodes, fn node ->
      Logger.debug(["Node ", to_string(node), " is already part of the cluster"])
    end)
  end

  defp sync_cluster(_state, {:ins, nodes}) do
    Enum.each(nodes, fn node ->
      Logger.debug(["Node ", to_string(node), " discovered but not sync to the cluster"])
    end)
  end
end
