defmodule Lux.Prisms.Coinbase.CoinbasePortfolioPrism do
  @moduledoc """
  A prism for fetching portfolio balance and positions from Coinbase.
  """
  use Lux.Prism,
    name: "Coinbase Portfolio Prism",
    description: "Fetches balances or positions for a Coinbase account"

  require Logger

  import Lux.Python
  require Lux.Python

  @impl true
  def handler(%{action: action} = input, _ctx) do
    market_type = Map.get(input, :market_type, "spot")
    testnet = Map.get(input, :testnet, false)
    
    api_key = Map.get(input, :api_key) || Lux.Config.get_module_config(_ctx, __MODULE__, :api_key)
    secret = Map.get(input, :secret) || Lux.Config.get_module_config(_ctx, __MODULE__, :secret)

    Logger.info("Fetching Coinbase portfolio data: #{action}")

    python_result =
      python variables: %{
        action: action, 
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
        Logger.error("Failed to fetch Coinbase portfolio: #{error}")
        {:error, error}

      response ->
        {:ok, response}
    end
  end
end
