defmodule Galaxy.Cluster do
  @moduledoc false
  use Supervisor

  @defaults [topology: :dist, polling: 5000, mode: :srv]

  def start_link(options) do
    Supervisor.start_link(__MODULE__, options, name: __MODULE__)
  end

  @doc """
  Retrieves the runtime configuration.
  """
  def runtime_config(options) do
    config = Application.get_all_env(:galaxy)
    config = @defaults |> Keyword.merge(config) |> Keyword.merge(options)
    {:ok, config}
  end

  @impl true
  def init(options) do
    case runtime_config(options) do
      {:ok, options} ->
        topology = Keyword.fetch!(options, :topology)
        mode = Keyword.fetch!(options, :mode)
        polling = Keyword.fetch!(options, :polling)
        services = Keyword.get(options, :services, [])

        topology = translate_topology(topology)

        children = [
          {Galaxy.Host, [topology: topology, polling: polling]},
          {Galaxy.DNS, [topology: topology, services: services, mode: mode, polling: polling]},
        ]

        Supervisor.init(children, strategy: :one_for_one, max_restarts: 0)

      :ignore ->
        :ignore
    end
  end

  defp translate_topology(:dist), do: Galaxy.Topology.Dist
  defp translate_topology(topology), do: topology
end