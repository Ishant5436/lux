defmodule Lux.Prisms.Binance.BinanceOrderPrism do
  @moduledoc """
  A prism for placing orders on Binance.
  Supports both spot and futures markets.
  """
  use Lux.Prism,
    name: "Binance Order Placement Prism",
    description: "Places market or limit orders on Binance Spot or Futures"

  require Logger

  import Lux.Python
  require Lux.Python

  @impl true
  def handler(%{symbol: symbol, type: type, side: side, amount: amount} = input, _ctx) do
    market_type = Map.get(input, :market_type, "spot")
    price = Map.get(input, :price, nil)
    testnet = Map.get(input, :testnet, false)

    Logger.info("Executing Binance order for #{symbol}")

    python_result =
      python variables: %{
        symbol: symbol,
        type: type,
        side: side,
        amount: amount,
        price: price,
        market_type: market_type,
        testnet: testnet
      } do
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
        result = client.create_order(symbol, type, side, amount, price)
        result
        """
      end

    case python_result do
      %{"error" => error} ->
        Logger.error("Failed to place Binance order: #{error}")
        {:error, error}

      response ->
        {:ok, response}
    end
  end
end
