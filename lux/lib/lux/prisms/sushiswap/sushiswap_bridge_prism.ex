defmodule Lux.Prisms.Sushiswap.SushiswapBridgePrism do
  @moduledoc """
  A prism that fetches cross-chain bridge quotes from SushiXSwap/Stargate.
  """

  use Lux.Prism,
    name: "SushiSwap Bridge Quote",
    description: "Fetches cross-chain bridge quotes and fees.",
    input_schema: %{
      type: :object,
      properties: %{
        token_a: %{
          type: :string,
          description: "Source token address"
        },
        token_b: %{
          type: :string,
          description: "Destination token address"
        },
        amount: %{
          type: :integer,
          description: "Amount of token_a to bridge (in wei)"
        },
        dest_chain: %{
          type: :integer,
          description: "Destination chain ID"
        },
        chain_id: %{
          type: :integer,
          description: "Source chain ID"
        }
      },
      required: ["token_a", "token_b", "amount", "dest_chain", "chain_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{type: :string},
        quote: %{
          type: :object,
          properties: %{
            fee: %{type: :integer},
            amountOut: %{type: :integer}
          }
        }
      },
      required: ["status", "quote"]
    }

  import Lux.Python

  def handler(%{token_a: token_a, token_b: token_b, amount: amount, dest_chain: dest_chain, chain_id: chain_id} = _input, _ctx) do
    Lux.Python.import_package("sushiswap_utils.sushiswap_client")

    python_result =
      python variables: %{
               token_a: token_a,
               token_b: token_b,
               amount: amount,
               dest_chain: dest_chain,
               chain_id: chain_id
             } do
        ~PY"""
        from sushiswap_utils.sushiswap_client import SushiSwapClient

        client = SushiSwapClient(chain_id)
        res = client.get_bridge_quote(token_a, token_b, amount, dest_chain)
        res
        """
      end

    case python_result do
      %{"error" => error} -> {:error, error}
      result when is_map(result) -> {:ok, %{status: "success", quote: result}}
      _ -> {:error, "Unexpected response from Python backend"}
    end
  end
end
