defmodule Lux.Prisms.Binance.BinancePortfolioPrismTest do
  use ExUnit.Case, async: true

  alias Lux.Prisms.Binance.BinancePortfolioPrism

  @tag :skip
  test "fetches portfolio successfully" do
    input = %{
      action: "balance",
      testnet: true
    }

    assert {:ok, result} = BinancePortfolioPrism.run(input)
    assert result != nil
  end
end
