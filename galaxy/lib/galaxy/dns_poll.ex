defmodule Galaxy.DNSPoll do
  @moduledoc """
  Assumes you have nodes that respond to the specified DNS query (A record), and which follow the node name pattern of
  `<name>@<ip-address>`. If your setup matches those assumptions, this strategy will periodically poll DNS and connect
  all nodes it finds.

  ## Options

  * `poll_interval` - How often to poll in milliseconds (optional; default: 5_000)
  * `query` - DNS query to use (required; e.g. "my-app.example.com")
  * `basename` - The short name of the nodes you wi
  """
  @behaviour Galaxy.Distribution

  @default_polling_interval 5_000

  def start_link(options) do
    Galaxy.Distribution.start_link(__MODULE__, options)
  end

  @impl true
  def handle_info(:poll, state) do
    {:noreply, poll_nodes(state)}
  end

  defp poll_nodes(%{mod: mod} = state) do
    nodes
    |> Enum.concat(dns_nodes())
    |> List.myers_difference(mod.list())
    |> Enum.each(&Galaxy.Distribution.sync(mod, &1))

    Process.send_after(self(), :reconnect, refresh_interval)

    state
  end

  defp dns_nodes(%{query: query, basename: basename} = state) do
    query
    |> to_charlist()
    |> :inet_res.lookup(:in, :a)
    |> Enum.map(&format_node(&1, basename))
  end

  defp format_node({a, b, c, d}, basename) do
    :"#{basename}@#{a}.#{b}.#{c}.#{d}"
  end
end
