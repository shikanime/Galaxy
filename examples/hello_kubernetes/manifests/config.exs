import Config

config :kernel,
  inet_dist_listen_min: 49200,
  inet_dist_listen_max: 49200

headless_service =
  System.get_env("SERVICE_NAME") ||
    raise """
    environment variable SERVICE_NAME is missing.
    You can retrieve a headless service using a StatefulSets
    """

config :galaxy,
  hosts: [headless_service],
  polling_interval: 10_000
