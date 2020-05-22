# Galaxy

This library provides a mechanism for automatically forming clusters of Erlang nodes, with
either static or dynamic node membership.

You can find supporting documentation [here](https://hexdocs.pm/galaxy).

## Installation

```elixir
defp deps do
  [{:galaxy, "~> 0.6"}]
end
```

## Usage

Node names can be registered either via the `.hosts.erlang` file, using DNS
service discovery such as a Kubernetes `headless-service` object, or using the
Gossip protocol compatible with `libcluster` and `Peerage` with security by
default to prevent malicious [untrusted code
injection](https://erlef.github.io/security-wg/secure_coding_and_deployment_hardening/sandboxing)
or [atom
exhaustion](https://erlef.github.io/security-wg/secure_coding_and_deployment_hardening/atom_exhaustion)
on open network.

```elixir
# In your config/releases.exs file
headless_service =
  System.get_env("SERVICE_NAME") ||
    raise """
    environment variable SERVICE_NAME is missing.
    You can retrieve a headless service using a StatefulSets
    """

config :galaxy,
  topology: Galaxy.Topology.Dist,
  hosts: [headless_service],
  polling_interval: 10_000,
  gossip: true,
  gossip_opts: [
    delivery_mode: :multicast,
    force_secure: true,
    secret_key_base: "Vr0v/aJYhlum6PPS7DpH1gT+aJKIies+Ebp54vNKSeN67337BMYB1/SO62KzgK1e"
  ]
end
```

## License

MIT
