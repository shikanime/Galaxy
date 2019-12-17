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
      {Galaxy.Erlhost, [name: Andromeda.Galaxy, cluster: Andromeda.Cluster]},
      # ..other children..
    ]
    Supervisor.start_link(children, strategy: :one_for_one, name: Andromeda.Supervisor)
  end
end
```

The following section describes topology configuration in more detail.

## Clustering

You have a handful of choices with regards to cluster management out of the box:

- `Galaxy.Erlhost`, which uses the `.hosts.erlang` file to
  determine which hosts to connect to.
- `Galaxy.Gossip`, which uses multicast UDP to form a cluster between
  nodes gossiping a heartbeat.
- `Galaxy.Kubernetes`, which uses the Kubernetes Metadata API to query
  nodes based on a label selector and basename.

## License

MIT
