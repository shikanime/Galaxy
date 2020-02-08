defmodule Galaxy.Erlhosts do
  @moduledoc """
  This clustering strategy relies on Erlang's built-in distribution protocol by
  using a `.hosts.erlang` file (as used by the `:net_adm` module).

  Please see [the net_adm docs](http://erlang.org/doc/man/net_adm.html) for more details.

  In short, the following is the gist of how it works:

  > File `.hosts.erlang` consists of a number of host names written as Erlang terms. It is looked for in the current work
  > directory, the user's home directory, and $OTP_ROOT (the root directory of Erlang/OTP), in that order.

  This looks a bit like the following in practice:

  ```erlang
  'super.eua.ericsson.se'.
  'renat.eua.ericsson.se'.
  'grouse.eua.ericsson.se'.
  'gauffin1.eua.ericsson.se'.

  ```

  An optional timeout can be specified in the config. This is the timeout that
  will be used in the GenServer to connect the nodes. This defaults to
  `:infinity` meaning that the connection process will only happen when the
  worker is started. Any integer timeout will result in the connection process
  being triggered. In the example above, it has been configured for 30 seconds.
  """
  use GenServer
  require Logger

  @default_polling_interval 5000

  def start_link(options) do
    {sup_opts, start_opts} = Keyword.split(options, [:name])
    GenServer.start_link(__MODULE__, start_opts, sup_opts)
  end

  @impl true
  def init(options) do
    case :net_adm.host_file() do
      {:error, _} ->
        Logger.info("Couldn't find .hosts.erlang file")
        :ignore

      hosts ->
        cluster = Keyword.get(options, :cluster, Galaxy.Cluster.Erldist)
        polling = Keyword.get(options, :polling, @default_polling_interval)
        {:ok, %{cluster: cluster, polling: polling, hosts: hosts}, {:continue, :connect}}
    end
  end

  @impl true
  def handle_continue(:connect, state) do
    {:noreply, polling_nodes(state)}
  end

  @impl true
  def handle_info(:reconnect, state) do
    {:noreply, polling_nodes(state)}
  end

  defp polling_nodes(%{polling: polling, hosts: hosts} = state) do
    hosts |> :net_adm.world_list() |> sync_nodes(state)
    Process.send_after(self(), :reconnect, polling)
    state
  end

  defp sync_nodes(hosts, %{cluster: cluster}) do
    cluster.connects(hosts -- [Node.self() | cluster.members()])
  end
end
