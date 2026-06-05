defmodule Lux.Prisms.Binance.BinanceMarketDataPrism do
  @moduledoc """
  A prism for fetching market data from Binance.
  """
  use Lux.Prism,
    name: "Binance Market Data Prism",
    description: "Fetches latest ticker info for a symbol on Binance"

  require Logger

  import Lux.Python
  require Lux.Python

  @impl true
  def handler(%{symbol: symbol} = input, _ctx) do
    market_type = Map.get(input, :market_type, "spot")
    testnet = Map.get(input, :testnet, false)

    Logger.info("Fetching Binance ticker for #{symbol}")

    python_result =
      python variables: %{symbol: symbol, market_type: market_type, testnet: testnet} do
        ~PY"""
        from binance_utils.binance_client import BinanceClient
        
        client = BinanceClient(testnet=testnet, market_type=market_type)
        result = client.fetch_ticker(symbol)
        result
        """
      end

    case python_result do
      %{"error" => error} ->
        Logger.error("Failed to fetch Binance ticker: #{error}")
        {:error, error}

      response ->
        {:ok, response}
    end
  end
end
