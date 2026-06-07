defmodule Lux.Beams.UniswapV3.RebalancerBeam do
  @moduledoc """
  A beam that evaluates a Uniswap V3 position's health and automates rebalancing
  if the current pool tick is out of bounds or nearing the edge of the position.
  """

  use Lux.Beam,
    name: "Uniswap V3 Rebalancer",
    description: "Evaluates position health and recommends rebalancing actions",
    input_schema: %{
      type: :object,
      properties: %{
        pool_address: %{type: :string},
        rpc_url: %{type: :string, default: "http://localhost:8545"},
        current_tick_lower: %{type: :integer},
        current_tick_upper: %{type: :integer},
        tick_spacing: %{type: :integer, default: 60},
        spread_multiplier: %{type: :integer, default: 10}
      },
      required: ["pool_address", "current_tick_lower", "current_tick_upper"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        pool_state: %{type: :object},
        position_status: %{type: :string},
        recommendation: %{type: :object}
      },
      required: ["pool_state", "position_status", "recommendation"]
    },
    generate_execution_log: true

  alias Lux.Prisms.UniswapV3.PoolStatePrism

  sequence do
    step(:fetch_pool_state, PoolStatePrism, %{
      pool_address: [:input, :pool_address],
      rpc_url: [:input, :rpc_url],
      tick_spacing: [:input, :tick_spacing],
      spread_multiplier: [:input, :spread_multiplier]
    })

    step(:analyze_health, Lux.Prisms.NoOp, %{
      pool_state: [:steps, :fetch_pool_state, :result],
      position_status: {__MODULE__, :compute_status},
      recommendation: {__MODULE__, :compute_recommendation}
    })
  end

  def compute_status(ctx) do
    state = ctx.steps.fetch_pool_state.result
    current_tick = state.tick
    current_tick_lower = ctx.input.current_tick_lower
    current_tick_upper = ctx.input.current_tick_upper

    cond do
      current_tick <= current_tick_lower ->
        "out_of_bounds_low"

      current_tick >= current_tick_upper ->
        "out_of_bounds_high"

      true ->
        range_size = current_tick_upper - current_tick_lower
        margin = div(range_size, 10)

        if current_tick < current_tick_lower + margin or
             current_tick > current_tick_upper - margin do
          "nearing_bounds"
        else
          "healthy"
        end
    end
  end

  def compute_recommendation(ctx) do
    state = ctx.steps.fetch_pool_state.result
    status = compute_status(ctx)

    if status in ["out_of_bounds_low", "out_of_bounds_high", "nearing_bounds"] do
      %{
        "action" => "REBALANCE",
        "reason" => "Status is \#{status}",
        "new_tick_lower" => state.optimal_tick_lower,
        "new_tick_upper" => state.optimal_tick_upper
      }
    else
      %{
        "action" => "HOLD",
        "reason" => "Position is healthy",
        "new_tick_lower" => ctx.input.current_tick_lower,
        "new_tick_upper" => ctx.input.current_tick_upper
      }
    end
  end
end
