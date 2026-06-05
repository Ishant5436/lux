defmodule Lux.Prisms.Binance.BinancePortfolioPrism do
  @moduledoc """
  A prism for fetching portfolio balance and positions from Binance.
  """
  use Lux.Prism,
    name: "Binance Portfolio Prism",
    description: "Fetches balances or positions for a Binance account"

  require Logger

  import Lux.Python
  require Lux.Python

  @impl true
  def handler(%{action: action} = input, _ctx) do
    market_type = Map.get(input, :market_type, "spot")
    testnet = Map.get(input, :testnet, false)

    Logger.info("Fetching Binance portfolio data: #{action}")

    python_result =
      python variables: %{action: action, market_type: market_type, testnet: testnet} do
        ~PY"""
        from binance_utils.binance_client import BinanceClient
        import os
        
        api_key = os.environ.get('BINANCE_API_KEY')
        secret = os.environ.get('BINANCE_SECRET')
        client = BinanceClient(
            api_key=api_key, 
            secret=secret, 
            testnet=testnet, 
            market_type=market_type
        )
        if action == "balance":
            result = client.fetch_balance()
        elif action == "positions":
            result = client.get_positions()
        else:
            result = {"error": f"Unknown action: {action}"}
            
        result
        """
      end

    case python_result do
      %{"error" => error} ->
        Logger.error("Failed to fetch Binance portfolio: #{error}")
        {:error, error}

      response ->
        {:ok, response}
    end
  end
end
