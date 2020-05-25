import Config

headless_service =
  System.get_env("SERVICE_NAME") ||
    raise """
    environment variable SERVICE_NAME is missing.
    You can retrieve a headless service using a StatefulSets
    """

config :galaxy,
  hosts: [headless_service],
  polling_interval: 10_000
