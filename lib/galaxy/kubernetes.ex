defmodule Galaxy.Kubernetes do
  @moduledoc """
  This clustering strategy works by loading all your Erlang nodes (within Pods) in the current [Kubernetes
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

  def start_link(options) do
    {sup_opts, start_opts} = Keyword.split(options, [:name])
    GenServer.start_link(__MODULE__, start_opts, sup_opts)
  end

  @impl true
  def init(options) do
    case System.get_env("RELEASE_SERVICE") do
      nil ->
        :ignore

      service ->
        Logger.info(["Watching ", service, " Kubernetes headless service"])
        cluster = Keyword.get(options, :cluster, Galaxy.Cluster.Erldist)
        polling = Keyword.get(options, :polling, @default_polling_interval)
        {:ok, %{cluster: cluster, polling: polling, service: service}, {:continue, :connect}}
    end
  end

  @impl true
  def handle_continue(:connect, state) do
    {:noreply, polling_nodes(state)}
  end

  @impl true
  def handle_info(:reconnect, state) do
    {:noreply, polling_nodes(state)}
  end

  defp polling_nodes(%{polling: polling} = state) do
    case discover_nodes(state) do
      {:ok, nodes} ->
        sync_nodes(nodes, state)
        Process.send_after(self(), :reconnect, polling)
        state

      {:error, reason} ->
        {:stop, reason, state}
    end
  end

  defp discover_nodes(%{service: service}) do
    case :inet_res.getbyname(to_charlist(service), :srv) do
      {:ok, {:hostent, _name, [], :srv, _lenght, addresses}} ->
        {:ok, addresses |> normalize_worlds() |> :net_adm.world_list()}

      {:error, :nxdomain} ->
        Logger.error("Cannot be resolve DNS")

      {:error, :timeout} ->
        Logger.error("DNS timeout")

      {:error, :refused} ->
        Logger.error("DNS respond with unauthorized request")
    end
  end

  defp sync_nodes(hosts, %{cluster: cluster}) do
    cluster.connects(hosts -- [Node.self() | cluster.members()])
  end

  defp normalize_worlds(addresses) do
    Enum.reduce(addresses, [], fn
      {_priority, _weight, 4369, target}, acc -> [List.to_atom(target) | acc]
      _, acc -> acc
    end)
  end
end
