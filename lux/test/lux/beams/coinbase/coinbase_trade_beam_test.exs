defmodule Lux.Beams.Coinbase.CoinbaseTradeBeamTest do
  use ExUnit.Case, async: true

  alias Lux.Beams.Coinbase.CoinbaseTradeBeam

  @tag :skip
  test "orchestrates coinbase trade successfully" do
    input = %{
      symbol: "BTC/USDT",
      market_type: "spot",
      testnet: true
    }

    assert {:ok, result} = CoinbaseTradeBeam.run(input)
    assert Map.has_key?(result, :fetch_market_data)
    assert Map.has_key?(result, :fetch_portfolio)
  end
end
