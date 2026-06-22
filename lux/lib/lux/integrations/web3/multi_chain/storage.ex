defmodule Lux.Integrations.Web3.MultiChain.Storage do
  @moduledoc """
  ETS-backed centralized storage for multi-chain data aggregation.
  Handles blocks, transactions, and events across all configured networks.
  """
  use GenServer

  @table_name :multi_chain_storage

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(_) do
    :ets.new(@table_name, [:named_table, :public, :set, read_concurrency: true])
    {:ok, %{}}
  end

  def insert_block(chain_id, block_data) do
    key = {:block, chain_id, Map.get(block_data, "number") || Map.get(block_data, "hash")}
    :ets.insert(@table_name, {key, block_data, System.system_time(:second)})
  end

  def insert_event(chain_id, log_data) do
    key = {:event, chain_id, log_data["transactionHash"], log_data["logIndex"]}
    :ets.insert(@table_name, {key, log_data, System.system_time(:second)})
  end

  def get_latest_blocks() do
    # Simple table scan for blocks, grouped by chain_id
    :ets.match_object(@table_name, {{:block, :"$1", :_}, :"$2", :_})
    |> Enum.group_by(fn {{:block, chain_id, _}, _, _} -> chain_id end)
    |> Enum.map(fn {chain_id, entries} ->
      latest =
        entries
        |> Enum.map(fn {_, data, _} -> data end)
        |> Enum.sort_by(&(&1["timestamp"] || 0), :desc)
        |> List.first()

      {chain_id, latest}
    end)
    |> Enum.into(%{})
  end

  def get_events(chain_id_filter \\ nil) do
    match_spec =
      if chain_id_filter,
        do: {{:event, chain_id_filter, :_, :_}, :"$1", :_},
        else: {{:event, :"$1", :_, :_}, :"$2", :_}

    :ets.match_object(@table_name, match_spec)
    |> Enum.map(fn {key, data, ts} ->
      case key do
        {:event, c_id, tx, idx} ->
          %{chain_id: c_id, transaction: tx, index: idx, data: data, recorded_at: ts}
      end
    end)
  end

  def clear() do
    :ets.delete_all_objects(@table_name)
  end
end
