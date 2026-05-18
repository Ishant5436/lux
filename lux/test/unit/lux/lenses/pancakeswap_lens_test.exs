defmodule Lux.Lenses.PancakeSwapLensTest do
  use UnitAPICase, async: true
  alias Lux.Lenses.PancakeSwapLens

  setup do
    Req.Test.verify_on_exit!()
  end

  describe "PancakeSwapLens.focus/2" do
    test "fetches pools from PancakeSwap subgraph" do
      Req.Test.expect(Lux.Lens, fn conn ->
        Req.Test.json(conn, %{
          "data" => %{
            "pools" => [
              %{"id" => "0x123", "token0" => %{"symbol" => "WBNB"}, "token1" => %{"symbol" => "CAKE"}}
            ]
          }
        })
      end)

      assert {:ok, %{"pools" => [%{"id" => "0x123" | _}]}} = PancakeSwapLens.focus(%{})
    end
  end
end
