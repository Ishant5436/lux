import unittest
from unittest.mock import MagicMock, patch
from uniswap_v3_utils.uniswap_client import UniswapV3Client

class TestUniswapV3Client(unittest.TestCase):
    @patch('uniswap_v3_utils.uniswap_client.Web3')
    def setUp(self, mock_web3):
        # Mock the Web3 instance
        self.mock_w3 = MagicMock()
        mock_web3.return_value = self.mock_w3
        self.mock_w3.to_checksum_address = lambda x: x
        
        self.client = UniswapV3Client("http://mock")

    def test_get_pool_state(self):
        mock_contract = MagicMock()
        self.mock_w3.eth.contract.return_value = mock_contract
        
        # Mock slot0 returns: sqrtPriceX96, tick, obsIndex, obsCard, obsCardNext, feeProtocol, unlocked
        mock_contract.functions.slot0().call.return_value = (
            79228162514264337593543950336, 100, 0, 1, 1, 0, True
        )
        mock_contract.functions.liquidity().call.return_value = 1000000
        
        state = self.client.get_pool_state("0xPool")
        
        self.assertEqual(state["sqrtPriceX96"], 79228162514264337593543950336)
        self.assertEqual(state["tick"], 100)
        self.assertEqual(state["unlocked"], True)
        self.assertEqual(state["liquidity"], 1000000)

    def test_compute_optimal_range(self):
        current_tick = 2050
        tick_spacing = 60
        # 2050 - (60 * 10) = 1450 -> floor(1450/60)*60 = 1440
        # 2050 + (60 * 10) = 2650 -> floor(2650/60)*60 = 2640
        optimal = self.client.compute_optimal_range(current_tick, tick_spacing, spread_multiplier=10)
        self.assertEqual(optimal["tickLower"], 1440)
        self.assertEqual(optimal["tickUpper"], 2640)

    def test_build_mint_tx(self):
        mock_contract = MagicMock()
        self.mock_w3.eth.contract.return_value = mock_contract
        mock_contract.encodeABI.return_value = "0xencoded"
        
        tx = self.client.build_mint_tx("0xNpm", "0xT0", "0xT1", 3000, -600, 600, 1000, 1000, "0xRec", 1234567890)
        self.assertEqual(tx["to"], "0xNpm")
        self.assertEqual(tx["data"], "0xencoded")
        self.assertEqual(tx["value"], 0)

    def test_get_position(self):
        mock_contract = MagicMock()
        self.mock_w3.eth.contract.return_value = mock_contract
        
        mock_contract.functions.positions().call.return_value = (
            0, "0xOp", "0xT0", "0xT1", 3000, -600, 600, 10000, 0, 0, 10, 20
        )
        
        pos = self.client.get_position("0xNpm", 1)
        self.assertEqual(pos["token0"], "0xT0")
        self.assertEqual(pos["tickLower"], -600)
        self.assertEqual(pos["liquidity"], 10000)
        self.assertEqual(pos["tokensOwed0"], 10)
        self.assertEqual(pos["tokensOwed1"], 20)

if __name__ == '__main__':
    unittest.main()
