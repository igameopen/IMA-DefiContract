// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract iGames is ERC20, Ownable {
    constructor() ERC20("iGameS", "IGS") {
        _mint(msg.sender, 1_300_000_000 ether);
    }
}