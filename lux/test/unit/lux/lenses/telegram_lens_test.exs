defmodule Lux.Lenses.TelegramLensTest do
  use UnitAPICase, async: true
  alias Lux.Lenses.TelegramLens

  setup do
    Req.Test.verify_on_exit!()
  end

  describe "TelegramLens.focus/2" do
    test "returns success when Telegram API returns ok" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        Req.Test.json(conn, %{"ok" => true, "result" => %{"message_id" => 123}})
      end)

      input = %{
        action: "sendMessage",
        chat_id: 123456,
        text: "Hello from Lux!",
        token: "fake_token"
      }

      assert {:ok, %{"message_id" => 123}} = TelegramLens.focus(input)
    end

    test "returns error when Telegram API returns error" do
      Req.Test.expect(Lux.Lens, fn conn ->
        Req.Test.json(conn, %{"ok" => false, "description" => "Unauthorized"})
      end)

      input = %{action: "getMe", token: "invalid_token"}
      assert {:error, "Unauthorized"} = TelegramLens.focus(input)
    end
  end
end
