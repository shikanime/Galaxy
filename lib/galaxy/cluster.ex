defmodule Galaxy.Cluster do
  @moduledoc false
  use Supervisor

  @config_schema [
    topology: [
      type: :atom,
      default: :erl_dist
    ],
    hosts: [
      type: {:custom, __MODULE__, :hosts, []},
      default: []
    ],
    polling_interval: [
      type: :pos_integer,
      default: 5000
    ],
    gossip: [
      type: :boolean,
      default: false
    ],
    gossip_opts: [
      type: :keyword_list
    ]
  ]

  @gossip_config_schema [
    ip: [
      type: {:custom, __MODULE__, :address, []},
      default: {0, 0, 0, 0}
    ],
    port: [
      type: :pos_integer,
      default: 45_892
    ],
    multicast_if: [
      type: {:custom, __MODULE__, :address, []},
      default: nil
    ],
    multicast_addr: [
      type: {:custom, __MODULE__, :address, []},
      default: {230, 1, 1, 251}
    ],
    multicast_ttl: [
      type: :pos_integer,
      default: 1
    ],
    delivery_mode: [
      type: {:one_of, [:broadcast, :multicast]},
      default: :multicast
    ],
    secret_key_base: [
      type: :string,
      required: true
    ],
    force_security: [
      type: :boolean,
      default: false
    ]
  ]

  def start_link(options) do
    Supervisor.start_link(__MODULE__, options, name: __MODULE__)
  end

  @impl true
  def init(options) do
    config =
      Application.get_all_env(:galaxy)
      |> Keyword.merge(options)
      |> NimbleOptions.validate!(@config_schema)
      |> Keyword.update!(:topology, &translate_topology/1)

    topology = Keyword.fetch!(config, :topology)
    polling_interval = Keyword.fetch!(config, :polling_interval)

    children =
      [
        {Galaxy.Host, [topology: topology]},
        {Galaxy.DNS, [topology: topology, polling_interval: polling_interval]}
      ] ++ gossip_child_spec(config)

    Supervisor.init(children, strategy: :one_for_one, max_restarts: 0)
  end

  def address(ip),
    do: ip |> to_charlist() |> :inet.parse_address()

  def hosts(hosts) do
    case Enum.filter(hosts, &(not is_bitstring(&1))) do
      [] ->
        {:ok, hosts}

      fail_hosts ->
        {:error, "hosts must be of type string got: #{inspect(fail_hosts)}"}
    end
  end

  defp translate_topology(:erl_dist), do: Galaxy.Topology.ErlDist
  defp translate_topology(topology), do: topology

  defp gossip_child_spec(config) do
    if Keyword.fetch!(config, :gossip) do
      topology = Keyword.fetch!(config, :topology)

      gossip_opts =
        config
        |> Keyword.fetch!(:gossip_opts)
        |> NimbleOptions.validate!(@gossip_config_schema)
        |> Keyword.put(:topology, topology)

      [{Galaxy.Gossip, gossip_opts}]
    else
      []
    end
  end
end
