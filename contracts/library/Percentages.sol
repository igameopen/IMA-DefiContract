// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

library Percentages {
    using SafeMath for uint256;

    function mulPercentage(uint256 a, uint16 b) internal pure returns(uint256) {
        return a.mul(uint256(b)).div(10000);
    }
}