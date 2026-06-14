from web3 import Web3

# Minimal ABI for standard 3pool-like Curve pools
STABLESWAP_ABI = [
    {
        "name": "get_virtual_price",
        "outputs": [{"type": "uint256", "name": ""}],
        "inputs": [],
        "stateMutability": "view",
        "type": "function",
        "gas": 1050275
    },
    {
        "name": "add_liquidity",
        "outputs": [],
        "inputs": [
            {"type": "uint256[3]", "name": "amounts"},
            {"type": "uint256", "name": "min_mint_amount"}
        ],
        "stateMutability": "nonpayable",
        "type": "function"
    },
    {
        "name": "remove_liquidity",
        "outputs": [],
        "inputs": [
            {"type": "uint256", "name": "_amount"},
            {"type": "uint256[3]", "name": "min_amounts"}
        ],
        "stateMutability": "nonpayable",
        "type": "function"
    }
]

def get_virtual_price(w3: Web3, pool_address: str) -> int:
    contract = w3.eth.contract(address=w3.to_checksum_address(pool_address), abi=STABLESWAP_ABI)
    return contract.functions.get_virtual_price().call()

def add_liquidity(w3: Web3, pool_address: str, amounts: list, min_mint_amount: int, user_address: str) -> dict:
    contract = w3.eth.contract(address=w3.to_checksum_address(pool_address), abi=STABLESWAP_ABI)
    return contract.functions.add_liquidity(amounts, min_mint_amount).build_transaction({
        'from': user_address,
        'nonce': w3.eth.get_transaction_count(user_address),
    })

def remove_liquidity(w3: Web3, pool_address: str, amount: int, min_amounts: list, user_address: str) -> dict:
    contract = w3.eth.contract(address=w3.to_checksum_address(pool_address), abi=STABLESWAP_ABI)
    return contract.functions.remove_liquidity(amount, min_amounts).build_transaction({
        'from': user_address,
        'nonce': w3.eth.get_transaction_count(user_address),
    })
