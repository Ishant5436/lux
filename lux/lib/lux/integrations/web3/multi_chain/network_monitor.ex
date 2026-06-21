defmodule Lux.Integrations.Web3.MultiChain.NetworkMonitor do
  @moduledoc """
  Monitors a single EVM network. 
  Uses WebSockex if a wss:// URL is provided, otherwise falls back to HTTP polling.
  """
  use WebSockex
  require Logger

  alias Lux.Integrations.Web3.MultiChain.Storage

  def start_link(%{chain_id: chain_id, rpc_url: "wss://" <> _ = rpc_url}) do
    WebSockex.start_link(rpc_url, __MODULE__, %{chain_id: chain_id, rpc_url: rpc_url, mode: :websocket}, name: via_tuple(chain_id))
  end

  def start_link(%{chain_id: chain_id, rpc_url: rpc_url}) do
    # Fallback to standard GenServer if HTTP
    GenServer.start_link(__MODULE__, %{chain_id: chain_id, rpc_url: rpc_url, mode: :http}, name: via_tuple(chain_id))
  end

  defp via_tuple(chain_id), do: {:via, Registry, {Lux.AgentHub, "multi_chain_monitor_#{chain_id}"}}

  # =========================================================
  # WebSocket Implementation
  # =========================================================

  def handle_connect(_conn, %{mode: :websocket} = state) do
    Logger.info("[MultiChain] Connected to WebSocket for chain: #{state.chain_id}")
    
    # Subscribe to new heads
    req = %{
      "jsonrpc" => "2.0",
      "id" => 1,
      "method" => "eth_subscribe",
      "params" => ["newHeads"]
    }
    
    # Subscribe to logs
    logs_req = %{
      "jsonrpc" => "2.0",
      "id" => 2,
      "method" => "eth_subscribe",
      "params" => ["logs", %{}]
    }

    {:reply, [
      {:text, Jason.encode!(req)},
      {:text, Jason.encode!(logs_req)}
    ], state}
  end

  def handle_frame({:text, msg}, %{mode: :websocket} = state) do
    case Jason.decode(msg) do
      {:ok, %{"method" => "eth_subscription", "params" => %{"result" => result, "subscription" => _sub_id}}} ->
        process_incoming_data(state.chain_id, result)
      _ ->
        :ok
    end
    {:ok, state}
  end
  
  def handle_disconnect(%{reason: reason}, state) do
    Logger.warning("[MultiChain] WebSocket disconnected for chain #{state.chain_id}: #{inspect(reason)}")
    {:reconnect, state}
  end

  # =========================================================
  # HTTP Polling Implementation
  # =========================================================

  def init(%{mode: :http} = state) do
    Logger.info("[MultiChain] Started HTTP Polling for chain: #{state.chain_id}")
    schedule_poll()
    {:ok, state}
  end

  def handle_info(:poll, %{mode: :http} = state) do
    # Fetch latest block
    req = %{
      "jsonrpc" => "2.0",
      "method" => "eth_getBlockByNumber",
      "params" => ["latest", false],
      "id" => 1
    }

    case Req.post(state.rpc_url, json: req) do
      {:ok, %{status: 200, body: %{"result" => block}}} when not is_nil(block) ->
        process_incoming_data(state.chain_id, block)
      _ ->
        :ok
    end

    schedule_poll()
    {:noreply, state}
  end

  defp schedule_poll do
    Process.send_after(self(), :poll, 5_000)
  end

  # =========================================================
  # Shared Processing
  # =========================================================

  defp process_incoming_data(chain_id, %{"number" => _} = block) do
    Storage.insert_block(chain_id, block)
  end

  defp process_incoming_data(chain_id, %{"transactionHash" => _} = log) do
    Storage.insert_event(chain_id, log)
  end

  defp process_incoming_data(_chain_id, _), do: :ok
end
