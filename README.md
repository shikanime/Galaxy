# Galaxy

This library provides a mechanism for automatically forming clusters of Erlang nodes, with
either static or dynamic node membership. It provides a publish/subscribe mechanism for cluster
events so that you can easily be notified when cluster members join or leave with a variety
of strategies provided out of the box.

You can find supporting documentation [here](https://hexdocs.pm/galaxy).

## Features

- Automatic cluster formation/healing
- Choice of multiple clustering strategies out of the box:
  - Standard Distributed Erlang facilities (e.g. `.hosts.erlang`), which supports IP-based or DNS-based names
  - Multicast UDP gossip, using a configurable port/multicast address,
  - Kubernetes via its metadata API using via a configurable label selector and
    node basename; or alternatively, using DNS.
  - Rancher, via its [metadata API][rancher-api]
- Easy to provide your own custom clustering strategies for your specific environment.
- Easy to use provide your own distribution plumbing (i.e. something other than
  Distributed Erlang), by implementing a small set of callbacks. This allows
  `galaxy` to support projects like
  [Partisan](https://github.com/lasp-lang/partisan).

## Installation

```elixir
defp deps do
  [{:galaxy, github: "shikanime/galaxy"}]
end
```

## Usage

It is easy to get started using `galaxy`, simply decide which strategy you
want to use to form a cluster, define a topology, and then start the module in
the supervision tree of an application in your Elixir system, as demonstrated below:

```elixir
defmodule Andromeda.App do
  use Application

  def start(_type, _args) do
    children = [
      {Galaxy.Erlhost, []},
      # ..other children..
    ]
    Supervisor.start_link(children, strategy: :one_for_one, name: Andromeda.Supervisor)
  end
end
```

The following section describes topology configuration in more detail.

## Example Configuration

You can configure `galaxy` either in your Mix config file (`config.exs`) as
shown below, or construct the keyword list structure manually, as shown in the
previous section.

```elixir
config :andromeda, Andromeda.Galaxy,
    hosts: [:"a@127.0.0.1", :"b@127.0.0.1"],
```

Either way, you need to pass the configuration to the `Galaxy` module in
it's start arguments.

```elixir
defmodule Andromeda.Galaxy do
  use Galaxy, otp_app: :andromeda

  @impl true
  def init(_type, config) do
    {:ok, Keyword.put(config, :hosts, [:"a@127.0.0.1", :"b@127.0.0.1"])}
  end

  @impl true
  def connect(node) do
    Node.connect(node)
  end

  @impl true
  def disconnect(node) do
    Node.disconnect(node)
  end

  @impl true
  def list() do
    Node.list()
  end
end
```

## Clustering

You have a handful of choices with regards to cluster management out of the box:

- `Galaxy.Erlhost`, which uses the `.hosts.erlang` file to
  determine which hosts to connect to.
- `Galaxy.Gossip`, which uses multicast UDP to form a cluster between
  nodes gossiping a heartbeat.
- `Galaxy.Kubernetes`, which uses the Kubernetes Metadata API to query
  nodes based on a label selector and basename.
- `Galaxy.Kubernetes.DNS`, which uses DNS to join nodes under a shared
  headless service in a given namespace.
- `Galaxy.Rancher`, which like the Kubernetes strategy, uses a
  metadata API to query nodes to cluster with.

You can also define your own strategy implementation, by implementing the
`Galaxy` behavior. This behavior expects you to implement a
`start_link/1` callback, optionally overriding `child_spec/1` if needed. You don't necessarily have
to start a process as part of your strategy, but since it's very likely you will need to maintain some state, designing your
strategy as an OTP process (e.g. `GenServer`) is the ideal method, however any
valid OTP process will work.

If you do not wish to use the default Erlang distribution protocol, you may provide an alternative means of connecting/
disconnecting nodes via the `connect` and `disconnect` configuration options, if not using Erlang distribution you must provide a `list_nodes` implementation as well.
They take a `{module, fun, args}` tuple, and append the node name being targeted to the `args` list. How to implement distribution in this way is left as an
exercise for the reader, but I recommend taking a look at the [Firenest](https://github.com/phoenixframework/firenest) project
currently under development. By default, `galaxy` uses Distributed Erlang.

## License

MIT

[rancher-api]: http://rancher.com/docs/rancher/latest/en/rancher-services/metadata-service/
