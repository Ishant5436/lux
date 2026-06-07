import json
from web3 import Web3

class UniswapV3Client:
    def __init__(self, rpc_url: str = "http://localhost:8545"):
        self.w3 = Web3(Web3.HTTPProvider(rpc_url))
        
        # Load ABIs from the priv/web3/abis directory if they were present,
        # but for this utility we define minimal ABIs to interact.
        self.pool_abi = json.loads('[{"inputs":[],"name":"slot0","outputs":[{"internalType":"uint160","name":"sqrtPriceX96","type":"uint160"},{"internalType":"int24","name":"tick","type":"int24"},{"internalType":"uint16","name":"observationIndex","type":"uint16"},{"internalType":"uint16","name":"observationCardinality","type":"uint16"},{"internalType":"uint16","name":"observationCardinalityNext","type":"uint16"},{"internalType":"uint8","name":"feeProtocol","type":"uint8"},{"internalType":"bool","name":"unlocked","type":"bool"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"liquidity","outputs":[{"internalType":"uint128","name":"","type":"uint128"}],"stateMutability":"view","type":"function"}]')
        
        self.npm_abi = json.loads('[{"inputs":[{"components":[{"internalType":"address","name":"token0","type":"address"},{"internalType":"address","name":"token1","type":"address"},{"internalType":"uint24","name":"fee","type":"uint24"},{"internalType":"int24","name":"tickLower","type":"int24"},{"internalType":"int24","name":"tickUpper","type":"int24"},{"internalType":"uint256","name":"amount0Desired","type":"uint256"},{"internalType":"uint256","name":"amount1Desired","type":"uint256"},{"internalType":"uint256","name":"amount0Min","type":"uint256"},{"internalType":"uint256","name":"amount1Min","type":"uint256"},{"internalType":"address","name":"recipient","type":"address"},{"internalType":"uint256","name":"deadline","type":"uint256"}],"internalType":"struct INonfungiblePositionManager.MintParams","name":"params","type":"tuple"}],"name":"mint","outputs":[{"internalType":"uint256","name":"tokenId","type":"uint256"},{"internalType":"uint128","name":"liquidity","type":"uint128"},{"internalType":"uint256","name":"amount0","type":"uint256"},{"internalType":"uint256","name":"amount1","type":"uint256"}],"stateMutability":"payable","type":"function"}, {"inputs":[{"components":[{"internalType":"uint256","name":"tokenId","type":"uint256"},{"internalType":"address","name":"recipient","type":"address"},{"internalType":"uint128","name":"amount0Max","type":"uint128"},{"internalType":"uint128","name":"amount1Max","type":"uint128"}],"internalType":"struct INonfungiblePositionManager.CollectParams","name":"params","type":"tuple"}],"name":"collect","outputs":[{"internalType":"uint256","name":"amount0","type":"uint256"},{"internalType":"uint256","name":"amount1","type":"uint256"}],"stateMutability":"payable","type":"function"}, {"inputs":[{"internalType":"uint256","name":"tokenId","type":"uint256"}],"name":"positions","outputs":[{"internalType":"uint96","name":"nonce","type":"uint96"},{"internalType":"address","name":"operator","type":"address"},{"internalType":"address","name":"token0","type":"address"},{"internalType":"address","name":"token1","type":"address"},{"internalType":"uint24","name":"fee","type":"uint24"},{"internalType":"int24","name":"tickLower","type":"int24"},{"internalType":"int24","name":"tickUpper","type":"int24"},{"internalType":"uint128","name":"liquidity","type":"uint128"},{"internalType":"uint256","name":"feeGrowthInside0LastX128","type":"uint256"},{"internalType":"uint256","name":"feeGrowthInside1LastX128","type":"uint256"},{"internalType":"uint128","name":"tokensOwed0","type":"uint128"},{"internalType":"uint128","name":"tokensOwed1","type":"uint128"}],"stateMutability":"view","type":"function"}]')

    def get_pool_state(self, pool_address: str):
        """Fetch the current state of a Uniswap V3 Pool."""
        contract = self.w3.eth.contract(address=self.w3.to_checksum_address(pool_address), abi=self.pool_abi)
        slot0 = contract.functions.slot0().call()
        liquidity = contract.functions.liquidity().call()
        
        return {
            "sqrtPriceX96": slot0[0],
            "tick": slot0[1],
            "unlocked": slot0[6],
            "liquidity": liquidity
        }

    def compute_optimal_range(self, current_tick: int, tick_spacing: int, spread_multiplier: int = 10):
        """Compute optimal tick lower and upper based on current tick and spacing."""
        # A simple strategy: range is current_tick +/- (spread_multiplier * tick_spacing)
        lower = current_tick - (tick_spacing * spread_multiplier)
        upper = current_tick + (tick_spacing * spread_multiplier)
        
        # Snap to tick spacing
        lower = (lower // tick_spacing) * tick_spacing
        upper = (upper // tick_spacing) * tick_spacing
        
        return {
            "tickLower": lower,
            "tickUpper": upper
        }

    def build_mint_tx(self, npm_address: str, token0: str, token1: str, fee: int, tick_lower: int, tick_upper: int, amount0: int, amount1: int, recipient: str, deadline: int):
        """Build a mint transaction for NonfungiblePositionManager."""
        contract = self.w3.eth.contract(address=self.w3.to_checksum_address(npm_address), abi=self.npm_abi)
        
        params = {
            "token0": self.w3.to_checksum_address(token0),
            "token1": self.w3.to_checksum_address(token1),
            "fee": fee,
            "tickLower": tick_lower,
            "tickUpper": tick_upper,
            "amount0Desired": amount0,
            "amount1Desired": amount1,
            "amount0Min": 0, # In production, set proper slippage bounds
            "amount1Min": 0,
            "recipient": self.w3.to_checksum_address(recipient),
            "deadline": deadline
        }
        
        # Just returning the encoded data for the agent to sign
        tx_data = contract.encodeABI(fn_name="mint", args=[list(params.values())])
        return {
            "to": npm_address,
            "data": tx_data,
            "value": 0
        }

    def get_position(self, npm_address: str, token_id: int):
        """Get position details from NonfungiblePositionManager."""
        contract = self.w3.eth.contract(address=self.w3.to_checksum_address(npm_address), abi=self.npm_abi)
        pos = contract.functions.positions(token_id).call()
        
        return {
            "token0": pos[2],
            "token1": pos[3],
            "fee": pos[4],
            "tickLower": pos[5],
            "tickUpper": pos[6],
            "liquidity": pos[7],
            "tokensOwed0": pos[10],
            "tokensOwed1": pos[11]
        }
