// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;
pragma abicoder v2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";

import "./library/Percentages.sol";

contract iGames is ERC20, Ownable {
    using Percentages for uint256;
    using SafeMath for uint256;
    
    address public constant POSITION_MANAGER = 0xC36442b4a4522E871399CD717aBDD847Ab11FE88;
    address public constant SWAP_ROUTER = 0xE592427A0AEce92De3Edee1F18E0157C05861564;

    address public constant MARKETING = 0xb728c15C35ADF40A8627a6dfA2614D8E84f03361;
    address public constant LP = 0x0d8ff05d9F10b3D3eC32E38bC03f0571B07B403b;

    address public constant WETH9 = 0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6;

    address public _uniswapV3Pool;

    uint16 public _marketingFee = 50;
    uint16 public _lpFee = 200;
    bool public _hasFee = true;

    modifier percentage(uint16 val) {
        require(val <= 10000, "out of limit");
        _;
    }

    constructor() ERC20("iGames", "IGS") {
        address thisAddr = address(this);
        _mint(thisAddr, 1_300_000_000 * 10 ** 18);
    } 

    function mintReward(address miner, uint256 amount) external onlyOwner {
        super._transfer(address(this), miner, amount);
    }

    function setHasFee(bool hasFee) external onlyOwner {
        _hasFee = hasFee;
    }

    function setLPFee(uint16 lpFee) external onlyOwner percentage(lpFee) {
        _lpFee = lpFee;
    }

    function setMarketingFee(uint16 marketingFee) external onlyOwner percentage(marketingFee) {
        _marketingFee = marketingFee;
    }

    function setUniswapV3Pool(address uniswapV3Pool) external onlyOwner {
        _uniswapV3Pool = uniswapV3Pool;
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        if (
            !_isSwapTransfer(from, to) || 
            _uniswapV3Pool == address(0) || 
            !_hasFee ||
            from == address(this) ||
            to == address(this)
        ) {
            super._transfer(from, to, amount);
            return;    
        }

        uint256 swapTokenAmount = balanceOf(address(this));
        if (swapTokenAmount >= 1 * 10 ** 18) {
            _swapIGSToEthInLP(swapTokenAmount);
        }

        uint256 lpFee = amount.mulPercentage(_lpFee);
        uint256 marketingFee = amount.mulPercentage(_marketingFee);
        uint256 trunAmount = amount.sub(lpFee).sub(marketingFee);

        if (from == _uniswapV3Pool) {
            super._transfer(from, address(this), lpFee);
        }
        if (to == _uniswapV3Pool) {
            super._transfer(from, LP, lpFee);
        }

        super._transfer(from, MARKETING, marketingFee);
        super._transfer(from, to, trunAmount);
    }

    function _isSwapTransfer(address from, address to) private view returns (bool) {
        return msg.sender != POSITION_MANAGER && (from == _uniswapV3Pool || to == _uniswapV3Pool);
    }

    function _swapIGSToEthInLP(uint256 amount) private {
        _approve(address(this), SWAP_ROUTER, amount);

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams(
            address(this),
            WETH9,
            IUniswapV3Pool(_uniswapV3Pool).fee(),
            LP,
            block.timestamp + 15,
            amount,
            0,
            0
        );
        ISwapRouter(SWAP_ROUTER).exactInputSingle(params);
    }
}