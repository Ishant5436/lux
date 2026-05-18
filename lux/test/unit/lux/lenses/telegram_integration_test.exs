defmodule Lux.Lenses.TelegramIntegrationTest do
  use UnitAPICase, async: true
  alias Lux.Lenses.TelegramLens

  setup do
    Req.Test.verify_on_exit!()
  end

  describe "Telegram Lens + Client Integration" do
    test "successfully fetches updates with retry on 429" do
      # 1. Expect first call to fail with 429
      Req.Test.expect(Lux.Integrations.Telegram.Client, fn conn ->
        Req.Test.json(conn, %{"ok" => false, "error_code" => 429, "description" => "Too Many Requests", "parameters" => %{"retry_after" => 1}})
      end)

      # 2. Expect second call to succeed
      Req.Test.expect(Lux.Integrations.Telegram.Client, fn conn ->
        Req.Test.json(conn, %{"ok" => true, "result" => [%{"update_id" => 1, "message" => %{"text" => "Retry success"}}]})
      end)

      input = %{
        action: "getUpdates",
        token: "fake_token",
        max_retries: 1
      }

      # Note: This will actually sleep for 1s in tests unless we mock Process.sleep
      assert {:ok, [%{"message" => %{"text" => "Retry success"}}]} = TelegramLens.focus(input)
    end

    test "returns error after exhausting retries" do
      Req.Test.stub(Lux.Integrations.Telegram.Client, fn conn ->
        Req.Test.json(conn, %{"ok" => false, "error_code" => 500, "description" => "Internal Server Error"})
      end)

      input = %{action: "getMe", token: "fake_token", max_retries: 2}
      assert {:error, {500, "Internal Server Error"}} = TelegramLens.focus(input)
    end
  end
end
