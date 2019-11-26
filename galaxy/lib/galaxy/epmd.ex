defmodule Galaxy.Epmd do
  @moduledoc """
  This clustering strategy relies on Erlang's built-in Epmd protocol.
  """
  use GenServer
  require Logger

  @default_refresh_interval 5000

  defstruct [:mod, :nodes, :refresh_interval, :opts]

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      @behaviour Galaxy.Epmd

      if Module.get_attribute(__MODULE__, :doc) == nil do
        @doc """
        Native Erlang Distribution node discovery.
        """
      end

      def start_link(options \\ []) do
        Galaxy.Epmd.start_link(__MODULE__, options)
      end

      def init(options) do
        {:ok, options}
      end

      def connect(node) do
        Galaxy.Epmd.connect(node)
      end

      def disconnect(node) do
        Galaxy.Epmd.disconnect(node)
      end

      def list do
        Galaxy.Epmd.list()
      end

      defoverridable init: 1, connect: 1, disconnect: 1, list: 1
    end
  end

  def start_link(options) do
    start_link(__MODULE__, options)
  end

  def start_link(module, options) do
    {sup_opts, start_opts} = Keyword.split(options, [:name])
    GenServer.start_link(module, {module, start_opts}, sup_opts)
  end

  def init(options) when is_list(options) do
    refresh_interval = Keyword.get(opts, :refresh_interval, @default_refresh_interval)
    nodes = Keyword.get(options, :nodes, [])

    flags = %{
      refresh_interval: refresh_interval,
      nodes: nodes
    }

    {:ok, flags}
  end

  @impl true
  def init({mod, options}) do
    case mod.init(options) do
      {:ok, flags} when is_map(flags) ->
        state = %__MODULE__{
          mod: mod,
          nodes: nodes,
          refresh_interval: refresh_interval,
          opts: opts
        }

        case init(state, flags) do
          {:ok, state} -> {:ok, state, {:continue, :connect}}
          {:error, reason} -> {:stop, {:supervisor_data, reason}}
        end

      :ignore ->
        :ignore

      other ->
        {:stop, {:bad_return, {mod, :init, other}}}
    end
  end

  @impl true
  def handle_continue(:connect, state) do
    {:noreply, state |> maybe_load_world_nodes() |> connect()}
  end

  @impl true
  def handle_info(:reconnect, state) do
    {:noreply, refresh_nodes(state)}
  end

  defp refresh_nodes(%{mod: mod, refresh_interval: refresh_interval} = state) do
    nodes
    |> List.myers_difference(mod.list())
    |> Enum.each(&sync_cluster(mod, &1))

    Process.send_after(self(), :reconnect, refresh_interval)

    state
  end

  defp init(state, flags) do
    refresh_interval = Map.get(flags, :refresh_interval, @default_refresh_interval)

    with :ok <- validate_refresh(refersh) do
      %{state | refresh_interval: refresh_interval}
    end
  end

  def connect(node) do
    Node.connect(node)
  end

  def disconnect(node) do
    Node.disconnect(node)
  end

  def list do
    Node.list()
  end

  def sync(%{mod: mod} = state, {:del, node}) do
    case mod.connect(node) do
      true -> Logger.info(["Node ", to_string(node), " joined the cluster"])
      false -> Logger.info(["Node ", to_string(node), " fail to connect the cluster"])
      :ignored -> Logger.info(["Node ", to_string(node), " was not able to connect the cluster"])
    end
  end

  def sync(_state, {:eq, node}) do
    Logger.debug(["Node ", to_string(node), " is already part of the cluster"])
  end

  def sync(_state, {:ins, node}) do
    Logger.debug([
      "Node ",
      to_string(node),
      " discovered but not scheduled to connect the cluster"
    ])
  end

  defp init(state, flags) do
  end

  defp maybe_load_world_nodes(state) do
    case read_host_file(state) do
      {:error, _} -> state
      nodes -> load_world_nodes(state)
    end
  end

  defp read_host_file(%{opts: opts} = state) do
    case Map.get(opts, :hosts_file_path) do
      nil -> :net_adm.host_file()
      path -> :net_adm.host_file(path)
    end
  end

  defp load_world_nodes(state) do
    Map.update!(state, :nodes, fn nodes ->
      nodes
      |> Enum.concat(:net_adm.world_list(nodes))
      |> Enum.uniq()
      |> Enum.sort()
    end)
  end

  defp validate_refresh(refresh_interval) do
    if is_integer(refresh_interval) and refresh_interval > 0,
      do: :ok,
      else: {:error, {:invalid_period, refresh_interval}}
  end
end
