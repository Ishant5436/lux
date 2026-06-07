defmodule Lux.Prisms.UniswapV3.PositionMintPrism do
  @moduledoc """
  A prism that prepares an unsigned mint transaction for a Uniswap V3 NonfungiblePositionManager.
  """

  use Lux.Prism,
    name: "Uniswap V3 Position Mint",
    description: "Builds a mint transaction for concentrated liquidity",
    input_schema: %{
      type: :object,
      properties: %{
        npm_address: %{type: :string, description: "NonfungiblePositionManager address"},
        token0: %{type: :string, description: "Address of token0"},
        token1: %{type: :string, description: "Address of token1"},
        fee: %{type: :integer, description: "Fee tier of the pool (e.g. 3000 for 0.3%)"},
        tick_lower: %{type: :integer, description: "Lower tick boundary"},
        tick_upper: %{type: :integer, description: "Upper tick boundary"},
        amount0: %{type: :integer, description: "Desired amount of token0"},
        amount1: %{type: :integer, description: "Desired amount of token1"},
        recipient: %{type: :string, description: "Address receiving the NFT"},
        deadline: %{type: :integer, description: "Unix timestamp deadline"},
        rpc_url: %{type: :string, default: "http://localhost:8545"}
      },
      required: [
        "npm_address",
        "token0",
        "token1",
        "fee",
        "tick_lower",
        "tick_upper",
        "amount0",
        "amount1",
        "recipient",
        "deadline"
      ]
    },
    output_schema: %{
      type: :object,
      properties: %{
        to: %{type: :string},
        data: %{type: :string},
        value: %{type: :integer}
      },
      required: ["to", "data", "value"]
    }

  import Lux.Python

  def handler(input, _ctx) do
    rpc_url = Map.get(input, :rpc_url, "http://localhost:8545")

    result =
      python variables: %{
        npm_address: input.npm_address,
        token0: input.token0,
        token1: input.token1,
        fee: input.fee,
        tick_lower: input.tick_lower,
        tick_upper: input.tick_upper,
        amount0: input.amount0,
        amount1: input.amount1,
        recipient: input.recipient,
        deadline: input.deadline,
        rpc_url: rpc_url
      } do
        ~PY"""
        try:
            from uniswap_v3_utils.uniswap_client import UniswapV3Client
            client = UniswapV3Client(rpc_url)
            
            tx = client.build_mint_tx(
                npm_address, token0, token1, fee, tick_lower, tick_upper,
                amount0, amount1, recipient, deadline
            )
            
            result = {
                "success": True,
                "data": tx
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
        {:error, "Failed to build mint transaction: #{error}"}

      _ ->
        {:error, "Unknown error during python execution"}
    end
  end

  defp atomize_keys(map) when is_map(map) do
    Map.new(map, fn {k, v} -> {String.to_atom(k), v} end)
  end
end
