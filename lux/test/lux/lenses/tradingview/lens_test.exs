defmodule Lux.Lenses.TradingViewTest do
  use ExUnit.Case, async: true

  alias Lux.Lenses.TradingView

  describe "calc_sma/2" do
    test "calculates correct simple moving average" do
      data = [10.0, 11.0, 12.0, 13.0, 14.0]
      assert TradingView.calc_sma(data, 3) == [11.0, 12.0, 13.0]
    end

    test "returns empty list when data is less than period" do
      assert TradingView.calc_sma([1.0, 2.0], 3) == []
    end
  end

  describe "calc_ema/2" do
    test "calculates exponential moving average" do
      data = [10.0, 11.0, 12.0, 13.0, 14.0, 15.0]
      ema = TradingView.calc_ema(data, 3)
      assert length(ema) == 4
      assert hd(ema) == 11.0 # First value is SMA of first 3
    end
  end

  describe "calc_rsi/2" do
    test "calculates relative strength index" do
      data = [44.34, 44.09, 44.15, 43.61, 44.33, 44.83, 45.10, 45.42, 45.84, 46.08, 45.89, 46.03, 45.61, 46.28, 46.28]
      rsi = TradingView.calc_rsi(data, 14)
      assert length(rsi) == 1
      assert Enum.at(rsi, 0) > 0 and Enum.at(rsi, 0) < 100
    end
  end

  describe "calc_atr/4" do
    test "calculates average true range" do
      highs = [10.0, 11.0, 12.0, 13.0]
      lows = [9.0, 10.0, 11.0, 12.0]
      closes = [9.5, 10.5, 11.5, 12.5]
      atr = TradingView.calc_atr(highs, lows, closes, 3)
      assert is_number(atr)
    end
  end

  describe "generate_signals/2" do
    test "generates correct signals for RSI overbought" do
      closes = [100.0]
      indicators = %{rsi: [80.0]}
      signals = TradingView.generate_signals(closes, indicators)
      
      assert length(signals) == 1
      assert hd(signals).type == :overbought
      assert hd(signals).indicator == :rsi
    end
    
    test "generates correct signals for MACD crossover" do
      closes = [100.0]
      indicators = %{macd: %{macd: [1.5], signal: [1.0]}}
      signals = TradingView.generate_signals(closes, indicators)
      
      assert length(signals) == 1
      assert hd(signals).type == :bullish
      assert hd(signals).indicator == :macd
    end
  end
end
