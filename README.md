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
  - DNS via its metadata API using via a configurable label selector and
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

It is easy to get started using `galaxy`, start the module in the supervision tree
of an application in your Elixir system. And configure the it using:

```elixir
# In your config/releases.exs file
headless_service =
  System.get_env("SERVICE_NAME") ||
    raise """
    environment variable SERVICE_NAME is missing.
    You can retrieve a headless service using a StatefulSets
    """

config :cruise, Cruise.Cluster,
  services: [headless_service],
  polling: 10_000

# In your application code
defmodule MyApp.Cluster do
  use Galaxy.Cluster,
    otp_app: :my_app,
    topology: Galaxy.Topology.ErlDist
end
```

The following section describes topology configuration in more detail.

## Clustering

You have a handful of choices with regards to cluster management out of the box:

- `Galaxy.Host`, which uses the `.hosts.erlang` file to
  determine which hosts to connect to.
- `Galaxy.DNS`, which query the DNS server based on
  the `services` configuration.

## License

MIT
