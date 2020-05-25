defmodule Galaxy.Host do
  @moduledoc """
  This topologying strategy relies on Erlang's built-in distribution protocol by
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
  """
  use GenServer
  require Logger

  def start_link(options) do
    GenServer.start_link(__MODULE__, options, name: __MODULE__)
  end

  @impl true
  def init(options) do
    case :net_adm.host_file() do
      {:error, _} ->
        :ignore

      _ ->
        topology = Keyword.fetch!(options, :topology)
        polling_interval = Keyword.fetch!(options, :polling_interval)

        state = %{
          topology: topology,
          polling_interval: polling_interval
        }

        send(self(), :poll)

        {:ok, state}
    end
  end

  @impl true
  def handle_info(:poll, state) do
    knowns_hosts = state.topology.members()
    registered_hosts = :net_adm.world()
    unconnected_hosts = registered_hosts -- knowns_hosts

    {_, bad_nodes} = state.topology.connect_nodes(unconnected_hosts)

    Enum.each(bad_nodes, &Logger.debug(["Host fail to connect ", &1 |> to_string(), " node"]))

    Process.send_after(self(), :poll, state.polling_interval)

    {:noreply, state}
  end
end
