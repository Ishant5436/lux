defmodule Lux.Prisms.UniswapV3.PoolStatePrism do
  @moduledoc """
  A prism that fetches the current state of a Uniswap V3 Pool and computes the optimal tick range.
  """

  use Lux.Prism,
    name: "Uniswap V3 Pool State",
    description: "Fetches current pool state and calculates optimal liquidity range",
    input_schema: %{
      type: :object,
      properties: %{
        pool_address: %{
          type: :string,
          description: "The Uniswap V3 Pool contract address"
        },
        rpc_url: %{
          type: :string,
          description: "RPC URL to query",
          default: "http://localhost:8545"
        },
        tick_spacing: %{
          type: :integer,
          description: "Tick spacing of the pool",
          default: 60
        },
        spread_multiplier: %{
          type: :integer,
          description: "Spread multiplier for optimal range",
          default: 10
        }
      },
      required: ["pool_address"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        sqrtPriceX96: %{type: :integer},
        tick: %{type: :integer},
        unlocked: %{type: :boolean},
        liquidity: %{type: :integer},
        optimal_tick_lower: %{type: :integer},
        optimal_tick_upper: %{type: :integer}
      },
      required: ["sqrtPriceX96", "tick", "liquidity"]
    }

  import Lux.Python

  def handler(%{pool_address: pool_address} = input, _ctx) do
    rpc_url = Map.get(input, :rpc_url, "http://localhost:8545")
    tick_spacing = Map.get(input, :tick_spacing, 60)
    spread_multiplier = Map.get(input, :spread_multiplier, 10)

    result =
      python variables: %{
        pool_address: pool_address,
        rpc_url: rpc_url,
        tick_spacing: tick_spacing,
        spread_multiplier: spread_multiplier
      } do
        ~PY"""
        try:
            from uniswap_v3_utils.uniswap_client import UniswapV3Client
            client = UniswapV3Client(rpc_url)
            
            state = client.get_pool_state(pool_address)
            optimal = client.compute_optimal_range(state["tick"], tick_spacing, spread_multiplier)
            
            result = {
                "success": True,
                "data": {
                    "sqrtPriceX96": state["sqrtPriceX96"],
                    "tick": state["tick"],
                    "unlocked": state["unlocked"],
                    "liquidity": state["liquidity"],
                    "optimal_tick_lower": optimal["tickLower"],
                    "optimal_tick_upper": optimal["tickUpper"]
                }
            }
        except Exception as e:
            result = {"success": False, "error": str(e)}
        
        result
        """
      end

    case result do
      %{"success" => true, "data" => data} ->
        {:ok, atomize_keys(data)}

      %{"success" => false, "error" => error} ->
        {:error, "Failed to fetch pool state: #{error}"}

      _ ->
        {:error, "Unknown error during python execution"}
    end
  end

  defp atomize_keys(map) when is_map(map) do
    Map.new(map, fn {k, v} -> {String.to_atom(k), v} end)
  end
end
