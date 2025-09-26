// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PositionManager} from "v4-periphery/src/PositionManager.sol";
import {IAllowanceTransfer} from "permit2/src/interfaces/IAllowanceTransfer.sol";

/// @notice Shared constants for Unichain deployments
contract Constants {
    address constant CREATE2_DEPLOYER = address(0x4e59b44847b379578588920cA78FbF26c0B4956C);

    // Unichain Mainnet Addresses (chainId: 130)
    IPoolManager constant POOLMANAGER = IPoolManager(address(0x1f98400000000000000000000000000000000004));
    PositionManager constant POSM = PositionManager(payable(address(0x4529a01c7a0410167c5740c487a8de60232617bf)));
    IAllowanceTransfer constant PERMIT2 = IAllowanceTransfer(address(0x000000000022D473030F116dDEE9F6B43aC78BA3));

    // Additional Unichain contracts
    address constant UNIVERSAL_ROUTER = address(0xef740bf23acae26f6492b10de645d6b98dc8eaf3);
    address constant QUOTER = address(0x333e3c607b141b18ff6de9f258db6e77fe7491e0);
    address constant STATE_VIEW = address(0x86e8631a016f9068c3f085faf484ee3f5fdee8f2);
}