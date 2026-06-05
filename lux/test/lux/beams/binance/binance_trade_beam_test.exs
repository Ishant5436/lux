defmodule Lux.Beams.Binance.BinanceTradeBeamTest do
  use ExUnit.Case, async: true

  alias Lux.Beams.Binance.BinanceTradeBeam

  @tag :skip
  test "orchestrates binance trade successfully" do
    input = %{
      symbol: "BTC/USDT",
      market_type: "spot",
      testnet: true
    }

    assert {:ok, result} = BinanceTradeBeam.run(input)
    assert Map.has_key?(result, :fetch_market_data)
    assert Map.has_key?(result, :fetch_portfolio)
  end
end
