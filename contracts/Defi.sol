// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap/v3-periphery/contracts/libraries/LiquidityAmounts.sol";
import "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import "./IIGamesNFT.sol";

contract Defi is Ownable {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeMath for uint256;

    struct Account {
        uint256 id;
        address referrer;
        address[] recommends;
        mapping(address => uint256) dividends;
        mapping(address => uint256) dividendsWithdraw;
        mapping(address => uint256) awards;
    }

    event Bind(address indexed account, address referrer);
    event Withdraw(address indexed account, address token, uint256 amount);
    event Mint(address indexed account);

    address public constant POSITION_MANAGER = 0xC36442b4a4522E871399CD717aBDD847Ab11FE88;

    address public constant WETH9 = 0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6;

    address public constant MARKETING = 0xb728c15C35ADF40A8627a6dfA2614D8E84f03361;

    address public _uniswapV3Pool;
    address public _nftToken;

    uint public _shareHolderMinAmount = 2_550_000 ether;

    mapping(address => Account) public _accountMap;
    address[] public _accounts;
    uint256 private _lastId = 1;

    EnumerableSet.AddressSet _dividends;

    function setUniswapV3Pool(address pool) external onlyOwner {
        _uniswapV3Pool = pool;
    }

    function setShareHolderMinAmount(uint amount) external onlyOwner {
        _shareHolderMinAmount = amount;
    }

    function setNFTToken(address nftToken) external onlyOwner {
        _nftToken = nftToken;
    }

    function bind(address referrer) external {
        address sender = _msgSender();
        if (_accountMap[sender].id != 0) return;

        require(referrer == MARKETING || (_accountMap[referrer].id != 0 && isShareholder(referrer)), "Registered: referrer is not registered or not shareholder");
        Account storage accountInfo = _accountMap[sender];
        accountInfo.id = _lastId;
        accountInfo.referrer = referrer;
        _lastId ++;
        _accountMap[referrer].recommends.push(msg.sender);
        _accounts.push(sender);
        
        emit Bind(sender, referrer);
    }

    function mint() external {
        require(_nftToken != address(0), "Defi: NFT not init");
        address sender = _msgSender();
        require(isShareholder(sender), "Defi: not shareholder");
        IIGamesNFT(_nftToken).mint(sender);

        emit Mint(sender);
    }

    function withdraw(address token, uint256 amount) external {
        address sender = _msgSender();
        require(_accountMap[sender].id != 0, "Registered: not registered");
        Account storage accountInfo = _accountMap[sender];
        uint256 balance = accountInfo.dividends[token];
        require(balance >= amount, "Defi: amount exceeds balance");
        uint256 fee = amount.div(5);
        IERC20(token).safeTransfer(accountInfo.referrer, fee);
        IERC20(token).safeTransfer(sender, amount.sub(fee));

        accountInfo.dividends[token] -= amount;
        accountInfo.dividendsWithdraw[token] += amount;
        _accountMap[accountInfo.referrer].awards[token] += fee;

        emit Withdraw(sender, token, amount);
    }

    function isShareholder(address account) public view returns(bool) {
        (uint256 amountIGS, , ) = _poolLiquidityAndPrincipalForAccount(account);
        return amountIGS >= _shareHolderMinAmount;
    }

    function shareholderCount() public view returns(uint256) {
        uint256 count = 0;
        for (uint256 i = 0; i < _accounts.length; i++) {
            if (isShareholder(_accounts[i])) {
                count ++;
            }
        }
        return count;
    }

    function gameDividend(address token, uint256 amount) external onlyOwner {
        require(_uniswapV3Pool != address(0), "Defi: pool not init");
        require(amount > 0, "Defi: amount not be zero");
        IERC20(token).safeTransferFrom(_msgSender(), address(this), amount);
        _dividends.add(token);
        (, int24 tick, , , , ,) = IUniswapV3Pool(_uniswapV3Pool).slot0();
        (uint128 liquidityGross, , , , , , ,) = IUniswapV3Pool(_uniswapV3Pool).ticks(tick);
        
        for (uint256 i = 0; i < _accounts.length; i++) {
            address account = _accounts[i];
            (uint256 amountIGS, , uint128 totalLiquidity) = _poolLiquidityAndPrincipalForAccount(account);
            if (amountIGS >= _shareHolderMinAmount) {
                _accountMap[account].dividends[token] = _accountMap[account].dividends[token].add(amount.mul(uint256(totalLiquidity).div(uint256(liquidityGross))));
            }
        }
    }

    function gameWithdraw(address token, uint256 amount, address recipient) external onlyOwner {
        IERC20(token).safeTransfer(recipient, amount);
    }

    function _poolLiquidityAndPrincipalForAccount(address account) private view returns(uint256 amountIGS, uint256 amountETH, uint128 liquidityGross) {
        if (_uniswapV3Pool == address(0) || _accountMap[account].id == 0) return (0, 0, 0);
        uint256 balance = INonfungiblePositionManager(POSITION_MANAGER).balanceOf(account);
        if (balance == 0) return (0, 0, 0);
        address poolToken0 = IUniswapV3Pool(_uniswapV3Pool).token0();
        address poolToken1 = IUniswapV3Pool(_uniswapV3Pool).token1();
        uint24 poolFee = IUniswapV3Pool(_uniswapV3Pool).fee();
        (uint160 sqrtPriceX96, , , , , , ) = IUniswapV3Pool(_uniswapV3Pool).slot0();

        for (uint256 i = 0; i < balance; i++) {
            uint256 tokenId = INonfungiblePositionManager(POSITION_MANAGER).tokenOfOwnerByIndex(account, i);
            (
                , 
                , 
                address token0, 
                address token1, 
                uint24 fee, 
                int24 tickLower, 
                int24 tickUpper, 
                uint128 liquidity,
                ,
                ,
                ,
            ) = INonfungiblePositionManager(POSITION_MANAGER).positions(tokenId);
            if (poolToken0 == token0 && poolToken1 == token1 && poolFee == fee && liquidity > 0) {
                (uint256 amount0, uint256 amount1) = _principal(sqrtPriceX96, tickLower, tickUpper, liquidity);
                if (_isToken0()) {
                    amountIGS += amount0;
                    amountETH += amount1;
                } else {
                    amountIGS += amount1;
                    amountETH += amount0;
                }
                liquidityGross += liquidity;
            }
        }
    }

    function _principal(uint160 sqrtPriceX96, int24 tickLower, int24 tickUpper, uint128 liquidity) private pure returns (uint256 amount0, uint256 amount1) {
        return
            LiquidityAmounts.getAmountsForLiquidity(
                sqrtPriceX96,
                TickMath.getSqrtRatioAtTick(tickLower),
                TickMath.getSqrtRatioAtTick(tickUpper),
                liquidity
            );
    }

    function _isToken0() private view returns(bool) {
        return address(this) < WETH9;
    }
}