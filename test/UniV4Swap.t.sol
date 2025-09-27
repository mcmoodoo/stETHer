// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";

// had some troble compiling the universal-router repo so copied the interfaces/libraries needed
import { IUniversalRouter } from "universal-router/contracts/interfaces/IUniversalRouter.sol";
import { Commands } from "universal-router/contracts/libraries/Commands.sol";

import { IPoolManager } from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import { StateLibrary } from "@uniswap/v4-core/src/libraries/StateLibrary.sol";
import { PoolKey } from "@uniswap/v4-core/src/types/PoolKey.sol";
import { Currency } from "@uniswap/v4-core/src/types/Currency.sol";
import { IHooks } from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import { IV4Router } from "@uniswap/v4-periphery/src/interfaces/IV4Router.sol";
import { Actions } from "@uniswap/v4-periphery/src/libraries/Actions.sol";
import { IPermit2 } from "../lib/permit2/src/interfaces/IPermit2.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

abstract contract UniV4Swap is Test {
    using StateLibrary for IPoolManager;

    address constant UNIVERSAL_ROUTER_ADDRESS = 0x66a9893cC07D91D95644AEDD05D03f95e1dBA8Af;
    address constant POOL_MANAGER_ADDRESS = 0x000000000004444c5dc75cB358380D2e3dE08A90;
    address constant PERMIT2_ADDRESS = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

    IUniversalRouter UNIVERSAL_ROUTER = IUniversalRouter(UNIVERSAL_ROUTER_ADDRESS);
    IPoolManager POOL_MANAGER = IPoolManager(POOL_MANAGER_ADDRESS);
    IPermit2 PERMIT2 = IPermit2(PERMIT2_ADDRESS);

    address constant USDC_ADDRESS = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant WBTC_ADDRESS = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    address constant ETH = address(0);

    IERC20 USDC = IERC20(USDC_ADDRESS);
    IERC20 WBTC = IERC20(WBTC_ADDRESS);

    PoolKey WBTC_USDC_KEY = PoolKey({
        currency0: Currency.wrap(WBTC_ADDRESS),
        currency1: Currency.wrap(USDC_ADDRESS),
        fee: 3000,
        tickSpacing: 60,
        hooks: IHooks(address(0))
    });

    PoolKey ETH_USDC_KEY = PoolKey({
        currency0: Currency.wrap(ETH),
        currency1: Currency.wrap(USDC_ADDRESS),
        fee: 3000,
        tickSpacing: 60,
        hooks: IHooks(address(0))
    });

    bytes constant actions = abi.encodePacked(
        uint8(Actions.SWAP_EXACT_IN_SINGLE),
        uint8(Actions.SETTLE_ALL),
        uint8(Actions.TAKE_ALL)
    );

    function setUp() public {
        // Fork at specific block for consistent caching
        // Run with: forge test --match-contract UniV4Swap --offline (after initial cache)
        vm.selectFork(vm.createFork(vm.envString("INFURA_ETHEREUM_MAINNET_RPC"), 23443437));


        vm.label(UNIVERSAL_ROUTER_ADDRESS, "UNIVERSAL_ROUTER");
        vm.label(POOL_MANAGER_ADDRESS, "POOL_MANAGER");
        vm.label(PERMIT2_ADDRESS, "PERMIT2");

        vm.label(USDC_ADDRESS, "USDC");
        vm.label(WBTC_ADDRESS, "WBTC");
    }

    function testSwapWBTCForUSDC() public {
        uint128 amountIn = 1e7;
        uint128 minAmountOut = 0;

        deal(WBTC_ADDRESS, address(this), amountIn);

        WBTC.approve(PERMIT2_ADDRESS, amountIn);
        PERMIT2.approve(WBTC_ADDRESS, UNIVERSAL_ROUTER_ADDRESS, amountIn, uint48(block.timestamp) + 1);

        bytes memory commands = abi.encodePacked(uint8(Commands.V4_SWAP));
        bytes[] memory inputs = new bytes[](1);
        bytes[] memory params = new bytes[](3);

        params[0] = abi.encode(
            IV4Router.ExactInputSingleParams({
                poolKey: WBTC_USDC_KEY,
                zeroForOne: true,
                amountIn: amountIn,
                amountOutMinimum: minAmountOut,
                hookData: bytes("")
            })
        );
        params[1] = abi.encode(WBTC_USDC_KEY.currency0, amountIn);
        params[2] = abi.encode(WBTC_USDC_KEY.currency1, minAmountOut);

        inputs[0] = abi.encode(actions, params);

        UNIVERSAL_ROUTER.execute(commands, inputs, block.timestamp);

        assertGt(USDC.balanceOf(address(this)), minAmountOut);
    }

    function testSwapETHForUSD() public {
        uint128 amountIn = 1e18;
        uint128 minAmountOut = 0;

        vm.deal(address(this), amountIn);

        bytes memory commands = abi.encodePacked(uint8(Commands.V4_SWAP));
        bytes[] memory inputs = new bytes[](1);
        bytes[] memory params = new bytes[](3);

        params[0] = abi.encode(
            IV4Router.ExactInputSingleParams({
                poolKey: ETH_USDC_KEY,
                zeroForOne: true,
                amountIn: amountIn,
                amountOutMinimum: minAmountOut,
                hookData: bytes("")
            })
        );
        params[1] = abi.encode(ETH_USDC_KEY.currency0, amountIn);
        params[2] = abi.encode(ETH_USDC_KEY.currency1, minAmountOut);

        inputs[0] = abi.encode(actions, params);

        UNIVERSAL_ROUTER.execute{value: amountIn}(commands, inputs, block.timestamp);

        assertGt(USDC.balanceOf(address(this)), minAmountOut);
    }

    function testSwapUSDCForETH() public {
        uint128 amountIn = 1000e6;
        uint128 minAmountOut = 0;

        deal(USDC_ADDRESS, address(this), amountIn);

        USDC.approve(PERMIT2_ADDRESS, amountIn);
        PERMIT2.approve(USDC_ADDRESS, UNIVERSAL_ROUTER_ADDRESS, amountIn, uint48(block.timestamp) + 1);

        bytes memory commands = abi.encodePacked(uint8(Commands.V4_SWAP));
        bytes[] memory inputs = new bytes[](1);
        bytes[] memory params = new bytes[](3);

        params[0] = abi.encode(
            IV4Router.ExactInputSingleParams({
                poolKey: ETH_USDC_KEY,
                zeroForOne: false,
                amountIn: amountIn,
                amountOutMinimum: minAmountOut,
                hookData: bytes("")
            })
        );
        params[1] = abi.encode(ETH_USDC_KEY.currency1, amountIn);
        params[2] = abi.encode(ETH_USDC_KEY.currency0, minAmountOut);

        inputs[0] = abi.encode(actions, params);

        UNIVERSAL_ROUTER.execute(commands, inputs, block.timestamp);

        assertGt(address(this).balance, minAmountOut);
    }

    receive() external payable {}

}
