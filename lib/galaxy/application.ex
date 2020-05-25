defmodule Galaxy.Application do
  @moduledoc false

  use Application

  @config_schema [
    topology: [
      type: :atom,
      default: Galaxy.Topology.Dist
    ],
    hosts: [
      type: {:custom, __MODULE__, :hosts, []},
      default: []
    ],
    polling_interval: [
      type: :pos_integer
    ],
    epmd_port: [
      type: :pos_integer
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
      type: {:custom, __MODULE__, :address, []}
    ],
    port: [
      type: :pos_integer
    ],
    multicast_if: [
      type: {:custom, __MODULE__, :address, []}
    ],
    multicast_addr: [
      type: {:custom, __MODULE__, :address, []}
    ],
    multicast_ttl: [
      type: :pos_integer
    ],
    delivery_mode: [
      type: {:one_of, [:broadcast, :multicast]}
    ],
    secret_key_base: [
      type: :string,
      required: true
    ],
    force_secure: [
      type: :boolean
    ]
  ]

  def start_link(options) do
    Supervisor.start_link(__MODULE__, options, name: __MODULE__)
  end

  @impl true
  def start(_type, _args) do
    config =
      Application.get_all_env(:galaxy)
      |> NimbleOptions.validate!(@config_schema)

    host_options =
      config
      |> Keyword.take([:topology, :polling_interval])
      |> Keyword.put(:name, Galaxy.Host)

    dns_options =
      config
      |> Keyword.take([:topology, :hosts, :epmd_port, :polling_interval])
      |> Keyword.put(:name, Galaxy.DNS)

    children =
      [
        {Galaxy.Host, host_options},
        {Galaxy.DNS, dns_options}
      ] ++ gossip_child_spec(config)

    Supervisor.start_link(children, strategy: :one_for_one, name: Galaxy.Supervisor)
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

  defp gossip_child_spec(config) do
    if Keyword.fetch!(config, :gossip) do
      topology = Keyword.fetch!(config, :topology)

      gossip_opts =
        config
        |> Keyword.get(:gossip_opts, [])
        |> NimbleOptions.validate!(@gossip_config_schema)
        |> Keyword.put(:topology, topology)
        |> Keyword.put(:name, Galaxy.Gossip)

      [{Galaxy.Gossip, gossip_opts}]
    else
      []
    end
  end
end
