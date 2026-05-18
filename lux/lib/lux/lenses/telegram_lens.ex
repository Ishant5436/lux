defmodule Lux.Lenses.TelegramLens do
  @moduledoc """
  A high-performance lens for interacting with the Telegram Bot API.
  Uses the hardened Lux.Integrations.Telegram.Client for data fetching.
  """
  use Lux.Lens,
    name: "Telegram Bot API Lens",
    description: "Robust data fetcher for Telegram Bot state and messages.",
    method: :post

  alias Lux.Integrations.Telegram.Client

  @doc """
  Main entry point for the lens. Focuses on specific Telegram API actions.
  """
  def focus(input \\ %{}, _opts \\ []) do
    action = Map.get(input, :action, "getUpdates")
    token = Map.get(input, :token)
    max_retries = Map.get(input, :max_retries, 3)
    defense_mode = Map.get(input, :defense_mode, true)

    # 1. Autonomous Defense: Rate-Limiting Guard
    if action == "sendMessage" do
       :timer.sleep(100) # Simple autonomous delay for swarm safety
    end

    # Convert action to path (e.g., "getUpdates" -> "/getUpdates")
    path = if String.starts_with?(action, "/"), do: action, else: "/#{action}"
    
    # Prepare client options
    client_opts = %{
      token: token,
      max_retries: max_retries,
      json: Map.drop(input, [:action, :token, :max_retries, :defense_mode])
    }

    case Client.request(:post, path, client_opts) do
      {:ok, %{"ok" => true, "result" => result}} -> 
        if defense_mode && action == "getUpdates" do
          # 2. Autonomous Defense: Anti-Spam Filter
          {:ok, autonomous_anti_spam(result)}
        else
          {:ok, result}
        end
      {:error, reason} -> {:error, reason}
    end
  end

  defp autonomous_anti_spam(updates) do
    spam_patterns = [~r/join my channel/i, ~r/buy this coin/i, ~r/airdrop/i]
    Enum.filter(updates, fn update ->
      msg_text = get_in(update, ["message", "text"]) || ""
      !Enum.any?(spam_patterns, fn pattern -> Regex.run(pattern, msg_text) end)
    end)
  end

  @doc """
  Helper to filter updates by type.
  """
  def filter_updates(updates, type) do
    Enum.filter(updates, fn update ->
      Map.has_key?(update, to_string(type))
    end)
  end
end
