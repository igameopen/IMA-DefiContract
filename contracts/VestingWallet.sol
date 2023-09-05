// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;
pragma abicoder v2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

abstract contract VestingWallet {
    using SafeMath for uint256;

    event ERC20Released(address indexed token, uint256 amount);

    struct PledgeRecord {
        uint256 timestamp;
        uint256 amount;
    }

    struct ReleasedRecord {
        address token;
        uint256 timestamp;
        uint256 amount;
    }

    mapping(address => ReleasedRecord[]) private _releasedRecords;

    mapping(address => mapping(address => PledgeRecord[])) private _pledge;
    mapping(address => mapping(address => uint256)) private _released;

    function vestingWallet(
        address beneficiary,
        address token,
        uint256 amount,
        uint256 start,
        uint256 duration,
        uint256 count
    ) internal {
        uint256 amountPerTime = amount.div(count);
        for (uint256 i = 0; i < count; i++) {
            _pledge[beneficiary][token].push(PledgeRecord(start.add(duration.mul(i)), amountPerTime));
        }
    }

    /**
     * @dev Amount of token already released
     */
    function released(address beneficiary, address token) internal view returns (uint256) {
        return _released[beneficiary][token];
    }

    /**
     * @dev Getter for the amount of releasable `token` tokens. `token` should be the address of an
     * IERC20 contract.
     */
    function releasable(address beneficiary, address token) internal view returns (uint256) {
        uint256 amount = 0;
        PledgeRecord[] memory records = _pledge[beneficiary][token];
        uint256 current = block.timestamp;
        for (uint i = 0; i < records.length; i++) {
            PledgeRecord memory record = records[i];
            if (record.timestamp <= current) {
                amount = amount.add(record.amount);
            }
        }
        amount = amount.sub(released(beneficiary, token));
        return amount;
    }

    function release(address token) internal returns (uint256) {
        uint256 amount = releasable(msg.sender, token);
        require(amount > 0, "VW: no amount");
        _released[msg.sender][token] = _released[msg.sender][token].add(amount);
        _releasedRecords[msg.sender].push(ReleasedRecord(token, block.timestamp, amount));
        emit ERC20Released(token, amount);
        return amount;
    }

    function pledging(address beneficiary, address token) internal view returns (uint256) {
        uint256 amount = 0;
        PledgeRecord[] memory records = _pledge[beneficiary][token];
        for (uint i = 0; i < records.length; i++) {
            PledgeRecord memory record = records[i];
            amount = amount.add(record.amount);
        }
        amount = amount.sub(released(beneficiary, token));
        return amount;
    }

    function releasedRecords(address beneficiary) public view returns (ReleasedRecord[] memory) {
        return _releasedRecords[beneficiary];
    }
}
