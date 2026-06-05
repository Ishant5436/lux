defmodule Lux.Beams.Binance.BinanceTradeBeam do
  @moduledoc """
  A beam that orchestrates Binance operations:
  1. Fetch current market data (ticker) for a symbol.
  2. Fetch the updated portfolio balance.
  """
  use Lux.Beam,
    name: "Binance Trade Orchestration",
    description: "Orchestrates basic Binance market data and portfolio operations",
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

  alias Lux.Prisms.Binance.BinanceMarketDataPrism
  alias Lux.Prisms.Binance.BinancePortfolioPrism

  require Logger

  sequence do
    step(:fetch_market_data, BinanceMarketDataPrism, %{
      symbol: [:input, :symbol],
      market_type: [:input, :market_type],
      testnet: [:input, :testnet]
    })

    step(:fetch_portfolio, BinancePortfolioPrism, %{
      action: "balance",
      market_type: [:input, :market_type],
      testnet: [:input, :testnet]
    })
  end
end
