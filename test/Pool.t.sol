// SPDX-License_Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Test.sol";
import {Pool} from "../src/Pool.sol";

contract PoolTest is Test {
    // test addresses
    address owner = makeAddr("User0");
    address contributor = makeAddr("User1");
    address contributor2 = makeAddr("User2");
    address contributor3 = makeAddr("User3");
    // test variables
    uint256 duration = 4 weeks;
    uint256 goal = 10 ether;

    Pool pool; // pool variable instantiating the Pool contract

    // function called between each test, beforeEach equivalent
    function setUp() public {
        vm.prank(owner); // set the owner
        pool = new Pool(duration, goal); // instantiate the Pool contract
    }

    // Tests deployment
    function test_ContractDeployedSuccessfully() public {
        // check if the contract is deployed correctly
        address _owner = pool.owner();
        assertEq(_owner, owner);
        uint256 _end = pool.end();
        assertEq(block.timestamp + duration, _end);
        uint256 _goal = pool.goal();
        assertEq(goal, _goal);
    }

    // Tests contribution
    function test_RevertWhen_EndIsReached() public {
        // set 1 hour after the end time to now
        vm.warp(pool.end() + 3600);
        // check if the contract reverts when the end is reached
        // checking if custom error "CollectIsFinished()" is thrown
        bytes4 selector = bytes4(keccak256("CollectIsFinished()"));
        vm.expectRevert(abi.encodeWithSelector(selector));

        vm.prank(contributor); // set the contributor
        vm.deal(contributor, 1 ether); // give 1 ether to the contributor
        pool.contribute{value: 1 ether}(); // call the contribute function to give 1 ether
    }

    function test_RevertWhen_NotEnoughFunds() public {
        // check if the contract reverts when the contribution is 0
        // checking if custom error "NotEnoughFunds()" is thrown
        bytes4 selector = bytes4(keccak256("NotEnoughFunds()"));
        vm.expectRevert(abi.encodeWithSelector(selector));

        vm.prank(contributor); // set the contributor
        pool.contribute(); // call the contribute function to give 0 ether
    }

    function test_ExpectEmit_SuccessfulContribute(uint96 _amount) public {
        // foundry allows to use random values for testing, here we use the random value for the amount
        // it's a real advantage for testing, not possible with Hardhat
        // it's a uint96 because foundry doesn't support uint256 for random values
        // foundry knows _amount is a random value because of the function name
        // we must assume that the random value is greater than 0, otherwise the test will fail
        vm.assume(_amount > 0);
        // true means an indexed value, false means a non-indexed value, maximum 3 indexed values per event
        // the last true means that the event is emitted
        vm.expectEmit(true, false, false, true);
        emit Pool.Contribute(address(contributor), _amount);
        vm.prank(contributor); // set the contributor
        vm.deal(contributor, _amount); // give _amount ether to the contributor
        pool.contribute{value: _amount}(); // call the contribute function to give _amount ether
    }

    // Tests withdraw
    function test_revertWhen_NotTheOwner() public {
        // check if the contract reverts when the caller is not the owner
        // custom error "OwnableUnauthorizedAccount(address)" from Ownable is thrown
        bytes4 selector = bytes4(
            keccak256("OwnableUnauthorizedAccount(address)")
        );
        vm.expectRevert(abi.encodeWithSelector(selector, contributor));
        vm.prank(contributor); // set the contributor
        pool.withdraw(); // call the withdraw function
    }

    function test_RevertWhen_EndIsNotReached() public {
        // check if the contract reverts when the end is not reached
        // checking if custom error "CollectNotFinished()" is thrown
        bytes4 selector = bytes4(keccak256("CollectNotFinished()"));
        vm.expectRevert(abi.encodeWithSelector(selector));

        vm.prank(owner); // set the owner
        pool.withdraw(); // call the withdraw function
    }

    function test_RevertWhen_GoalIsNotReached() public {
        vm.prank(contributor); // set the contributor
        vm.deal(contributor, 1 ether); // give 1 ether to the contributor
        pool.contribute{value: 1 ether}(); // call the contribute function to give 1 ether
        // check if the contract reverts when the goal is not reached after the end is reached
        vm.warp(pool.end() + 3600); // set 1 hour after the end time to now
        bytes4 selector = bytes4(keccak256("CollectNotFinished()"));
        vm.expectRevert(abi.encodeWithSelector(selector));
        vm.prank(owner); // set the owner
        pool.withdraw(); // call the withdraw function
    }

    function test_RevertWhen_WithdrawFailedToSendEther() public {
        // check if the contract reverts when the withdraw failed to send ether
        // to perform this test, we need a contract that CAN'T receive ether (no receive or fallback or payable function)
        // So we use this PoolTest contract itself !
        // So here, this test contract become the owner of the pool contract
        pool = new Pool(duration, goal);
        // goal is 10 ether, we need to contribute at least 10 ether to reach the goal
        vm.prank(contributor); // set the contributor
        vm.deal(contributor, 6 ether); // give goal ether to the contributor
        pool.contribute{value: 6 ether}(); // call the contribute function to give goal ether

        vm.prank(contributor2); // set the contributor
        vm.deal(contributor2, 6 ether); // give goal ether to the contributor
        pool.contribute{value: 6 ether}(); // call the contribute function to give goal ether
        // end is 4 weeks, we need to wait 4 weeks to reach the end
        vm.warp(pool.end() + 3600); // set 1 hour after the end time to now
        // check if the contract reverts when the withdraw failed to send ether
        bytes4 selector = bytes4(keccak256("FailtedToSendEther()"));
        vm.expectRevert(abi.encodeWithSelector(selector));
        // no need to prank the owner, the owner is this contract due to the pool instantiation in this test function
        pool.withdraw(); // call the withdraw function
    }

    function test_Withdraw() public {
        // goal is 10 ether, we need to contribute at least 10 ether to reach the goal
        vm.prank(contributor); // set the contributor
        vm.deal(contributor, 6 ether); // give goal ether to the contributor
        pool.contribute{value: 6 ether}(); // call the contribute function to give goal ether

        vm.prank(contributor2); // set the contributor
        vm.deal(contributor2, 6 ether); // give goal ether to the contributor
        pool.contribute{value: 6 ether}(); // call the contribute function to give goal ether
        // end is 4 weeks, we need to wait 4 weeks to reach the end
        vm.warp(pool.end() + 3600); // set 1 hour after the end time to now
        // check if the contract reverts when the withdraw failed to send ether
        vm.prank(owner); // set the owner
        pool.withdraw(); // call the withdraw function
    }

    // Tests refund
    function test_RevertWhen_CollectNotFinished() public {
        // check if the contract reverts when the end is not reached
        // checking if custom error "CollectNotFinished()" is thrown
        vm.prank(contributor); // set the contributor
        vm.deal(contributor, 6 ether); // give goal ether to the contributor
        pool.contribute{value: 6 ether}(); // call the contribute function to give goal ether

        vm.prank(contributor2); // set the contributor
        vm.deal(contributor2, 6 ether); // give goal ether to the contributor
        pool.contribute{value: 6 ether}(); // call the contribute function to give goal ether
        bytes4 selector = bytes4(keccak256("CollectNotFinished()"));
        vm.expectRevert(abi.encodeWithSelector(selector));
        vm.prank(contributor); // set the owner
        pool.refund(); // call the refund function
    }

    function test_RevertWhen_GoalAlreadyReached() public {
        // check if the contract reverts when the goal is reached
        // checking if custom error "GoalAlreadyReached()" is thrown
        vm.prank(contributor); // set the contributor
        vm.deal(contributor, 6 ether); // give goal ether to the contributor
        pool.contribute{value: 6 ether}(); // call the contribute function to give goal ether

        vm.prank(contributor2); // set the contributor
        vm.deal(contributor2, 6 ether); // give goal ether to the contributor
        pool.contribute{value: 6 ether}(); // call the contribute function to give goal ether
        vm.warp(pool.end() + 3600); // set 1 hour after the end time to now
        bytes4 selector = bytes4(keccak256("GoalAlreadyReached()"));
        vm.expectRevert(abi.encodeWithSelector(selector));
        vm.prank(contributor);
        pool.refund(); // call the refund function
    }

    function test_RevertWhen_NoContribution() public {
        // check if the contract reverts when the contributor has no contribution
        // checking if custom error "NoContribution()" is thrown
        vm.prank(contributor); // set the contributor
        vm.deal(contributor, 6 ether); // give goal ether to the contributor
        pool.contribute{value: 6 ether}(); // call the contribute function to give goal ether

        vm.prank(contributor2); // set the contributor
        vm.deal(contributor2, 1 ether); // give goal ether to the contributor
        pool.contribute{value: 1 ether}(); // call the contribute function to give goal ether
        vm.warp(pool.end() + 3600); // set 1 hour after the end time to now
        bytes4 selector = bytes4(keccak256("NoContribution()"));
        vm.expectRevert(abi.encodeWithSelector(selector));
        vm.prank(contributor3);

        pool.refund(); // call the refund function
    }

    function test_RevertWhen_RefundFailedToSendEther() public {
        // check if the contract reverts when the refund failed to send ether
        // to perform this test, we need a contract that CAN'T receive ether (no receive or fallback or payable function)
        // So we use this PoolTest contract itself !
        // So here, this test contract become the owner of the pool contract
        vm.deal(address(this), 2 ether);
        pool.contribute{value: 2 ether}();

        vm.prank(contributor); // set the contributor
        vm.deal(contributor, 6 ether); // give goal ether to the contributor
        pool.contribute{value: 6 ether}(); // call the contribute function to give goal ether
        // end is 4 weeks, we need to wait 4 weeks to reach the end
        vm.warp(pool.end() + 3600); // set 1 hour after the end time to now
        // check if the contract reverts when the withdraw failed to send ether
        bytes4 selector = bytes4(keccak256("FailtedToSendEther()"));
        vm.expectRevert(abi.encodeWithSelector(selector));
        // should revert as this test contract can't receive ether
        pool.refund(); // call the refund function
    }

    function test_Refund() public {
        vm.prank(contributor); // set the contributor
        vm.deal(contributor, 6 ether); // give goal ether to the contributor
        pool.contribute{value: 6 ether}(); // call the contribute function to give goal ether

        vm.prank(contributor2); // set the contributor
        vm.deal(contributor2, 1 ether); // give goal ether to the contributor
        pool.contribute{value: 1 ether}(); // call the contribute function to give goal ether
        // end is 4 weeks, we need to wait 4 weeks to reach the end
        vm.warp(pool.end() + 3600); // set 1 hour after the end time to now
        uint256 balanceBeforeRefund = contributor.balance;
        vm.prank(contributor);
        pool.refund();
        uint256 balanceAfterRefund = contributor.balance;
        assertEq(balanceAfterRefund, balanceBeforeRefund + 6 ether);
    }
}
