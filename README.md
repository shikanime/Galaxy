# Galaxy

This library provides a mechanism for automatically forming clusters of Erlang nodes, with
either static or dynamic node membership.

You can find supporting documentation [here](https://hexdocs.pm/galaxy).

## Installation

```elixir
defp deps do
  [{:galaxy, "~> 0.5"}]
end
```

## Usage

Node names can be registered either via the `.hosts.erlang` file, or by using a DNS
service discovery such as a `headless-service` Kubernetes object.

```elixir
# In your config/releases.exs file
headless_service =
  System.get_env("SERVICE_NAME") ||
    raise """
    environment variable SERVICE_NAME is missing.
    You can retrieve a headless service using a StatefulSets
    """

config :galaxy,
  topology: :erl_dist,
  services: [headless_service],
  polling_interval: 10_000
end
```

## License

MIT
