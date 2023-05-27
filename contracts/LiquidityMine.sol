// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;
pragma abicoder v2;

import "@uniswap/v3-periphery/contracts/libraries/LiquidityAmounts.sol";
import "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import "@uniswap/v3-core/contracts/libraries/SqrtPriceMath.sol";
import "@uniswap/v3-core/contracts/libraries/Tick.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./interfaces/IWETH9.sol";

contract LiquidityMine is Ownable, ERC721Holder {
    using SafeMath for uint256;

    struct Position {
        uint256 tokenId;
        address token0;
        address token1;
        uint24 fee;
        uint128 liquidity;
        uint256 amount0;
        uint256 amount1;
    }

    struct User {
        uint256 id;
        address referrer;
        address[] recommends;
        uint256 depositETH;
        uint256 depositIGS;
        bool isBenefited;
        Liquidity[] liquidities;
        uint256 withdrawETH;
        uint256 withdrawIGS;
        uint256 benefitedETH;
        uint256 benefitedIGS;
    }

    struct Liquidity {
        uint256 tokenId;
        uint128 liquidity;
        uint256 depositETH;
        uint256 depositIGS;
        uint256 initFeeETH;
        uint256 initFeeIGS;
    }

    struct Recommend {
        address recommend;
        uint128 liquidity;
    }

    modifier registered(address user) {
        require(_isRegistered(user), "Registered: user is not registered");
        _;
    }

    event Deposit(address indexed user, uint256 indexed tokenId, uint128 liquidity);
    event Withdraw(address indexed user, address indexed token, uint256 amount);

    address public constant POSITION_MANAGER = 0xC36442b4a4522E871399CD717aBDD847Ab11FE88;

    address public constant WETH9 = 0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6;

    address public constant MARKETING = 0xb728c15C35ADF40A8627a6dfA2614D8E84f03361;
    address public constant LP = 0x0d8ff05d9F10b3D3eC32E38bC03f0571B07B403b;

    address public _pool;
    address public _igs;

    uint256 public _lastUserId = 1;
    mapping (address => User) public _users;

    uint128 public _feeLiquidity;
    uint256 public _feeTotalETH;
    uint256 public _feeTotalIGS;
    uint256 public _feeWithdrawETH;
    uint256 public _feeWithdrawIGS;

    constructor() {

    }

    function setPool(address pool) onlyOwner external {
        _pool = pool;
    }

    function setIGS(address igs) onlyOwner external {
        _igs = igs;
    }

    function liquidities() external view returns(Position[] memory) {
        uint256 totalNFT = INonfungiblePositionManager(POSITION_MANAGER).balanceOf(msg.sender);

        address poolToken0 = IUniswapV3Pool(_pool).token0();
        address poolToken1 = IUniswapV3Pool(_pool).token1();
        uint24 poolFee = IUniswapV3Pool(_pool).fee();
        (uint160 sqrtPriceX96, int24 tick, , , , , ) = IUniswapV3Pool(_pool).slot0();

        Position[] memory positions = new Position[](totalNFT);

        uint256 igsToEthTokenCount = 0;

        for (uint256 i = 0; i < totalNFT; i++) {
            uint256 tokenId = INonfungiblePositionManager(POSITION_MANAGER).tokenOfOwnerByIndex(msg.sender, i);
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
            if (poolToken0 == token0 && poolToken1 == token1 && poolFee == fee) {
                (int256 amount0, int256 amount1) = _getAmountDelta(tick, sqrtPriceX96, tickLower, tickUpper, int128(liquidity));
                Position memory position = Position (
                    tokenId,
                    token0,
                    token1,
                    fee,
                    liquidity,
                    uint(amount0),
                    uint(amount1)
                );
                positions[igsToEthTokenCount] = position;
                igsToEthTokenCount++;
            }
        }

        Position[] memory newPositions = new Position[](igsToEthTokenCount);
        for (uint256 i = 0; i < igsToEthTokenCount; i++) {
            newPositions[i] = positions[i];
        }

        return newPositions;
    }

    function userLiquidities() external view registered(msg.sender) returns (Position[] memory) {
        uint256 liquidityCount = _users[msg.sender].liquidities.length;
        Position[] memory array = new Position[](liquidityCount);

        address token0 = IUniswapV3Pool(_pool).token0();
        address token1 = IUniswapV3Pool(_pool).token1();
        uint24 fee = IUniswapV3Pool(_pool).fee();


        for (uint256 i = 0; i < liquidityCount; i++) {
            Liquidity memory liquidityInfo = _users[msg.sender].liquidities[i];
            
            Position memory position = Position (
                liquidityInfo.tokenId,
                token0,
                token1,
                fee,
                liquidityInfo.liquidity,
                liquidityInfo.depositETH,
                liquidityInfo.depositIGS
            );
            array[i] = position;
        }
        return array;
    }

    function userInfoDetail()
        external 
        view 
        returns (
            uint160 sqrtPriceX96,
            bool isBenefited,
            uint128 liquidity,
            uint256 balanceETH,
            uint256 balanceIGS,
            uint256 withdrawETH,
            uint256 withdrawIGS,
            uint256 benefitedETH,
            uint256 benefitedIGS
        )
    {
        (sqrtPriceX96, , , , , , ) = IUniswapV3Pool(_pool).slot0();
        User memory userInfo = _users[msg.sender];
        if (userInfo.id != 0) {
            isBenefited = userInfo.isBenefited;
            liquidity = _getUserLiquidity(msg.sender);
            (balanceETH, balanceIGS) = _getUserBalance(msg.sender);
            withdrawETH = userInfo.withdrawETH;
            withdrawIGS = userInfo.withdrawIGS;
            benefitedETH = userInfo.benefitedETH;
            benefitedIGS = userInfo.benefitedIGS;
        }

    }

    function recommendCount() external view returns (uint256) {
        return _users[msg.sender].recommends.length;
    }

    function recommendLiquidities() external view returns (uint128 liquidity) {
        for (uint i = 0; i < _users[msg.sender].recommends.length; i++) {
            liquidity += _getUserLiquidity(_users[msg.sender].recommends[i]);
        }
    }

    function recommends() external view returns (Recommend[] memory) {
        uint256 count = _users[msg.sender].recommends.length;
        Recommend[] memory recommendArr = new Recommend[](count);
        for (uint i = 0; i < count; i++) {
            recommendArr[i].recommend = _users[msg.sender].recommends[i];
            recommendArr[i].liquidity = _getUserLiquidity(_users[msg.sender].recommends[i]);
        }
        return recommendArr;
    }

    function bind(address referrer) external {
        bool isRegistered = _isRegistered(msg.sender);
        if(isRegistered) return;

        require(_isRegistered(referrer) || referrer == MARKETING, "Registered: referrer is not registered");
        User storage userInfo = _users[msg.sender];
        userInfo.id = _lastUserId;
        userInfo.referrer = referrer;
        _lastUserId ++;
        _users[referrer].recommends.push(msg.sender); 
    }

    function deposit(uint256 tokenId) external registered(msg.sender) {
        INonfungiblePositionManager(POSITION_MANAGER).safeTransferFrom(msg.sender, address(this), tokenId);

        _updateFee();

        (uint160 sqrtPriceX96, int24 tick, , , , , ) = IUniswapV3Pool(_pool).slot0();

        (
            ,
            ,
            ,
            ,
            ,
            int24 tickLower,
            int24 tickUpper,
            uint128 liquidity,
            ,
            ,
            ,
        ) = INonfungiblePositionManager(POSITION_MANAGER).positions(tokenId);

        _feeLiquidity += liquidity;

        (int256 amount0, int256 amount1) = _getAmountDelta(tick, sqrtPriceX96, tickLower, tickUpper, int128(liquidity));
        if (amount0 < 0) amount0 = 0;
        if (amount1 < 0) amount0 = 0;
        (uint256 ethAmount, uint256 igsAmount) = WETH9 < _igs ? (uint256(amount0), uint256(amount1)) : (uint256(amount1), uint256(amount0));

        User storage userInfo = _users[msg.sender];
        userInfo.depositETH += ethAmount;
        userInfo.depositIGS += igsAmount;

        Liquidity memory liquidityInfo = Liquidity(
            tokenId,
            liquidity,
            ethAmount,
            igsAmount,
            _feeTotalETH,
            _feeTotalIGS
        );

        userInfo.liquidities.push(liquidityInfo);

        if (userInfo.depositETH >= 0.5 ether) userInfo.isBenefited = true;

        emit Deposit(msg.sender, tokenId, liquidity);
    }

    function withdrawLiquidity(uint256 tokenId) external registered(msg.sender) {
        User storage userInfo = _users[msg.sender];
        int256 index = -1;
        for (uint256 i = 0; i < userInfo.liquidities.length; i++) {
            if(userInfo.liquidities[i].tokenId == tokenId) {
                index = int256(i);
                break;
            }
        }
        if (index < 0) return;

        INonfungiblePositionManager(POSITION_MANAGER).safeTransferFrom(address(this), msg.sender, tokenId);

        Liquidity memory liquidity = userInfo.liquidities[uint(index)];

        userInfo.depositETH -= liquidity.depositETH;
        userInfo.depositIGS -= liquidity.depositIGS;
        if (userInfo.depositETH < 0.5 ether && userInfo.isBenefited == true) {
            userInfo.isBenefited = false;
        }
        _feeLiquidity -= liquidity.liquidity;

        for (uint256 i = uint256(index); i < userInfo.liquidities.length - 1; i++){
            userInfo.liquidities[i] = userInfo.liquidities[i + 1];
        }

        userInfo.liquidities.pop();

        _updateFee();
    }

    function withdrawUserIGS() external registered(msg.sender) {
        (, uint256 amountIGS) = _getUserBalance(msg.sender);
        User storage userInfo = _users[msg.sender];
        User storage referrerInfo = _users[userInfo.referrer];
        if (referrerInfo.isBenefited) {
            uint256 benefitedAmount = amountIGS.mul(2).div(10);
            IERC20(_igs).transferFrom(LP, userInfo.referrer, benefitedAmount);
            IERC20(_igs).transferFrom(LP, msg.sender, amountIGS.sub(benefitedAmount));

            referrerInfo.benefitedIGS = referrerInfo.benefitedIGS.add(benefitedAmount);
        } else {
            IERC20(_igs).transferFrom(LP, msg.sender, amountIGS);
        }

        userInfo.withdrawIGS = userInfo.withdrawIGS.add(amountIGS);
        _feeWithdrawIGS = _feeWithdrawIGS.add(amountIGS);

        _updateFee();

        emit Withdraw(msg.sender, _igs, amountIGS);
    }

    function withdrawUserETH() external registered(msg.sender) {
        (uint256 amountETH, ) = _getUserBalance(msg.sender);
        User storage userInfo = _users[msg.sender];
        User storage referrerInfo = _users[userInfo.referrer];

        IWETH9(WETH9).transferFrom(LP, address(this), amountETH);
        IWETH9(WETH9).withdraw(amountETH);
        if (referrerInfo.isBenefited) {
            uint256 benefitedAmount = amountETH.mul(2).div(10);

            payable(userInfo.referrer).transfer(benefitedAmount);
            payable(msg.sender).transfer(amountETH.sub(benefitedAmount));

            referrerInfo.benefitedETH = referrerInfo.benefitedIGS.add(benefitedAmount);
        } else {
            payable(msg.sender).transfer(amountETH);
        }

        userInfo.withdrawETH = userInfo.withdrawETH.add(amountETH);
        _feeWithdrawETH = _feeWithdrawIGS.add(amountETH);

        _updateFee();

        emit Withdraw(msg.sender, WETH9, amountETH);
    }

    function _isRegistered(address user) private view returns(bool) {
        return _users[user].id != 0;
    }

    function _updateFee() private {
        _feeTotalETH = IERC20(WETH9).balanceOf(LP).add(_feeWithdrawETH);
        _feeTotalIGS = IERC20(_igs).balanceOf(LP).add(_feeWithdrawIGS);
    }

    function _getAmountDelta(int24 tick, uint160 sqrtPriceX96, int24 tickLower, int24 tickUpper, int128 liquidityDelta) private pure returns (int256 amount0, int256 amount1) {
        // (, int24 tick, , , , , ) IUniswapV3Pool(POOL).slot0();
        if (liquidityDelta != 0) {
            if (tick < tickLower) {
                amount0 = SqrtPriceMath.getAmount0Delta(
                    TickMath.getSqrtRatioAtTick(tickLower),
                    TickMath.getSqrtRatioAtTick(tickUpper),
                    liquidityDelta
                );
            } else if (tick < tickUpper) {
                amount0 = SqrtPriceMath.getAmount0Delta(
                    sqrtPriceX96,
                    TickMath.getSqrtRatioAtTick(tickUpper),
                    liquidityDelta
                );
                amount1 = SqrtPriceMath.getAmount1Delta(
                    TickMath.getSqrtRatioAtTick(tickLower),
                    sqrtPriceX96,
                    liquidityDelta
                );
            } else {
                amount1 = SqrtPriceMath.getAmount1Delta(
                    TickMath.getSqrtRatioAtTick(tickLower),
                    TickMath.getSqrtRatioAtTick(tickUpper),
                    liquidityDelta
                );
            }
        }
    }

    function _getUserLiquidity(address user) private view returns (uint128 liquidity) {
        for (uint i = 0; i < _users[user].liquidities.length; i++) {
            liquidity += _users[user].liquidities[i].liquidity;
        }
    }

    function _getUserBalance(address user) private view returns(uint256 amountETH, uint256 amountIGS) {
        if (_feeLiquidity == 0) return (0, 0);

        User memory userInfo = _users[user];

        for (uint i = 0; i < userInfo.liquidities.length; i++) {
            Liquidity memory liquidity = userInfo.liquidities[i];
            uint128 proportion = liquidity.liquidity / _feeLiquidity;
            amountETH += _feeTotalETH.sub(liquidity.initFeeETH).mul(proportion);
            amountIGS += _feeTotalIGS.sub(liquidity.initFeeIGS).mul(proportion);
        }

        amountETH -= userInfo.withdrawETH;
        amountIGS -= userInfo.withdrawIGS;
    }

    receive() external payable {}
    fallback() external {}
}