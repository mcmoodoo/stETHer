// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {Currency} from "v4-core/src/types/Currency.sol";

/// @notice Shared configuration between scripts
contract Config {
    /// @dev ETH is represented as address(0) for native token
    /// @dev stETH will be deployed and its address will be set during script execution
    IERC20 constant TOKEN0 = IERC20(address(0)); // ETH (native token)
    IERC20 constant TOKEN1 = IERC20(address(0xa513E6E4b8f2a923D98304ec87F64353C4D5C853)); // stETH (to be deployed)
    IHooks constant HOOK_CONTRACT = IHooks(address(0x0));

    Currency constant CURRENCY0 = Currency.wrap(address(TOKEN0)); // ETH
    Currency constant CURRENCY1 = Currency.wrap(address(TOKEN1)); // stETH
}
