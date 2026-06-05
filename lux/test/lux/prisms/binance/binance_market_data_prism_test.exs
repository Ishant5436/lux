defmodule Lux.Prisms.Binance.BinanceMarketDataPrismTest do
  use ExUnit.Case, async: true

  alias Lux.Prisms.Binance.BinanceMarketDataPrism

  @tag :skip
  test "fetches market data successfully" do
    input = %{
      symbol: "BTC/USDT",
      testnet: true
    }

    assert {:ok, result} = BinanceMarketDataPrism.run(input)
    assert result != nil
  end
end
