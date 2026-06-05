defmodule Lux.Prisms.Sushiswap.SushiswapPoolInfoPrism do
  @moduledoc """
  A prism that fetches pool reserves and state from a SushiSwap V2/V3 contract.
  """

  use Lux.Prism,
    name: "SushiSwap Pool Info",
    description: "Fetches SushiSwap pool reserve ratios and block timestamps.",
    input_schema: %{
      type: :object,
      properties: %{
        pool_address: %{
          type: :string,
          description: "Ethereum address of the SushiSwap pool pair",
          pattern: "^0x[a-fA-F0-9]{40}$"
        },
        chain_id: %{
          type: :integer,
          description: "The chain ID to query (e.g. 1 for Mainnet, 42161 for Arbitrum)"
        }
      },
      required: ["pool_address", "chain_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{type: :string},
        reserves: %{
          type: :object,
          properties: %{
            reserve0: %{type: :integer},
            reserve1: %{type: :integer},
            blockTimestampLast: %{type: :integer}
          }
        }
      },
      required: ["status", "reserves"]
    }

  import Lux.Python

  def handler(%{pool_address: pool_address, chain_id: chain_id} = _input, _ctx) do
    # Ensure package is imported
    Lux.Python.import_package("sushiswap_utils.sushiswap_client")

    python_result =
      python variables: %{
               pool_address: pool_address,
               chain_id: chain_id
             } do
        ~PY"""
        from sushiswap_utils.sushiswap_client import SushiSwapClient

        client = SushiSwapClient(chain_id)
        res = client.get_pool_reserves(pool_address)
        res
        """
      end

    case python_result do
      %{"error" => error} -> {:error, error}
      result when is_map(result) -> {:ok, %{status: "success", reserves: result}}
      _ -> {:error, "Unexpected response from Python backend"}
    end
  end
end
