import os
import ccxt
import ccxt.pro as ccxtpro
import asyncio
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class BinanceClient:
    def __init__(self, api_key=None, secret=None, testnet=False, market_type="spot"):
        """
        Initializes the Binance Client using ccxt.
        
        Args:
            api_key (str): Binance API Key. If not provided, reads from BINANCE_API_KEY.
            secret (str): Binance API Secret. If not provided, reads from BINANCE_SECRET.
            testnet (bool): Use Binance testnet if True.
            market_type (str): "spot" or "future".
        """
        self.api_key = api_key or os.getenv("BINANCE_API_KEY")
        self.secret = secret or os.getenv("BINANCE_SECRET")
        self.testnet = testnet or os.getenv("BINANCE_TESTNET", "false").lower() == "true"
        self.market_type = market_type
        
        exchange_options = {
            'enableRateLimit': True,
            'options': {
                'defaultType': self.market_type,
            }
        }
        
        if self.api_key and self.secret:
            exchange_options.update({
                'apiKey': self.api_key,
                'secret': self.secret,
            })
            
        self.exchange = ccxt.binance(exchange_options)
        if self.testnet:
            self.exchange.set_sandbox_mode(True)
            
        # For websocket operations
        self.ws_exchange = ccxtpro.binance(exchange_options)
        if self.testnet:
            self.ws_exchange.set_sandbox_mode(True)

    def fetch_ticker(self, symbol: str):
        """Fetches the latest ticker for a symbol."""
        try:
            return self.exchange.fetch_ticker(symbol)
        except Exception as e:
            logger.error(f"Error fetching ticker for {symbol}: {e}")
            return {"error": str(e)}

    def fetch_balance(self):
        """Fetches account balance."""
        try:
            return self.exchange.fetch_balance()
        except Exception as e:
            logger.error(f"Error fetching balance: {e}")
            return {"error": str(e)}

    def create_order(self, symbol: str, order_type: str, side: str, amount: float, price: float = None):
        """
        Creates a new order.
        order_type can be 'limit' or 'market'.
        side can be 'buy' or 'sell'.
        """
        try:
            if order_type.lower() == 'market':
                return self.exchange.create_market_order(symbol, side, amount)
            elif order_type.lower() == 'limit':
                if price is None:
                    raise ValueError("Price is required for limit orders")
                return self.exchange.create_limit_order(symbol, side, amount, price)
            else:
                raise ValueError(f"Unsupported order type: {order_type}")
        except Exception as e:
            logger.error(f"Error creating order: {e}")
            return {"error": str(e)}

    def get_positions(self):
        """Fetches open positions (futures only)."""
        if self.market_type != "future":
            return {"error": "Positions are only available in futures market"}
        try:
            return self.exchange.fetch_positions()
        except Exception as e:
            logger.error(f"Error fetching positions: {e}")
            return {"error": str(e)}
            
    def fetch_open_orders(self, symbol: str = None):
        """Fetches open orders."""
        try:
            return self.exchange.fetch_open_orders(symbol)
        except Exception as e:
            logger.error(f"Error fetching open orders: {e}")
            return {"error": str(e)}

    def cancel_order(self, id: str, symbol: str):
        """Cancels an existing order."""
        try:
            return self.exchange.cancel_order(id, symbol)
        except Exception as e:
            logger.error(f"Error canceling order {id}: {e}")
            return {"error": str(e)}

    async def watch_ticker(self, symbol: str):
        """Async function to watch a ticker via WebSocket."""
        try:
            ticker = await self.ws_exchange.watch_ticker(symbol)
            return ticker
        except Exception as e:
            logger.error(f"WebSocket error watching ticker {symbol}: {e}")
            return {"error": str(e)}
        finally:
            await self.ws_exchange.close()
