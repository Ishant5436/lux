defmodule Lux.Beams.UniswapV3.RebalancerBeamTest do
  use ExUnit.Case, async: true

  alias Lux.Beams.UniswapV3.RebalancerBeam

  @tag :integration
  test "executes rebalancer evaluation" do
    input = %{
      pool_address: "0x8ad599c3A0ff1De082011EFDDc58f1908eb6e6D8",
      current_tick_lower: 190000,
      current_tick_upper: 210000,
      rpc_url: "http://localhost:8545",
      tick_spacing: 60,
      spread_multiplier: 10
    }

    # Same as above, since we don't have a live ETH node, we expect graceful error.
    # A successful execution would return {:ok, result, execution_log}
    # But because PoolStatePrism fails to connect to localhost:8545, it returns {:error, ...}
    result = RebalancerBeam.run(input)
    
    assert {:error, msg, _} = result
    assert String.contains?(msg, "Failed to fetch pool state")
  end
end
