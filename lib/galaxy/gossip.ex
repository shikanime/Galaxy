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
  alias Galaxy.Gossip.Crypto

  def start_link(options) do
    GenServer.start_link(__MODULE__, options, name: __MODULE__)
  end

  @impl true
  def init(options) do
    topology = Keyword.fetch!(options, :topology)
    port = Keyword.fetch!(options, :port)
    if_addr = Keyword.fetch!(options, :ip)
    multicast_addr = Keyword.fetch!(options, :multicast_addr)
    secret_key_base = Keyword.fetch!(options, :secret_key_base)
    force_security = Keyword.fetch!(options, :force_security)

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
      multicast_addr: multicast_addr,
      secret_key_base: secret_key_base,
      force_security: force_security
    }

    send(self(), :heartbeat)

    {:ok, state}
  end

  @sol_socket 0xFFFF
  @so_reuseport 0x0200

  defp reuse_port_opts do
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
    raw_payload = "heartbeat::" <> :erlang.term_to_binary(%{node: node()})
    {iv, encrypted_payload} = Crypto.encrypt(raw_payload, state.secret_key_base)

    :gen_udp.send(
      state.socket,
      state.multicast_addr,
      state.port,
      [iv, encrypted_payload]
    )

    Process.send_after(self(), :heartbeat, :rand.uniform(5_000))

    {:noreply, state}
  end

  def handle_info({:udp, _, _, _, "Peer:" <> name}, state) do
    handle_peer(name, state)
  end

  def handle_info({:udp, _, _, _, "heartbeat::" <> data}, state) do
    handle_heartbeat({:unsafe, data}, state)
  end

  def handle_info({:udp, _, _, _, <<iv::binary-16, data::binary>>}, state) do
    handle_heartbeat({:safe, iv, data}, state)
  end

  def handle_info({:udp, _, _, _, _}, state) do
    {:noreply, state}
  end

  defp handle_peer(name, state) do
    if state.force_security do
      Logger.debug(["Gossip refused unsecure node ", name |> to_string(), " to connect"])
    else
      name
      |> String.to_atom()
      |> maybe_connect_node(state)
    end

    {:noreply, state}
  end

  defp handle_heartbeat({:unsafe, payload}, state) do
    if state.force_security do
      Logger.debug("Gossip refused unsecure node to connect")
    else
      with {:ok, unserialized_payload} <- unserialize_heartbeat_payload(payload) do
        maybe_connect_node(unserialized_payload, state)
      end
    end

    {:noreply, state}
  end

  defp handle_heartbeat({:safe, iv, data}, state) do
    with {:ok, bin_data} <- Crypto.decrypt(data, iv, state.secret_key_base),
         {:ok, payload} <- validate_heartbeat_message(bin_data),
         {:ok, unserialized_payload} <- unserialize_heartbeat_payload(payload) do
      maybe_connect_node(unserialized_payload, state)
    end

    {:noreply, state}
  end

  defp validate_heartbeat_message("heartbeat::" <> payload), do: {:ok, payload}
  defp validate_heartbeat_message(_), do: {:error, :bad_request}

  @impl true
  def terminate(_reason, %{socket: socket}) do
    :gen_udp.close(socket)
  end

  defp unserialize_heartbeat_payload(payload) do
    unserialized_payload =
      payload
      |> :erlang.binary_to_term()
      |> Map.get(:node)

    {:ok, unserialized_payload}
  rescue
    ArgumentError ->
      {:error, :bad_format}
  end

  defp maybe_connect_node(name, state)
       when is_atom(name) and name != node() do
    unless name in state.topology.members() do
      state.topology.connect_nodes([name])
      Logger.debug(["Gossip connected ", name |> to_string(), " node"])
    end

    :ok
  end

  defp maybe_connect_node(_, _) do
    :ok
  end
end

defmodule Galaxy.Gossip.Crypto do
  @moduledoc false

  def encrypt(data, secret) do
    iv = :crypto.strong_rand_bytes(16)
    key = :crypto.hash(:sha256, secret)
    padded_data = pkcs7_pad(data)
    encrypted_data = :crypto.block_encrypt(:aes_cbc256, key, iv, padded_data)
    {iv, encrypted_data}
  end

  def decrypt(data, iv, secret) do
    with {:ok, padded_data} <- decrypt_block(data, iv, secret) do
      pkcs7_unpad(padded_data)
    end
  end

  defp decrypt_block(data, iv, secret) do
    key = :crypto.hash(:sha256, secret)

    try do
      {:ok, :crypto.block_decrypt(:aes_cbc256, key, iv, data)}
    rescue
      ArgumentError ->
        {:error, :cant_decrypt}
    end
  end

  defp pkcs7_pad(data) do
    bytes_remaining = rem(byte_size(data), 16)
    padding_size = 16 - bytes_remaining
    [data, :binary.copy(<<padding_size>>, padding_size)]
  end

  defp pkcs7_unpad(<<>>) do
    {:ok, ""}
  end

  defp pkcs7_unpad(data) do
    padding_size = :binary.last(data)

    if padding_size <= 16 do
      message_size = byte_size(data)

      left = binary_part(data, message_size, -padding_size)
      right = :binary.copy(<<padding_size>>, padding_size)

      if left === right,
        do: {:ok, binary_part(data, 0, message_size - padding_size)},
        else: {:error, :malformed}
    else
      {:error, :malformed}
    end
  end
end
