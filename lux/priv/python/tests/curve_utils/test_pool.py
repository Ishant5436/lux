import sys, os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "../..")))

import pytest
from unittest.mock import MagicMock
from curve_utils.pool import get_virtual_price, add_liquidity, remove_liquidity

def test_get_virtual_price():
    mock_web3 = MagicMock()
    mock_contract = mock_web3.eth.contract.return_value
    mock_contract.functions.get_virtual_price.return_value.call.return_value = 1000000000000000000
    
    vp = get_virtual_price(mock_web3, "0xMockAddress")
    assert vp == 1000000000000000000
    mock_contract.functions.get_virtual_price.assert_called_once()

def test_add_liquidity():
    mock_web3 = MagicMock()
    mock_contract = mock_web3.eth.contract.return_value
    mock_contract.functions.add_liquidity.return_value.build_transaction.return_value = {"data": "mock"}
    
    tx = add_liquidity(mock_web3, "0xMockAddress", [100, 100, 100], 0, "0xUser")
    assert tx["data"] == "mock"
    mock_contract.functions.add_liquidity.assert_called_once_with([100, 100, 100], 0)

def test_remove_liquidity():
    mock_web3 = MagicMock()
    mock_contract = mock_web3.eth.contract.return_value
    mock_contract.functions.remove_liquidity.return_value.build_transaction.return_value = {"data": "mock"}
    
    tx = remove_liquidity(mock_web3, "0xMockAddress", 100, [0, 0, 0], "0xUser")
    assert tx["data"] == "mock"
    mock_contract.functions.remove_liquidity.assert_called_once_with(100, [0, 0, 0])
