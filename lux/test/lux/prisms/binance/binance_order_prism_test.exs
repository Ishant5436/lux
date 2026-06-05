defmodule Lux.Prisms.Binance.BinanceOrderPrismTest do
  use ExUnit.Case, async: true

  alias Lux.Prisms.Binance.BinanceOrderPrism

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

    assert {:ok, result} = BinanceOrderPrism.run(input)
    assert result != nil
  end
end
