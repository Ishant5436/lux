import sys, os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "../..")))

import pytest
from unittest.mock import MagicMock
from curve_utils.gauge import deposit, withdraw, claim_rewards

def test_deposit():
    mock_web3 = MagicMock()
    mock_contract = mock_web3.eth.contract.return_value
    mock_contract.functions.deposit.return_value.build_transaction.return_value = {"data": "mock_deposit"}
    
    tx = deposit(mock_web3, "0xGauge", 1000, "0xUser")
    assert tx["data"] == "mock_deposit"
    mock_contract.functions.deposit.assert_called_once_with(1000)

def test_withdraw():
    mock_web3 = MagicMock()
    mock_contract = mock_web3.eth.contract.return_value
    mock_contract.functions.withdraw.return_value.build_transaction.return_value = {"data": "mock_withdraw"}
    
    tx = withdraw(mock_web3, "0xGauge", 500, "0xUser")
    assert tx["data"] == "mock_withdraw"
    mock_contract.functions.withdraw.assert_called_once_with(500)

def test_claim_rewards():
    mock_web3 = MagicMock()
    mock_contract = mock_web3.eth.contract.return_value
    mock_contract.functions.claim_rewards.return_value.build_transaction.return_value = {"data": "mock_claim"}
    
    tx = claim_rewards(mock_web3, "0xGauge", "0xUser")
    assert tx["data"] == "mock_claim"
    mock_contract.functions.claim_rewards.assert_called_once()
