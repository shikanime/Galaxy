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

  def start_link(options) do
    GenServer.start_link(__MODULE__, options, name: __MODULE__)
  end

  @impl true
  def init(options) do
    services = Keyword.fetch!(options, :services)
    Enum.each(services, &Logger.info(["Watching ", to_string(&1), " host"]))
    topology = Keyword.fetch!(options, :topology)
    mode = Keyword.fetch!(options, :mode)
    polling = Keyword.get(options, :polling, @default_polling_interval)
    {:ok, %{topology: topology, polling: polling, services: services, mode: mode}, {:continue, :connect}}
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
    discover_nodes(state) |> sync_nodes(state)
    Process.send_after(self(), :reconnect, polling)
    state
  end

  defp discover_nodes(%{services: services, mode: mode}) do
    Enum.flat_map(services, fn host ->
      case :inet_res.getbyname(to_charlist(host), mode) do
        {:ok, {:hostent, _, _, _, _, addresses}} ->
          addresses |> normalize_addresses() |> :net_adm.world_list()

        {:error, :nxdomain} ->
          Logger.error(["Can't resolve DNS for ", host])
          []

        {:error, :timeout} ->
          Logger.error(["DNS timeout for ", host])
          []

        _ ->
          []
      end
    end)
  end

  defp sync_nodes(services, %{topology: topology}) do
    topology.connects(filter_members(services, topology.members()))
  end

  defp normalize_addresses(addresses) do
    Enum.reduce(addresses, [], fn
      {_, _, 4369, target}, acc -> [List.to_atom(target) | acc]
      _, acc -> acc
    end)
  end

  defp filter_members(nodes, members) do
    MapSet.difference(MapSet.new(nodes), MapSet.new([Node.self() | members]))
  end
end
