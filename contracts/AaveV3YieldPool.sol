//SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import { IAToken } from "@aave/core-v3/contracts/interfaces/IAToken.sol";
import { IPool } from "@aave/core-v3/contracts/interfaces/IPool.sol";
import { IPoolAddressesProvider } from "@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol";
import { IPoolAddressesProviderRegistry } from "@aave/core-v3/contracts/interfaces/IPoolAddressesProviderRegistry.sol";
import { IRewardsController } from "@aave/periphery-v3/contracts/rewards/interfaces/IRewardsController.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import { Manageable, Ownable } from "./Manageable.sol";
import { IYieldPool } from "./IYieldPool.sol";

contract AaveV3YieldPool is ERC20, IYieldPool, Manageable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // State vars
    IAToken public immutable aToken;
    IRewardsController public immutable rewardsController;
    IPoolAddressesProviderRegistry public immutable poolAddressesProviderRegistry;
    address private immutable _tokenAddress;
    uint256 private immutable _tokenUnit;
    uint8 private immutable _decimals;
    uint256 private constant ADDRESSES_PROVIDER_ID = uint256(0);
    // uint16 private constant REFERRAL_CODE = uint16(0);

    // Events
    event AaveV3YieldPoolInitialized(
        IAToken indexed aToken,
        IRewardsController rewardsController, 
        IPoolAddressesProviderRegistry poolAddressesProviderRegistry, 
        string name, string symbol, 
        uint8 decimals, 
        address indexed owner);

    event SuppliedTokenTo(address indexed from, uint256 shares, uint256 amount, address indexed to);
    event RedeemedToken(address indexed from, uint256 shares, uint256 amount);
    event Claimed(address indexed from, address indexed to, address[] rewardsList, uint256[] claimedAmounts);
    event DecresedERC20Allowance(address indexed from, address indexed spender, uint256 amount, IERC20 indexed token);
    event IncreasedERC20Allowance(address indexed from, address indexed spender, uint256 amount, IERC20 indexed token);
    event TransferredERC20(address indexed from, address indexed to, uint256 amount, IERC20 indexed token);

    constructor (
        IAToken _aToken,
        IRewardsController _rewardsController,
        IPoolAddressesProviderRegistry _poolAddressesProviderRegistry,
        string memory _name,
        string memory _symbol,
        uint8 decimals_,
        address _owner
    ) Ownable () ERC20 (_name, _symbol) ReentrancyGuard() {
        require(_owner != address(0), "AaveV3YieldPool: Owner can not be address 0");
        require(address(_aToken) != address(0), "AaveV3YieldPool: aToken can not be address 0");
        require(decimals_ > 0, "AaveV3YieldPool: Decimals can not be 0");
        require(address(_rewardsController) != address(0), "AaveV3YieldPool: Rewards controller can not be address 0");
        require(address(_poolAddressesProviderRegistry) != address(0), "AaveV3YieldPool: Addresses provider can not be address 0");

        aToken = _aToken;
        _decimals = decimals_;
        _tokenUnit = 10**decimals_;
        _tokenAddress = address(_aToken.UNDERLYING_ASSET_ADDRESS());
        rewardsController = _rewardsController;
        poolAddressesProviderRegistry = _poolAddressesProviderRegistry;

        IERC20(_tokenAddress).safeApprove(address(_pool()), type(uint256).max);

        emit AaveV3YieldPoolInitialized(_aToken, _rewardsController, _poolAddressesProviderRegistry, _name, _symbol, decimals_, _owner);
    }

    /**
     * @notice Returns total balance of asset tokens with deposit and interest
     * @param _user address to get balance for
     * @return Balance of asset token for address
     */
    function balanceOfToken(address _user) external view override returns (uint256) {
        return _sharesToToken(balanceOf(_user), _pricePerShare());
    }

    /**
     * @notice Calculates the number of asset tokens that user has in the yield pool
     * @param _shares Amount of shares
     * @param _fullShare Price of a full share
     * @return Number of asset tokens
     */
    function _sharesToToken(uint256 _shares, uint256 _fullShare) internal view returns (uint256) {
        // tokens = (shares * yieldPoolBalanceOfAToken) / totalSupply;
        return _shares == 0 ? _shares : (_shares * _fullShare) / _tokenUnit;

    }

    function _pool() internal view returns (IPool) {
        return IPool(IPoolAddressesProvider(poolAddressesProviderRegistry.getAddressesProvidersList()[ADDRESSES_PROVIDER_ID]).getPool());
    }
}