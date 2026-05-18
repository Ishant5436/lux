defmodule Lux.Integrations.Telegram.Client do
  @moduledoc """
  Basic HTTP client for Telegram Bot API requests.
  """

  require Logger

  @endpoint "https://api.telegram.org/bot"

  @type request_opts :: %{
    optional(:token) => String.t(),
    optional(:json) => map(),
    optional(:headers) => [{String.t(), String.t()}],
    optional(:plug) => {module(), term()}
  }

  @doc """
  Makes a request to the Telegram Bot API.

  ## Parameters

    * `method` - HTTP method (:get, :post, :put, :delete)
    * `path` - API endpoint path (e.g. "/copyMessage")
    * `opts` - Request options (see Options section)

  ## Options

    * `:token` - Telegram Bot API token (required)
    * `:json` - Request body for POST/PUT requests
    * `:headers` - Additional headers to include
    * `:plug` - A plug to use for testing instead of making real HTTP requests

  ## Examples

      # Send a message
      iex> Telegram.Client.request(:post, "/sendMessage", %{
      ...>   token: "your_bot_token",
      ...>   json: %{chat_id: 123_456_789, text: "Hello!"}
      ...> })
      {:ok, %{"ok" => true, "result" => %{"message_id" => 456}}}

      # Copy a message
      iex> Telegram.Client.request(:post, "/copyMessage", %{
      ...>   token: "your_bot_token",
      ...>   json: %{chat_id: 123_456_789, from_chat_id: 987_654_321, message_id: 42}
      ...> })
      {:ok, %{"ok" => true, "result" => %{"message_id" => 123}}}
  """
  @spec request(atom(), String.t(), request_opts()) :: {:ok, map()} | {:error, term()}
  def request(method, path, opts \\ %{}) do
    max_retries = opts[:max_retries] || 3
    do_request(method, path, opts, max_retries, 0)
  end

  defp do_request(method, path, opts, max_retries, attempt) do
    token = opts[:token] || Lux.Config.telegram_bot_token()
    url = @endpoint <> token <> path

    [
      method: method,
      url: url,
      headers: [{"Content-Type", "application/json"}] ++ (opts[:headers] || []),
      json: opts[:json]
    ]
    |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))
    |> maybe_add_plug(opts[:plug])
    |> Req.new()
    |> Req.request()
    |> case do
      {:ok, %{status: status} = response} when status in 200..299 ->
        case response.body do
          %{"ok" => true} = body -> {:ok, body}
          body -> {:error, body}
        end

      {:ok, %{status: 429, body: %{"parameters" => %{"retry_after" => retry_after}}}} ->
        if attempt < max_retries do
          Logger.info("Telegram Rate Limit: Retrying after #{retry_after}s (Attempt #{attempt + 1})")
          Process.sleep(retry_after * 1000)
          do_request(method, path, opts, max_retries, attempt + 1)
        else
          {:error, :rate_limited}
        end

      {:ok, %{status: status}} when status in [500, 502, 503, 504] and attempt < max_retries ->
        backoff = 500 * round(:math.pow(2, attempt))
        Logger.info("Telegram API Error #{status}: Retrying in #{backoff}ms")
        Process.sleep(backoff)
        do_request(method, path, opts, max_retries, attempt + 1)

      {:ok, %{status: 401}} ->
        {:error, :invalid_token}

      {:ok, %{status: status, body: %{"description" => message}}} ->
        {:error, {status, message}}

      {:ok, %{status: status, body: body}} ->
        {:error, {status, body}}

      {:error, error} ->
        {:error, error}
    end
  end

  defp maybe_add_plug(options, nil), do: options
  defp maybe_add_plug(options, plug), do: Keyword.put(options, :plug, plug)
end
