defmodule Galaxy.Cluster do
  @moduledoc """
  Defines a cluster.
  """

  @type t :: module

  @doc false
  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      @behaviour Galaxy.Cluster

      otp_app = Keyword.fetch!(opts, :otp_app)
      topology = Keyword.fetch!(opts, :topology)

      @otp_app otp_app
      @topology topology

      def __topology__ do
        @topology
      end

      def child_spec(opts) do
        %{
          id: __MODULE__,
          start: {__MODULE__, :start_link, [opts]},
          type: :supervisor
        }
      end

      def start_link(opts \\ []) do
        Galaxy.Cluster.Supervisor.start_link(__MODULE__, @otp_app, @topology, opts)
      end

      def connects(nodes) do
        @topology.connects(nodes)
      end

      def disconnects(nodes) do
        @topology.disconnects(nodes)
      end

      def members do
        @topology.members()
      end
    end
  end

  @optional_callbacks init: 2

  @doc """
  A callback executed when the repo starts or when configuration is read.
  The first argument is the context the callback is being invoked. If it
  is called because the Repo supervisor is starting, it will be `:supervisor`.
  It will be `:runtime` if it is called for reading configuration without
  actually starting a process.
  The second argument is the repository configuration as stored in the
  application environment. It must return `{:ok, keyword}` with the updated
  list of configuration or `:ignore` (only in the `:supervisor` case).
  """
  @callback init(context :: :supervisor | :runtime, config :: Keyword.t()) ::
              {:ok, Keyword.t()} | :ignore
end