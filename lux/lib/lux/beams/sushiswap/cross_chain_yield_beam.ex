defmodule Lux.Beams.Sushiswap.CrossChainYieldBeam do
  @moduledoc """
  A Beam that orchestrates reading pool reserves and determining bridge routes.
  """

  use Lux.Beam,
    name: "SushiSwap Cross-Chain Yield Beam",
    description: "Evaluates pools and bridges to maximize yield.",
    input_schema: %{
      type: :object,
      properties: %{
        pool_address: %{type: :string},
        source_chain: %{type: :integer},
        token_a: %{type: :string},
        token_b: %{type: :string},
        amount: %{type: :integer},
        dest_chain: %{type: :integer}
      },
      required: ["pool_address", "source_chain", "token_a", "token_b", "amount", "dest_chain"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        pool_reserves: %{type: :object},
        bridge_quote: %{type: :object}
      },
      required: ["pool_reserves", "bridge_quote"]
    }

  alias Lux.Prisms.Sushiswap.SushiswapPoolInfoPrism
  alias Lux.Prisms.Sushiswap.SushiswapBridgePrism

  sequence do
    step(:get_pool_info, SushiswapPoolInfoPrism, %{
      pool_address: [:input, :pool_address],
      chain_id: [:input, :source_chain]
    })

    step(:get_bridge_quote, SushiswapBridgePrism, %{
      token_a: [:input, :token_a],
      token_b: [:input, :token_b],
      amount: [:input, :amount],
      dest_chain: [:input, :dest_chain],
      chain_id: [:input, :source_chain]
    })
  end
end
