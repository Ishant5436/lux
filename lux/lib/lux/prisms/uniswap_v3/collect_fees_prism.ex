defmodule Lux.Prisms.UniswapV3.CollectFeesPrism do
  @moduledoc """
  A prism that prepares an unsigned collect transaction to harvest fees from a position.
  """

  use Lux.Prism,
    name: "Uniswap V3 Collect Fees",
    description: "Builds a collect transaction for harvesting fees from a position",
    input_schema: %{
      type: :object,
      properties: %{
        npm_address: %{type: :string, description: "NonfungiblePositionManager address"},
        token_id: %{type: :integer, description: "Position Token ID"},
        recipient: %{type: :string, description: "Address receiving the fees"},
        amount0_max: %{type: :integer, description: "Maximum amount of token0 to collect", default: 340282366920938463463374607431768211455}, # max uint128
        amount1_max: %{type: :integer, description: "Maximum amount of token1 to collect", default: 340282366920938463463374607431768211455},
        rpc_url: %{type: :string, default: "http://localhost:8545"}
      },
      required: ["npm_address", "token_id", "recipient"]
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
    amount0_max = Map.get(input, :amount0_max, 340282366920938463463374607431768211455)
    amount1_max = Map.get(input, :amount1_max, 340282366920938463463374607431768211455)

    result =
      python variables: %{
        npm_address: input.npm_address,
        token_id: input.token_id,
        recipient: input.recipient,
        amount0_max: amount0_max,
        amount1_max: amount1_max,
        rpc_url: rpc_url
      } do
        ~PY"""
        try:
            from web3 import Web3
            w3 = Web3(Web3.HTTPProvider(rpc_url))
            
            import json
            npm_abi = json.loads('[{"inputs":[{"components":[{"internalType":"uint256","name":"tokenId","type":"uint256"},{"internalType":"address","name":"recipient","type":"address"},{"internalType":"uint128","name":"amount0Max","type":"uint128"},{"internalType":"uint128","name":"amount1Max","type":"uint128"}],"internalType":"struct INonfungiblePositionManager.CollectParams","name":"params","type":"tuple"}],"name":"collect","outputs":[{"internalType":"uint256","name":"amount0","type":"uint256"},{"internalType":"uint256","name":"amount1","type":"uint256"}],"stateMutability":"payable","type":"function"}]')
            
            contract = w3.eth.contract(address=w3.to_checksum_address(npm_address), abi=npm_abi)
            
            params = {
                "tokenId": token_id,
                "recipient": w3.to_checksum_address(recipient),
                "amount0Max": amount0_max,
                "amount1Max": amount1_max
            }
            
            tx_data = contract.encodeABI(fn_name="collect", args=[list(params.values())])
            
            result = {
                "success": True,
                "data": {
                    "to": npm_address,
                    "data": tx_data,
                    "value": 0
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
        {:error, "Failed to build collect transaction: #{error}"}

      _ ->
        {:error, "Unknown error during python execution"}
    end
  end

  defp atomize_keys(map) when is_map(map) do
    Map.new(map, fn {k, v} -> {String.to_atom(k), v} end)
  end
end
