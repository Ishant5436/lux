defmodule Lux.Integrations.Web3.EventMonitor do
  @moduledoc """
  Top level integration module for Smart Contract Event Monitoring.
  Orchestrates storage, WebSocket real-time subscription, and historical syncing.
  """
  
  alias Lux.Integrations.Web3.EventMonitor.Storage
  alias Lux.Integrations.Web3.EventMonitor.WebSocket
  
  @doc """
  Starts a real-time event monitor.
  Returns the PID of the WebSocket client.
  
  ## Options
    * `:url` - The WebSocket RPC URL (required).
    * `:address` - Contract address to filter logs (optional).
    * `:topics` - List of topic strings to filter logs (optional).
    * `:webhook_url` - Webhook URL for alerting (optional).
  """
  def start_monitor(opts) do
    # Ensure storage is started
    case Storage.start_link() do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
    end

    WebSocket.start_link(opts)
  end
  
  @doc """
  Fetches historical events for a given block range using HTTP RPC (eth_getLogs).
  Stores the results into `Storage` so they can be queried alongside live events.
  
  ## Options
    * `:url` - The HTTP RPC URL (required).
    * `:address` - Contract address to filter logs (optional).
    * `:topics` - List of topic strings to filter logs (optional).
    * `:from_block` - Hex string or tags like "earliest" (optional).
    * `:to_block` - Hex string or tags like "latest" (optional).
  """
  def sync_historical(opts) do
    # Ensure storage is started
    case Storage.start_link() do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
    end
    
    url = Keyword.fetch!(opts, :url)
    
    params = %{
      "fromBlock" => Keyword.get(opts, :from_block, "earliest"),
      "toBlock" => Keyword.get(opts, :to_block, "latest")
    }
    
    params = if opts[:address], do: Map.put(params, "address", opts[:address]), else: params
    params = if opts[:topics], do: Map.put(params, "topics", opts[:topics]), else: params
    
    payload = %{
      "jsonrpc" => "2.0",
      "id" => 1,
      "method" => "eth_getLogs",
      "params" => [params]
    }
    
    case Req.post(url, json: payload) do
      {:ok, %Req.Response{body: %{"result" => logs}}} when is_list(logs) ->
        Enum.each(logs, &Storage.insert/1)
        {:ok, length(logs)}
      
      {:ok, %Req.Response{body: %{"error" => error}}} ->
        {:error, error}
        
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Queries stored events.
  """
  def query_events(opts \\ []) do
    Storage.query(opts)
  end
  
  @doc """
  Clears stored events.
  """
  def clear_events do
    Storage.clear()
  end
end
