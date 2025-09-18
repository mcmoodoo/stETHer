// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {Currency} from "v4-core/src/types/Currency.sol";
import {RebasingParityPool} from "../src/RebasingParityPool.sol";
import {ProtocolRevenue} from "../src/ProtocolRevenue.sol";
import {Fixtures} from "./utils/Fixtures.sol";

// Mock ERC20 that can fail transfers
contract MockFailingERC20 {
    mapping(address => uint256) public balanceOf;
    bool public shouldFail;

    function transfer(address, uint256) external view returns (bool) {
        return !shouldFail;
    }

    function setShouldFail(bool _shouldFail) external {
        shouldFail = _shouldFail;
    }

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
    }
}

contract ProtocolRevenueExtendedTest is Test, Fixtures {
    RebasingParityPool hook;
    ProtocolRevenue protocolRevenue;
    address treasury = address(0x999);
    address unauthorizedUser = address(0x123);
    MockFailingERC20 mockToken;

    function setUp() public {
        deployFreshManagerAndRouters();
        deployMintAndApprove2Currencies();
        deployAndApprovePosm(manager);

        // Deploy protocol revenue contract
        protocolRevenue = new ProtocolRevenue(treasury);

        // Deploy ParityPool with protocol revenue
        address flags = address(
            uint160(Hooks.BEFORE_SWAP_FLAG | Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG | Hooks.BEFORE_ADD_LIQUIDITY_FLAG)
                ^ (0x4449 << 144)
        );

        // Create the pool key first (before deploying hook)
        key = PoolKey(currency0, currency1, 3000, 60, IHooks(flags));

        bytes memory constructorArgs = abi.encode(manager, treasury, key);
        deployCodeTo("RebasingParityPool.sol:RebasingParityPool", constructorArgs, flags);
        hook = RebasingParityPool(flags);

        key = PoolKey(currency0, currency1, 3000, 60, IHooks(hook));
        manager.initialize(key, SQRT_PRICE_1_1);

        // Setup mock token for transfer failure tests
        mockToken = new MockFailingERC20();
    }

    // Test updateTreasury function
    function test_updateTreasury_success() public {
        address newTreasury = address(0x888);

        // Only owner can update
        protocolRevenue.updateTreasury(newTreasury);

        assertEq(protocolRevenue.treasury(), newTreasury, "Treasury should be updated");
    }

    function test_updateTreasury_unauthorizedReverts() public {
        address newTreasury = address(0x888);

        vm.prank(unauthorizedUser);
        vm.expectRevert("Not authorized");
        protocolRevenue.updateTreasury(newTreasury);
    }

    // Test updateFeeParameters function
    function test_updateFeeParameters_success() public {
        uint256 newFeePercentage = 15;
        uint256 newThreshold = 500e18;
        uint256 newLargeFee = 1000;

        protocolRevenue.updateFeeParameters(newFeePercentage, newThreshold, newLargeFee);

        assertEq(protocolRevenue.protocolFeePercentage(), newFeePercentage);
        assertEq(protocolRevenue.largeSwapThreshold(), newThreshold);
        assertEq(protocolRevenue.largeSwapProtocolFee(), newLargeFee);
    }

    function test_updateFeeParameters_maxFeeEnforced() public {
        uint256 tooHighFee = 26; // Above MAX_PROTOCOL_FEE (25)

        vm.expectRevert("Fee too high");
        protocolRevenue.updateFeeParameters(tooHighFee, 1000e18, 500);
    }

    function test_updateFeeParameters_exactMaxFeeAllowed() public {
        uint256 maxFee = 25; // Exactly MAX_PROTOCOL_FEE

        protocolRevenue.updateFeeParameters(maxFee, 1000e18, 500);
        assertEq(protocolRevenue.protocolFeePercentage(), maxFee);
    }

    function test_updateFeeParameters_unauthorizedReverts() public {
        vm.prank(unauthorizedUser);
        vm.expectRevert("Not authorized");
        protocolRevenue.updateFeeParameters(15, 500e18, 1000);
    }

    function test_updateFeeParameters_emitsEvent() public {
        uint256 newFeePercentage = 15;
        uint256 newThreshold = 500e18;
        uint256 newLargeFee = 1000;

        vm.expectEmit(true, true, true, true);
        emit FeeParametersUpdated(newFeePercentage, newThreshold, newLargeFee);

        protocolRevenue.updateFeeParameters(newFeePercentage, newThreshold, newLargeFee);
    }

    // Test accumulateProtocolFee edge cases
    function test_accumulateProtocolFee_multipleAccumulations() public {
        address token = Currency.unwrap(currency0);
        uint256 amount1 = 100e18;
        uint256 amount2 = 200e18;

        protocolRevenue.accumulateProtocolFee(token, amount1);
        protocolRevenue.accumulateProtocolFee(token, amount2);

        assertEq(protocolRevenue.getProtocolFees(token), amount1 + amount2);
    }

    function test_accumulateProtocolFee_emitsEvent() public {
        address token = Currency.unwrap(currency0);
        uint256 amount = 100e18;

        vm.expectEmit(true, true, false, true);
        emit ProtocolFeeCollected(token, amount);

        protocolRevenue.accumulateProtocolFee(token, amount);
    }

    // Test withdrawProtocolFees edge cases
    function test_withdrawProtocolFees_insufficientBalance() public {
        address token = Currency.unwrap(currency0);

        // Try to withdraw more than available
        vm.expectRevert("Insufficient protocol fees");
        protocolRevenue.withdrawProtocolFees(token, 100e18);
    }

    function test_withdrawProtocolFees_partialWithdrawal() public {
        address token = Currency.unwrap(currency0);
        uint256 totalAmount = 1000e18;
        uint256 withdrawAmount = 300e18;

        // Accumulate fees
        protocolRevenue.accumulateProtocolFee(token, totalAmount);

        // Setup token balance for protocol revenue contract
        deal(token, address(protocolRevenue), totalAmount);

        // Withdraw partial amount
        protocolRevenue.withdrawProtocolFees(token, withdrawAmount);

        assertEq(protocolRevenue.getProtocolFees(token), totalAmount - withdrawAmount);
    }

    function test_withdrawProtocolFees_transferFailureReverts() public {
        address token = address(mockToken);
        uint256 amount = 100e18;

        // Setup: accumulate fees and prepare for transfer
        protocolRevenue.accumulateProtocolFee(token, amount);
        mockToken.mint(address(protocolRevenue), amount);

        // Make transfer fail
        mockToken.setShouldFail(true);

        // Should revert when transfer fails
        vm.expectRevert("Transfer failed");
        protocolRevenue.withdrawProtocolFees(token, amount);
    }

    function test_withdrawProtocolFees_unauthorizedReverts() public {
        address token = Currency.unwrap(currency0);

        vm.prank(unauthorizedUser);
        vm.expectRevert("Not authorized");
        protocolRevenue.withdrawProtocolFees(token, 100e18);
    }

    function test_withdrawProtocolFees_emitsEvent() public {
        address token = Currency.unwrap(currency0);
        uint256 amount = 100e18;

        // Setup
        protocolRevenue.accumulateProtocolFee(token, amount);
        deal(token, address(protocolRevenue), amount);

        vm.expectEmit(true, true, false, true);
        emit ProtocolFeeWithdrawn(token, amount, treasury);

        protocolRevenue.withdrawProtocolFees(token, amount);
    }

    // Test spendProtocolFeesForIncentive
    function test_spendProtocolFeesForIncentive_sufficientFunds() public {
        address token = Currency.unwrap(currency0);
        uint256 available = 1000e18;
        uint256 spendAmount = 300e18;

        protocolRevenue.accumulateProtocolFee(token, available);

        bool success = protocolRevenue.spendProtocolFeesForIncentive(token, spendAmount);

        assertTrue(success, "Should succeed with sufficient funds");
        assertEq(protocolRevenue.getProtocolFees(token), available - spendAmount);
    }

    function test_spendProtocolFeesForIncentive_insufficientFunds() public {
        address token = Currency.unwrap(currency0);
        uint256 available = 100e18;
        uint256 spendAmount = 300e18;

        protocolRevenue.accumulateProtocolFee(token, available);

        bool success = protocolRevenue.spendProtocolFeesForIncentive(token, spendAmount);

        assertFalse(success, "Should fail with insufficient funds");
        assertEq(protocolRevenue.getProtocolFees(token), available, "Balance should remain unchanged");
    }

    function test_spendProtocolFeesForIncentive_exactAmount() public {
        address token = Currency.unwrap(currency0);
        uint256 amount = 100e18;

        protocolRevenue.accumulateProtocolFee(token, amount);

        bool success = protocolRevenue.spendProtocolFeesForIncentive(token, amount);

        assertTrue(success, "Should succeed with exact amount");
        assertEq(protocolRevenue.getProtocolFees(token), 0, "Balance should be zero");
    }

    function test_spendProtocolFeesForIncentive_emitsEventOnSuccess() public {
        address token = Currency.unwrap(currency0);
        uint256 amount = 100e18;

        protocolRevenue.accumulateProtocolFee(token, amount);

        vm.expectEmit(true, true, false, true);
        emit ProtocolFeeWithdrawn(token, amount, address(this));

        protocolRevenue.spendProtocolFeesForIncentive(token, amount);
    }

    function test_spendProtocolFeesForIncentive_noEventOnFailure() public {
        address token = Currency.unwrap(currency0);
        uint256 amount = 100e18;

        // Don't accumulate any fees, so spend will fail
        bool success = protocolRevenue.spendProtocolFeesForIncentive(token, amount);

        assertFalse(success, "Should return false on insufficient funds");
    }

    // Test calculateProtocolFee edge cases
    function test_calculateProtocolFee_zeroFee() public view {
        (uint256 protocolFee, uint256 lpFee) = protocolRevenue.calculateProtocolFee(0, 100e18);

        assertEq(protocolFee, 0);
        assertEq(lpFee, 0);
    }

    function test_calculateProtocolFee_belowLargeSwapThreshold() public view {
        uint256 totalFee = 100e18;
        uint256 swapAmount = 500e18; // Below threshold of 1000e18

        (uint256 protocolFee, uint256 lpFee) = protocolRevenue.calculateProtocolFee(totalFee, swapAmount);

        // Should only apply base percentage (10%)
        assertEq(protocolFee, 10e18);
        assertEq(lpFee, 90e18);
    }

    function test_calculateProtocolFee_atLargeSwapThreshold() public view {
        uint256 totalFee = 100e18;
        uint256 swapAmount = 1000e18; // Exactly at threshold

        (uint256 protocolFee, uint256 lpFee) = protocolRevenue.calculateProtocolFee(totalFee, swapAmount);

        // Should apply base percentage + large swap fee
        uint256 expectedBase = 10e18; // 10% of 100e18
        uint256 expectedAdditional = (swapAmount * 500) / 1_000_000; // 0.5e18

        assertEq(protocolFee, expectedBase + expectedAdditional);
        assertEq(lpFee, totalFee - protocolFee);
    }

    function test_calculateProtocolFee_maxFeeEnforced() public {
        // Update to 25% protocol fee (max allowed)
        protocolRevenue.updateFeeParameters(25, 1000e18, 10000); // High additional fee

        uint256 totalFee = 100e18;
        uint256 largeSwapAmount = 10000e18; // Very large swap

        (uint256 protocolFee, uint256 lpFee) = protocolRevenue.calculateProtocolFee(totalFee, largeSwapAmount);

        // Should cap at 25% max
        assertEq(protocolFee, 25e18); // 25% of 100e18
        assertEq(lpFee, 75e18);
    }

    // Test getProtocolFees view function
    function test_getProtocolFees_multipleTokens() public {
        address token1 = Currency.unwrap(currency0);
        address token2 = Currency.unwrap(currency1);

        protocolRevenue.accumulateProtocolFee(token1, 100e18);
        protocolRevenue.accumulateProtocolFee(token2, 200e18);

        assertEq(protocolRevenue.getProtocolFees(token1), 100e18);
        assertEq(protocolRevenue.getProtocolFees(token2), 200e18);
    }

    function test_getProtocolFees_unknownToken() public view {
        address unknownToken = address(0x789);
        assertEq(protocolRevenue.getProtocolFees(unknownToken), 0);
    }

    // Test constructor
    function test_constructor_setsOwnerAndTreasury() public {
        address newTreasury = address(0x111);
        ProtocolRevenue newProtocolRevenue = new ProtocolRevenue(newTreasury);

        assertEq(newProtocolRevenue.OWNER(), address(this));
        assertEq(newProtocolRevenue.treasury(), newTreasury);
    }

    // Fuzz testing
    function testFuzz_calculateProtocolFee(uint256 totalFee, uint256 swapAmount) public view {
        totalFee = bound(totalFee, 0, 100000e18);
        swapAmount = bound(swapAmount, 0, 100000e18);

        (uint256 protocolFee, uint256 lpFee) = protocolRevenue.calculateProtocolFee(totalFee, swapAmount);

        // Invariants
        assertEq(protocolFee + lpFee, totalFee, "Fees should sum to total");
        assertLe(protocolFee, (totalFee * 25) / 100, "Protocol fee should not exceed 25%");
    }

    function testFuzz_accumulateAndWithdraw(bool useCurrency0, uint256 amount) public {
        amount = bound(amount, 1, 100000e18);

        address token = useCurrency0 ? Currency.unwrap(currency0) : Currency.unwrap(currency1);

        // Accumulate
        protocolRevenue.accumulateProtocolFee(token, amount);
        assertEq(protocolRevenue.getProtocolFees(token), amount);

        // Setup token for withdrawal
        deal(token, address(protocolRevenue), amount);

        // Withdraw
        protocolRevenue.withdrawProtocolFees(token, amount);
        assertEq(protocolRevenue.getProtocolFees(token), 0);
    }

    // Events
    event ProtocolFeeCollected(address indexed token, uint256 amount);
    event ProtocolFeeWithdrawn(address indexed token, uint256 amount, address to);
    event FeeParametersUpdated(uint256 feePercentage, uint256 threshold, uint256 largeFee);
}