defmodule Lux.Prisms.Sushiswap.SushiswapPoolInfoPrismTest do
  use ExUnit.Case, async: true

  alias Lux.Prisms.Sushiswap.SushiswapPoolInfoPrism

  # Skip this test if Python environment is not fully mocked/available
  @tag :skip
  test "fetches pool reserves successfully" do
    input = %{
      pool_address: "0x1234567890123456789012345678901234567890",
      chain_id: 42161
    }

    # In a real environment, we would mock Python.run or rely on the local setup
    assert {:ok, result} = SushiswapPoolInfoPrism.run(input)
    assert result.status == "success"
    assert is_map(result.reserves)
  end
end
