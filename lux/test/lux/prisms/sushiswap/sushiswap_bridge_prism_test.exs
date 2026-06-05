defmodule Lux.Prisms.Sushiswap.SushiswapBridgePrismTest do
  use ExUnit.Case, async: true

  alias Lux.Prisms.Sushiswap.SushiswapBridgePrism

  @tag :skip
  test "fetches cross-chain bridge quote successfully" do
    input = %{
      token_a: "0xTokenA",
      token_b: "0xTokenB",
      amount: 1000000000000000000,
      dest_chain: 42161,
      chain_id: 1
    }

    assert {:ok, result} = SushiswapBridgePrism.run(input)
    assert result.status == "success"
    assert is_map(result.quote)
  end
end
