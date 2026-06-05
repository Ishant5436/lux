import pytest
from unittest.mock import Mock, patch, PropertyMock
from sushiswap_utils.sushiswap_client import SushiSwapClient

def test_get_pool_reserves():
    client = SushiSwapClient(chain_id=42161) # Arbitrum
    mock_contract = Mock()
    mock_contract.functions.getReserves.return_value.call.return_value = [1000000000000000000, 2000000000000000000, 1620000000]
    
    with patch.object(client, '_get_pair_contract', return_value=mock_contract):
        reserves = client.get_pool_reserves("0x1234567890123456789012345678901234567890")
        assert reserves["reserve0"] == 1000000000000000000
        assert reserves["reserve1"] == 2000000000000000000

def test_gas_optimization():
    client = SushiSwapClient(chain_id=10) # Optimism
    
    with patch('web3.eth.eth.Eth.gas_price', new_callable=PropertyMock, return_value=1500000000):
        gas_data = client.estimate_optimal_gas()
        assert gas_data["maxFeePerGas"] > gas_data["maxPriorityFeePerGas"]
        assert gas_data["base_fee"] == 1500000000

def test_cross_chain_bridge_quote():
    client = SushiSwapClient(chain_id=1) # Mainnet
    
    # Mocking SushiXSwap or Stargate bridge logic
    with patch.object(client, '_fetch_stargate_quote', return_value={"fee": 5000000000000000, "amountOut": 995000000000000000}):
        quote = client.get_bridge_quote("0xTokenA", "0xTokenB", 1000000000000000000, dest_chain=42161)
        assert quote["fee"] == 5000000000000000
        assert quote["amountOut"] == 995000000000000000
