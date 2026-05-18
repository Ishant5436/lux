defmodule Lux.Lenses.PancakeSwapLens do
  @moduledoc """
  A multi-chain lens for PancakeSwap.
  Handles pool discovery, TVL tracking, and volume analysis across BSC, Ethereum, and Base.
  """
  use Lux.Lens,
    name: "PancakeSwap Integration Lens",
    description: "Advanced analytics for PancakeSwap V2/V3 liquidity pools.",
    method: :post

  @subgraphs %{
    bsc: "https://api.thegraph.com/subgraphs/name/pancakeswap/exchange-v3-bsc",
    eth: "https://api.thegraph.com/subgraphs/name/pancakeswap/exchange-v3-eth",
    base: "https://api.thegraph.com/subgraphs/name/pancakeswap/exchange-v3-base"
  }

  @doc """
  Fetches top pools for a specific chain.
  """
  def focus(input \\ %{}, opts \\ []) do
    chain = Map.get(input, :chain, :bsc) |> String.to_atom()
    url = Map.get(@subgraphs, chain, @subgraphs.bsc)
    min_tvl = Map.get(input, :min_tvl, 10_000) # Autonomous TVL safety guard
    
    query = Map.get(input, :query) || """
    {
      pools(first: 10, orderBy: totalValueLockedUSD, orderDirection: desc) {
        id
        token0 { symbol, name }
        token1 { symbol, name }
        feeTier
        totalValueLockedUSD
        volumeUSD
      }
    }
    """

    Req.post(url, json: %{query: query})
    |> case do
      {:ok, %{status: 200, body: %{"data" => %{"pools" => pools}}}} -> 
        # Autonomous Defense: Filter out low-liquidity (dangerous) pools
        safe_pools = Enum.filter(pools, fn p -> 
          String.to_float(p["totalValueLockedUSD"]) >= min_tvl 
        end)
        {:ok, %{"pools" => safe_pools}}
      {:ok, response} -> {:error, "Subgraph error: #{response.status}"}
      {:error, error} -> {:error, inspect(error)}
    end
  end
end
