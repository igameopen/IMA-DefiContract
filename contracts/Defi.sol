// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;
pragma abicoder v2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap/v3-periphery/contracts/libraries/LiquidityAmounts.sol";
import "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import "./IERC20Metadata.sol";
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

    struct Pool {
        address token0;
        address token1;
        uint24 fee;
    }

    struct TokenInfo {
        string symbol;
        uint8 decimals;
    }

    struct RecommendRes {
        address recommend;
        uint160 liquidity;
    }

    struct TokenAmountRes {
        address token;
        string symbol;
        uint8 decimals;
        uint256 dividends;
        uint256 dividendsWithdraw;
        uint256 awards;
    }

    event Bind(address indexed account, address referrer);
    event Withdraw(address indexed account, address token, uint256 amount);
    event Mint(address indexed account);

    address public constant POSITION_MANAGER = 0xC36442b4a4522E871399CD717aBDD847Ab11FE88;

    address public constant WETH9 = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;

    address public constant MARKETING = 0xb728c15C35ADF40A8627a6dfA2614D8E84f03361;

    address public _igs;

    address public _uniswapV3Pool;
    Pool public _pool;
    address public _nftToken;

    uint256 public _shareHolderMinAmount = 2_600_000 ether;

    uint16 public _shareFee = 2000;

    mapping(address => Account) public _accountMap;
    address[] public _accounts;
    uint256 private _lastId = 1;

    EnumerableSet.AddressSet _dividends;
    mapping(address => TokenInfo) _tokenInfoMap;

    function setIGS(address token) external onlyOwner {
        _igs = token;
    }

    function setUniswapV3Pool(address uniswapV3Pool) external onlyOwner {
        _uniswapV3Pool = uniswapV3Pool;
        _pool.token0 = IUniswapV3Pool(_uniswapV3Pool).token0();
        _pool.token1 = IUniswapV3Pool(_uniswapV3Pool).token1();
        _pool.fee = IUniswapV3Pool(_uniswapV3Pool).fee();
    }

    function setShareHolderMinAmount(uint256 amount) external onlyOwner {
        _shareHolderMinAmount = amount;
    }

    function setNFTToken(address nftToken) external onlyOwner {
        _nftToken = nftToken;
    }

    function setShareFee(uint16 fee) external onlyOwner {
        _shareFee = fee;
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
        require(IIGamesNFT(_nftToken).balanceOf(sender) == 0, "Defi: can not mint");
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

        if (accountInfo.referrer == MARKETING) {
            IERC20(token).safeTransfer(sender, amount);
        } else {
            uint256 fee = amount.mul(_shareFee).div(10000);
            IERC20(token).safeTransfer(accountInfo.referrer, fee);
            IERC20(token).safeTransfer(sender, amount.sub(fee));
            
            _accountMap[accountInfo.referrer].awards[token] += fee;
        }

        accountInfo.dividends[token] -= amount;
        accountInfo.dividendsWithdraw[token] += amount;

        emit Withdraw(sender, token, amount);
    }

    function isBind(address account) public view returns(bool) {
        return _accountMap[account].id != 0;
    }

    function isShareholder(address account) public view returns(bool) {
        (uint256 amountIGS, , ) = _poolLiquidityAndPrincipalForAccount(account);
        return amountIGS >= _shareHolderMinAmount;
    }

    function getLiquidityGross(address account) public view returns(uint160) {
        if (_accountMap[account].id == 0) return 0;
        ( , , uint160 liquidityGross) = _poolLiquidityAndPrincipalForAccount(account);
        return liquidityGross;
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

    function poolSqrtPriceX96() external view returns(uint160) {
        if (_uniswapV3Pool == address(0)) return 0;
        (uint160 sqrtPriceX96, , , , , , ) = IUniswapV3Pool(_uniswapV3Pool).slot0();
        return sqrtPriceX96;
    }

    function dividendsRecord(address account) external view returns(TokenAmountRes[] memory) {
        if (_accountMap[account].id == 0) return new TokenAmountRes[](0);

        uint256 currentIndex = 0;

        for (uint i = 0; i < _dividends.length(); i++) {
            address token = _dividends.at(i);
            if (
                _accountMap[account].dividends[token] > 0 ||
                _accountMap[account].dividendsWithdraw[token] > 0 ||
                _accountMap[account].awards[token] > 0
                ) 
            {
                currentIndex ++;
            }
        }

        TokenAmountRes[] memory results = new TokenAmountRes[](currentIndex);
        currentIndex = 0;
        for (uint i = 0; i < _dividends.length(); i++) {
            address token = _dividends.at(i);
            uint256 dividends = _accountMap[account].dividends[token];
            uint256 dividendWithdraw = _accountMap[account].dividendsWithdraw[token];
            uint256 awards = _accountMap[account].awards[token];
            if (dividends > 0 || dividendWithdraw > 0 || awards > 0) {
                results[currentIndex] = TokenAmountRes(
                    token, 
                    _tokenInfoMap[token].symbol, 
                    _tokenInfoMap[token].decimals,
                    dividends,
                    dividendWithdraw,
                    awards
                );
            }
        }
        return results;
    }

    function recommends(address account) external view returns(RecommendRes[] memory) {
        if (_accountMap[account].id == 0) return new RecommendRes[](0);

        Account storage accountInfo = _accountMap[account];

        RecommendRes[] memory results = new RecommendRes[](accountInfo.recommends.length);

        for (uint256 i = 0; i < accountInfo.recommends.length; i ++) {
            address recommend = accountInfo.recommends[i];
            (, , uint128 liquidity) = _poolLiquidityAndPrincipalForAccount(recommend);
            results[i] = RecommendRes(
                recommend,
                liquidity
            );
        }
        return results;
    }

    function recommendCount(address account) external view returns(uint256) {
        if (_accountMap[account].id == 0) return 0;
        return _accountMap[account].recommends.length;
    }

    function recommendLiquidityGross(address account) external view returns(uint128) {
        if (_accountMap[account].id == 0) return 0;
        uint128 liquidityGross = 0;
        for (uint256 i = 0; i < _accountMap[account].recommends.length; i++) {
            (, , uint128 liquidity) = _poolLiquidityAndPrincipalForAccount(_accountMap[account].recommends[i]);
            liquidityGross += liquidity;
        }
        return liquidityGross;
    }

    function gameDividend(address token, uint256 amount) external onlyOwner {
        require(_uniswapV3Pool != address(0), "Defi: pool not init");
        require(amount > 0, "Defi: amount not be zero");
        IERC20(token).safeTransferFrom(_msgSender(), address(this), amount);
        if (!_dividends.contains(token)) {
            _dividends.add(token);
            _tokenInfoMap[token].decimals = IERC20Metadata(token).decimals();
            _tokenInfoMap[token].symbol = IERC20Metadata(token).symbol();
        }
        uint128 liquidityGross = IUniswapV3Pool(_uniswapV3Pool).liquidity();
        
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
            if (_pool.token0 == token0 && _pool.token1 == token1 && _pool.fee == fee && liquidity > 0) {
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
        return _igs < WETH9;
    }
}