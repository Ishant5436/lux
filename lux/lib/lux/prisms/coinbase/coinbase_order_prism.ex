defmodule Lux.Prisms.Coinbase.CoinbaseOrderPrism do
  @moduledoc """
  A prism for placing orders on Coinbase.
  Supports both spot and futures markets.
  """
  use Lux.Prism,
    name: "Coinbase Order Placement Prism",
    description: "Places market or limit orders on Coinbase Spot or Futures"

  require Logger

  import Lux.Python
  require Lux.Python

  @impl true
  def handler(%{symbol: symbol, type: type, side: side, amount: amount} = input, _ctx) do
    market_type = Map.get(input, :market_type, "spot")
    price = Map.get(input, :price, nil)
    testnet = Map.get(input, :testnet, false)
    
    api_key = Map.get(input, :api_key) || Lux.Config.get_module_config(_ctx, __MODULE__, :api_key)
    secret = Map.get(input, :secret) || Lux.Config.get_module_config(_ctx, __MODULE__, :secret)

    Logger.info("Executing Coinbase order for #{symbol}")

    python_result =
      python variables: %{
        symbol: symbol,
        type: type,
        side: side,
        amount: amount,
        price: price,
        market_type: market_type,
        testnet: testnet,
        api_key: api_key,
        secret: secret
      } do
        ~PY"""
        from coinbase_utils.coinbase_client import CoinbaseClient
        
        client = CoinbaseClient(
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
        Logger.error("Failed to place Coinbase order: #{error}")
        {:error, error}

      response ->
        {:ok, response}
    end
  end
end
