defmodule Galaxy.Gossip do
  @moduledoc """
  This clustering strategy uses multicast UDP to gossip node names
  to other nodes on the network. These packets are listened for on
  each node as well, and a connection will be established between the
  two nodes if they are reachable on the network, and share the same
  magic cookie. In this way, a cluster of nodes may be formed dynamically.

  The gossip protocol is extremely simple, with a prelude followed by the node
  name which sent the packet. The node name is parsed from the packet, and a
  connection attempt is made. It will fail if the two nodes do not share a cookie.

  By default, the gossip occurs on port 45892, using the multicast address 230.1.1.251

  A TTL of 1 will limit packets to the local network, and is the default TTL.

  Optionally, `delivery_mode: :broadcast` option can be set which disables multicast and
  only uses broadcasting. This limits connectivity to local network but works on in
  scenarios where multicast is not enabled. Use `multicast_addr` as the broadcast address.
  """
  use GenServer
  require Logger

  def start_link(options) do
    GenServer.start_link(__MODULE__, options, name: __MODULE__)
  end

  @impl true
  def init(options) do
    topology = Keyword.fetch!(options, :topology)
    port = Keyword.fetch!(options, :port)
    if_addr = Keyword.fetch!(options, :ip)
    multicast_addr = Keyword.fetch!(options, :multicast_addr)

    opts = [
      :binary,
      reuseaddr: true,
      broadcast: true,
      active: true,
      ip: if_addr,
      add_membership: {multicast_addr, {0, 0, 0, 0}}
    ]

    {:ok, socket} =
      :gen_udp.open(
        port,
        opts ++ multicast_opts(options) ++ reuse_port_opts()
      )

    state = %{
      topology: topology,
      socket: socket,
      port: port,
      multicast_addr: multicast_addr
    }

    send(self(), :heartbeat)

    {:ok, state}
  end

  @sol_socket 0xFFFF
  @so_reuseport 0x0200

  defp reuse_port_opts() do
    case :os.type() do
      {:unix, os_name} when os_name in [:darwin, :freebsd, :openbsd, :netbsd] ->
        [{:raw, @sol_socket, @so_reuseport, <<1::native-32>>}]

      _ ->
        []
    end
  end

  defp multicast_opts(config) do
    case Keyword.fetch!(config, :delivery_mode) do
      :broadcast ->
        []

      :multicast ->
        if multicast_if = Keyword.get(config, :multicast_if) do
          multicast_ttl = Keyword.fetch!(config, :multicast_ttl)

          [
            multicast_if: multicast_if,
            multicast_ttl: multicast_ttl,
            multicast_loop: true
          ]
        else
          []
        end
    end
  end

  @impl true
  def handle_info(:heartbeat, state) do
    :gen_udp.send(
      state.socket,
      state.multicast_addr,
      state.port,
      ["heartbeat::", node() |> to_string()]
    )

    Process.send_after(self(), :heartbeat, :rand.uniform(5_000))

    {:noreply, state}
  end

  def handle_info({:udp, socket, _, _, "heartbeat::" <> name}, %{socket: socket} = state)
      when name != node() do
    state.topology.connect_nodes([name |> String.to_atom()])
    {:noreply, state}
  end

  def handle_info({:udp, socket, _, _, "Peer:" <> name}, %{socket: socket} = state) do
    state.topology.connect_nodes([name |> String.to_atom()])
    {:noreply, state}
  end

  def handle_info({:udp, socket, _, _, _}, %{socket: socket} = state) do
    {:noreply, state}
  end

  @impl true
  def terminate(_reason, %{socket: socket}) do
    :gen_udp.close(socket)
  end
end
