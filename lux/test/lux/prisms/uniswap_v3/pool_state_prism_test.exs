defmodule Lux.Prisms.UniswapV3.PoolStatePrismTest do
  use ExUnit.Case, async: true

  alias Lux.Prisms.UniswapV3.PoolStatePrism

  # Skip this test if Python/Web3 is not set up correctly in the CI environment
  @tag :integration
  test "fetches pool state" do
    # Using a random mainnet pool address or mock endpoint
    # This is an integration test
    input = %{
      pool_address: "0x8ad599c3A0ff1De082011EFDDc58f1908eb6e6D8", # USDC/ETH 0.3%
      rpc_url: "http://localhost:8545", # Expected to fail or mock
      tick_spacing: 60,
      spread_multiplier: 10
    }

    # Because we don't have a live ETH node on localhost in this test environment,
    # we just expect it to return the error gracefully rather than crashing.
    result = PoolStatePrism.run(input)

    assert {:error, msg} = result
    assert String.contains?(msg, "Failed to fetch pool state")
  end
end
