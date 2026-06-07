defmodule Lux.Web3.Contracts.UniswapV3Factory do
  @moduledoc "Uniswap V3 Factory contract"
  use Ethers.Contract, abi_file: "priv/web3/abis/UniswapV3Factory.abi.json"
end

defmodule Lux.Web3.Contracts.UniswapV3Pool do
  @moduledoc "Uniswap V3 Pool contract"
  use Ethers.Contract, abi_file: "priv/web3/abis/UniswapV3Pool.abi.json"
end

defmodule Lux.Web3.Contracts.NonfungiblePositionManager do
  @moduledoc "Uniswap V3 NonfungiblePositionManager contract"
  use Ethers.Contract, abi_file: "priv/web3/abis/NonfungiblePositionManager.abi.json"
end

defmodule Lux.Web3.Contracts.SwapRouter do
  @moduledoc "Uniswap V3 SwapRouter contract"
  use Ethers.Contract, abi_file: "priv/web3/abis/SwapRouter.abi.json"
end
