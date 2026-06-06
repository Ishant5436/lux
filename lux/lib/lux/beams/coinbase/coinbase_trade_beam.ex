defmodule Lux.Beams.Coinbase.CoinbaseTradeBeam do
  @moduledoc """
  A beam that orchestrates Coinbase operations:
  1. Fetch current market data (ticker) for a symbol.
  2. Fetch the updated portfolio balance.
  """
  use Lux.Beam,
    name: "Coinbase Trade Orchestration",
    description: "Orchestrates basic Coinbase market data and portfolio operations",
    input_schema: %{
      type: :object,
      properties: %{
        symbol: %{type: :string},
        market_type: %{type: :string},
        testnet: %{type: :boolean}
      },
      required: ["symbol"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        market_data: %{type: :object},
        portfolio: %{type: :object}
      },
      required: ["market_data", "portfolio"]
    }

  alias Lux.Prisms.Coinbase.CoinbaseMarketDataPrism
  alias Lux.Prisms.Coinbase.CoinbasePortfolioPrism

  require Logger

  sequence do
    step(:fetch_market_data, CoinbaseMarketDataPrism, %{
      symbol: [:input, :symbol],
      market_type: [:input, :market_type],
      testnet: [:input, :testnet]
    })

    step(:fetch_portfolio, CoinbasePortfolioPrism, %{
      action: "balance",
      market_type: [:input, :market_type],
      testnet: [:input, :testnet]
    })
  end
end
