// SPDX-License-Identifier: MIT
/*
██████╗ ██╗     ██╗   ██╗███████╗██████╗ ███████╗██████╗ ██████╗ ██╗   ██╗
██╔══██╗██║     ██║   ██║██╔════╝██╔══██╗██╔════╝██╔══██╗██╔══██╗╚██╗ ██╔╝
██████╔╝██║     ██║   ██║█████╗  ██████╔╝█████╗  ██████╔╝██████╔╝ ╚████╔╝
██╔══██╗██║     ██║   ██║██╔══╝  ██╔══██╗██╔══╝  ██╔══██╗██╔══██╗  ╚██╔╝
██████╔╝███████╗╚██████╔╝███████╗██████╔╝███████╗██║  ██║██║  ██║   ██║
╚═════╝ ╚══════╝ ╚═════╝ ╚══════╝╚═════╝ ╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝   ╚═╝
*/
pragma solidity 0.8.22;

import { Ownable2StepUpgradeable } from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";

import "../utils/BlueberryErrors.sol" as Errors;
import { IBalancerVault, IAsset } from "../interfaces/balancer-v2/IBalancerVault.sol";
import { ICurvePool } from "../interfaces/curve/ICurvePool.sol";

import { ISwapRegistry } from "../interfaces/ISwapRegistry.sol";
import { ISwapRouter } from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

abstract contract SwapRegistry is ISwapRegistry, Ownable2StepUpgradeable {
    /// @notice The address of the WETH token
    address internal _weth;

    /// @dev The Balancer Vault address
    IBalancerVault internal _balancerVault;

    /// @dev The address of the swap router
    ISwapRouter internal _swapRouter;

    /// @notice Mapping of a token to the DEX to use for liquidation swaps
    mapping(address => DexRoute) internal _tokenToExchange;

    /// @notice Mapping of a token pair to the poolId to use for liquidation swaps
    mapping(address => mapping(address => bytes32)) internal _balancerRoutes;

    /// @notice Mapping of a token pair to curve pool to use for liquidation swaps
    mapping(address => mapping(address => address)) internal _curveRoutes;

    mapping(address => bool) internal _isProtocolToken;

    /// @inheritdoc ISwapRegistry
    function registerBalancerRoute(address srcToken, address dstToken, bytes32 poolId) external onlyOwner {
        if (srcToken == address(0) || dstToken == address(0)) {
            revert Errors.ZERO_ADDRESS();
        }

        if (poolId == bytes32(0)) {
            revert Errors.ZERO_AMOUNT();
        }

        _tokenToExchange[srcToken] = DexRoute.Balancer;
        _balancerRoutes[srcToken][dstToken] = poolId;
    }

    /// @inheritdoc ISwapRegistry
    function registerCurveRoute(address srcToken, address dstToken, address pool) external onlyOwner {
        if (srcToken == address(0) || dstToken == address(0) || pool == address(0)) {
            revert Errors.ZERO_ADDRESS();
        }

        _tokenToExchange[srcToken] = DexRoute.Curve;
        _curveRoutes[srcToken][dstToken] = pool;
    }

    /// @inheritdoc ISwapRegistry
    function registerUniswapRoute(address srcToken) external onlyOwner {
        if (srcToken == address(0)) {
            revert Errors.ZERO_ADDRESS();
        }

        _tokenToExchange[srcToken] = DexRoute.UniswapV3;
    }

    /// @inheritdoc ISwapRegistry
    function setProtocolToken(address token, bool isProtocolToken) external onlyOwner {
        _isProtocolToken[token] = isProtocolToken;
    }

    function _swapOnBalancer(
        address srcToken,
        address dstToken,
        uint256 amount
    ) internal returns (address tokenReceived, uint256 amountReceived) {
        if (IERC20(srcToken).balanceOf(address(this)) >= amount) {
            if (_isProtocolToken[srcToken]) {
                dstToken == address(_weth);
            }

            IERC20(srcToken).approve(address(_balancerVault), amount);

            bytes32 poolId = _balancerRoutes[srcToken][dstToken];

            if (poolId == bytes32(0)) {
                revert Errors.ZERO_AMOUNT();
            }

            IBalancerVault.SingleSwap memory singleSwap;
            singleSwap.poolId = poolId;
            singleSwap.kind = IBalancerVault.SwapKind.GIVEN_IN;
            singleSwap.assetIn = IAsset(srcToken);
            singleSwap.assetOut = IAsset(dstToken);
            singleSwap.amount = amount;

            IBalancerVault.FundManagement memory funds;
            funds.sender = address(this);
            funds.recipient = payable(address(this));

            amountReceived = _balancerVault.swap(singleSwap, funds, 0, block.timestamp);
        }
        return (dstToken, amountReceived);
    }

    function _swapOnCurve(
        address srcToken,
        address dstToken,
        uint256 amount
    ) internal returns (address tokenReceived, uint256 amountReceived) {
        if (IERC20(srcToken).balanceOf(address(this)) >= amount) {
            if (_isProtocolToken[srcToken]) {
                dstToken == address(_weth);
            }

            ICurvePool pool = ICurvePool(_curveRoutes[srcToken][dstToken]);
            IERC20(srcToken).approve(address(pool), amount);

            uint256 srcIndex;
            uint256 dstIndex;
            for (uint256 i = 0; i < 4; i++) {
                try pool.coins(i) returns (address coin) {
                    if (coin == srcToken) {
                        srcIndex = i;
                    } else if (coin == dstToken) {
                        dstIndex = i;
                    }
                } catch {}

                if (srcIndex != 0 && dstIndex != 0) {
                    break;
                }
            }

            amountReceived = pool.exchange(srcIndex, dstIndex, amount, 0, false, address(this));

            return (dstToken, amountReceived);
        }
    }

    function _swapOnUniswap(
        address srcToken,
        address dstToken,
        uint256 amount
    ) internal returns (address tokenReceived, uint256 amountReceived) {
        if (IERC20(srcToken).balanceOf(address(this)) >= amount) {
            IERC20(srcToken).approve(address(_swapRouter), amount);

            amountReceived = _swapRouter.exactInputSingle(
                ISwapRouter.ExactInputSingleParams({
                    tokenIn: srcToken,
                    tokenOut: dstToken,
                    fee: 3000,
                    recipient: address(this),
                    deadline: block.timestamp,
                    amountIn: amount,
                    amountOutMinimum: 0,
                    sqrtPriceLimitX96: 0
                })
            );
        }

        return (dstToken, amountReceived);
    }
}
