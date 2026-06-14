from web3 import Web3

GAUGE_ABI = [
    {
        "name": "deposit",
        "outputs": [],
        "inputs": [
            {"type": "uint256", "name": "_value"}
        ],
        "stateMutability": "nonpayable",
        "type": "function"
    },
    {
        "name": "withdraw",
        "outputs": [],
        "inputs": [
            {"type": "uint256", "name": "_value"}
        ],
        "stateMutability": "nonpayable",
        "type": "function"
    },
    {
        "name": "claim_rewards",
        "outputs": [],
        "inputs": [],
        "stateMutability": "nonpayable",
        "type": "function"
    }
]

def deposit(w3: Web3, gauge_address: str, amount: int, user_address: str) -> dict:
    contract = w3.eth.contract(address=w3.to_checksum_address(gauge_address), abi=GAUGE_ABI)
    return contract.functions.deposit(amount).build_transaction({
        'from': user_address,
        'nonce': w3.eth.get_transaction_count(user_address),
    })

def withdraw(w3: Web3, gauge_address: str, amount: int, user_address: str) -> dict:
    contract = w3.eth.contract(address=w3.to_checksum_address(gauge_address), abi=GAUGE_ABI)
    return contract.functions.withdraw(amount).build_transaction({
        'from': user_address,
        'nonce': w3.eth.get_transaction_count(user_address),
    })

def claim_rewards(w3: Web3, gauge_address: str, user_address: str) -> dict:
    contract = w3.eth.contract(address=w3.to_checksum_address(gauge_address), abi=GAUGE_ABI)
    return contract.functions.claim_rewards().build_transaction({
        'from': user_address,
        'nonce': w3.eth.get_transaction_count(user_address),
    })
