// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title Pool
/// @dev All function calls are currently implemented without side effects
/// @notice Pool is a contract for collecting funds
/// @Author Crypt0zauruS

import "@openzeppelin/contracts/access/Ownable.sol";

error CollectIsFinished();
error GoalAlreadyReached();
error CollectNotFinished();
error FailtedToSendEther();
error NoContribution();
error NotEnoughFunds();

contract Pool is Ownable {
    uint256 public end;
    uint256 public goal;
    uint256 public totalCollected;

    mapping(address => uint256) public contributions;

    event Contribute(address indexed contributor, uint256 amount);
    event Refunded(address indexed contributor, uint256 amount);
    event Withdrawn(address indexed owner, uint256 amount);

    constructor(uint256 _duration, uint256 _goal) Ownable(msg.sender) {
        end = block.timestamp + _duration;
        goal = _goal;
    }

    /// @notice Allows contribution for the pool
    /// @dev If the pool is finished, it reverts
    /// @dev If the contribution is 0, it reverts
    /// @dev If the contribution is successful, it emits an event
    /// @dev If the contribution is successful, it adds the contribution to the totalCollected
    /// @dev If the contribution is successful, it adds the contribution to the contributions mapping

    function contribute() external payable {
        // same as require(block.timestamp < end, "Collect is finished"); but costs less gas
        if (block.timestamp >= end) {
            revert CollectIsFinished();
        }
        if (msg.value == 0) {
            revert NotEnoughFunds();
        }
        contributions[msg.sender] += msg.value;
        totalCollected += msg.value;
        emit Contribute(msg.sender, msg.value);
    }

    /// @notice Allows the owner to withdraw all the funds
    /// @dev If the pool is not finished, it reverts
    /// @dev If the goal is not reached, it reverts
    function withdraw() external onlyOwner {
        if (block.timestamp < end || totalCollected < goal) {
            revert CollectNotFinished();
        }

        (bool sent, ) = msg.sender.call{value: address(this).balance}("");
        if (!sent) {
            revert FailtedToSendEther();
        }
        emit Withdrawn(msg.sender, address(this).balance);
    }

    /// @notice Allows the contributors to get a refund if the goal is not reached and the pool is finished
    /// @dev If the pool is not finished, it reverts
    /// @dev If the goal is reached, it reverts
    /// @dev If the contributor has not contributed, it reverts
    /// @dev If the refund is successful, it emits an event
    /// @dev If the refund is successful, it subtracts the contribution from the totalCollected
    /// @dev If the refund is successful, it subtracts the contribution from the contributions mapping
    function refund() external {
        if (block.timestamp < end) {
            revert CollectNotFinished();
        }
        if (totalCollected >= goal) {
            revert GoalAlreadyReached();
        }
        if (contributions[msg.sender] == 0) {
            revert NoContribution();
        }
        uint amount = contributions[msg.sender];
        contributions[msg.sender] = 0;
        totalCollected -= amount;
        (bool sent, ) = msg.sender.call{value: amount}("");
        if (!sent) {
            revert FailtedToSendEther();
        }
        emit Refunded(msg.sender, amount);
    }
}
