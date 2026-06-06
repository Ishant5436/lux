import pytest
from unittest.mock import patch, MagicMock
from coinbase_utils.coinbase_client import CoinbaseClient

@pytest.fixture
def mock_ccxt():
    with patch("coinbase_utils.coinbase_client.ccxt.coinbase") as mock_coinbase:
        mock_instance = MagicMock()
        mock_coinbase.return_value = mock_instance
        yield mock_instance

@pytest.fixture
def mock_ccxtpro():
    with patch("coinbase_utils.coinbase_client.ccxtpro.coinbase") as mock_ws_coinbase:
        mock_instance = MagicMock()
        mock_ws_coinbase.return_value = mock_instance
        yield mock_instance

def test_fetch_ticker(mock_ccxt):
    mock_ccxt.fetch_ticker.return_value = {"symbol": "BTC/USDT", "last": 50000}
    client = CoinbaseClient(api_key="test", secret="test")
    res = client.fetch_ticker("BTC/USDT")
    assert res["symbol"] == "BTC/USDT"
    assert res["last"] == 50000

def test_create_order(mock_ccxt):
    mock_ccxt.create_market_order.return_value = {"id": "123", "status": "closed"}
    client = CoinbaseClient(api_key="test", secret="test")
    res = client.create_order("BTC/USDT", "market", "buy", 1.0)
    assert res["id"] == "123"
    assert res["status"] == "closed"

def test_create_limit_order(mock_ccxt):
    mock_ccxt.create_limit_order.return_value = {"id": "124", "status": "open"}
    client = CoinbaseClient(api_key="test", secret="test")
    res = client.create_order("BTC/USDT", "limit", "sell", 1.0, 60000.0)
    assert res["id"] == "124"
    assert res["status"] == "open"

def test_create_limit_order_missing_price(mock_ccxt):
    client = CoinbaseClient(api_key="test", secret="test")
    res = client.create_order("BTC/USDT", "limit", "sell", 1.0)
    assert "error" in res

def test_fetch_balance(mock_ccxt):
    mock_ccxt.fetch_balance.return_value = {"total": {"BTC": 1.5}}
    client = CoinbaseClient(api_key="test", secret="test")
    res = client.fetch_balance()
    assert res["total"]["BTC"] == 1.5

def test_get_positions_spot(mock_ccxt):
    client = CoinbaseClient(api_key="test", secret="test", market_type="spot")
    res = client.get_positions()
    assert "error" in res

def test_get_positions_future(mock_ccxt):
    mock_ccxt.fetch_positions.return_value = [{"symbol": "BTC/USDT", "positionAmt": 1.0}]
    client = CoinbaseClient(api_key="test", secret="test", market_type="future")
    res = client.get_positions()
    assert len(res) == 1
    assert res[0]["symbol"] == "BTC/USDT"

@pytest.mark.asyncio
async def test_watch_ticker(mock_ccxtpro):
    from unittest.mock import AsyncMock
    mock_ccxtpro.watch_ticker = AsyncMock(return_value={"symbol": "BTC/USDT", "last": 50000})
    mock_ccxtpro.close = AsyncMock()
    client = CoinbaseClient(api_key="test", secret="test")
    res = await client.watch_ticker("BTC/USDT")
    assert res["last"] == 50000
    mock_ccxtpro.close.assert_awaited_once()
