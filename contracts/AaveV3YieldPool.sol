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
     * @notice The address of ERC20 asset token user used for deposits
     * @return ERC20 asset token address
     */
    function depositToken() public view override returns (address) {
        return _tokenAddress;
    }

    /**
     * @notice yield pool ERC20 decimals
     * @dev This value should be equal to the decimals of the token used to deposit into the pool
     * @return number of decimals
     */
    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    /**
     * @notice This function supplies asset token to the yield pool
     * @dev _shares corresponding to the number of tokens supplied are minted to the user's balance
     * @dev asset tokens are supplied to the yield pool and than deposited into Aave
     * @param _depositAmount -> amount of asset tokens to be supplied
     * @param _to -> User who will receive the shares
     */
    function supplyTokenTo(uint256 _depositAmount, address _to) external override nonReentrant {
        uint256 _shares = _tokenToShares(_depositAmount, _pricePerShare());
        uint16 _refferalCode = 0;
        _requireSharesGreaterThanZero(_shares);
        IERC20(_tokenAddress).safeTransferFrom(msg.sender, address(this), _depositAmount);
        _pool().supply(_tokenAddress, _depositAmount, address(this), _refferalCode);
        _mint(_to, _shares);
        emit SuppliedTokenTo(msg.sender, _shares, _depositAmount, _to);
    }

    /**
     * @notice withdraws asset token from yield pool
     * @dev _shares corresponding to the number of tokens withdrawn are burnt from the user's balance
     * @dev asset tokens are withdrawn from Aave and than transferred from yield pool to user's address
     * @param _redeemAmount -> amount of asset tokens to be withdrawn
     * @return Amount of asset tokens that were withdrawn
     */
    function redeemToken(uint256 _redeemAmount) external override nonReentrant returns (uint256) {
        uint256 _shares = _tokenToShares(_redeemAmount, _pricePerShare());
        _requireSharesGreaterThanZero(_shares);
        _burn(msg.sender, _shares);
        IERC20 _assetToken = IERC20(_tokenAddress);
        uint256 _beforeBalance = _assetToken.balanceOf(address(this));
        _pool().withdraw(_tokenAddress, _redeemAmount, address(this));
        uint256 _balanceDifference;

        unchecked {
            _balanceDifference = _assetToken.balanceOf(address(this)) - _beforeBalance;
        }

        _assetToken.safeTransfer(msg.sender, _balanceDifference);
        emit RedeemedToken(msg.sender, _shares, _redeemAmount);
        return _balanceDifference;
    }

    /**
     * @notice Claims accured rewards for the aToken accumulating any pending rewards
     * @dev Can be called only by owner or manager
     * @param _to -> address where the claimed rewards should be sent 
     */
    function claimRewards(address _to) external onlyManagerOrOwner {
        require(_to != address(0), "AaveV3YieldPool: Can not claim rewards to address 0");
        address[] memory _assets = new address[](1);
        _assets[0] = address(aToken);
        (address[] memory _rewardsList, uint256[] memory _claimedAmounts) = rewardsController.claimAllRewards(_assets, _to);
        emit Claimed(msg.sender, _to, _rewardsList, _claimedAmounts);
    }

    /**
     * @notice Decreases the allowance of ERC20 tokens other than aTokens held by this contract
     * @dev Only owner of manager can call this function
     * @dev Current allowance should be computed off-chain to avoid any underflow
     * @param _token -> address of the ERC20 token to decrease allowance for
     * @param _spender -> address of the spender of the tokens
     * @param _amount -> amount of tokens to decrease allowance by
     */
    function decreaseERC20Allowance(IERC20 _token, address _spender, uint256 _amount) external onlyManagerOrOwner {
        _requireNotAToken(address(_token));
        _token.safeDecreaseAllowance(_spender, _amount);
        emit DecresedERC20Allowance(msg.sender, _spender, _amount, _token);
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


    /**
     * @notice This function calculates the number of shares that should be minted or burnt when user deposit or withdraw asset tokens
     * @param _tokens Amount of asset tokens
     * @param _fullShare Price of a full share
     * @return Number of shares
     */
    function _tokenToShares(uint256 _tokens, uint256 _fullShare) internal view returns (uint256) {
        // shares = (tokens * totalSuppply) / yieldPoolBalanceOfAToken
        return _tokens == 0 ? _tokens : (_tokens * _tokenUnit) / _fullShare;
    }

    /**
     * @notice Function calculates the price of a full share
     * @dev This calculation is used to ensure that the price per share can not be manipulated
     * @return The current price per share
     */
    function _pricePerShare() internal view returns (uint256) {
        uint256 _supply = totalSupply();
        // pricePerShare = (token * yieldPoolBalanceOfAToken) / totalSupply
        return _supply == 0 ? _tokenUnit : (_tokenUnit * aToken.balanceOf(address(this))) / _supply;
    }

    function _requireSharesGreaterThanZero(uint256 _shares) internal pure {
        require(_shares > 0, "AaveV3YieldPool: Shares must be greater than zero");
    }

    /**
     * @notice Retrieves Aave pool address
     * @return Reference to Pool interface
     */
    function _pool() internal view returns (IPool) {
        return IPool(IPoolAddressesProvider(poolAddressesProviderRegistry.getAddressesProvidersList()[ADDRESSES_PROVIDER_ID]).getPool());
    }
}