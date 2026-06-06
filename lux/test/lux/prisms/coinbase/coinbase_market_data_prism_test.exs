defmodule Lux.Prisms.Coinbase.CoinbaseMarketDataPrismTest do
  use ExUnit.Case, async: true

  alias Lux.Prisms.Coinbase.CoinbaseMarketDataPrism

  @tag :skip
  test "fetches market data successfully" do
    input = %{
      symbol: "BTC/USDT",
      testnet: true
    }

    assert {:ok, result} = CoinbaseMarketDataPrism.run(input)
    assert result != nil
  end
end
