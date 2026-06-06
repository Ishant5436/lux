defmodule Lux.Prisms.Coinbase.CoinbaseOrderPrismTest do
  use ExUnit.Case, async: true

  alias Lux.Prisms.Coinbase.CoinbaseOrderPrism

  @tag :skip
  test "places an order successfully" do
    input = %{
      symbol: "BTC/USDT",
      type: "limit",
      side: "buy",
      amount: 0.001,
      price: 50000.0,
      testnet: true
    }

    assert {:ok, result} = CoinbaseOrderPrism.run(input)
    assert result != nil
  end
end
