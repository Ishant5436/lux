defmodule Lux.Prisms.Coinbase.CoinbasePortfolioPrismTest do
  use ExUnit.Case, async: true

  alias Lux.Prisms.Coinbase.CoinbasePortfolioPrism

  @tag :skip
  test "fetches portfolio successfully" do
    input = %{
      action: "balance",
      testnet: true
    }

    assert {:ok, result} = CoinbasePortfolioPrism.run(input)
    assert result != nil
  end
end
