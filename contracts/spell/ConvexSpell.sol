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

import { SafeERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import { IERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

import { PSwapLib } from "../libraries/Paraswap/PSwapLib.sol";
import { UniversalERC20, IERC20 } from "../libraries/UniversalERC20.sol";

import "../utils/BlueberryErrors.sol" as Errors;

import { BasicSpell } from "./BasicSpell.sol";

import { IBank } from "../interfaces/IBank.sol";
import { ICurveOracle } from "../interfaces/ICurveOracle.sol";
import { ICurveZapDepositor } from "../interfaces/ICurveZapDepositor.sol";
import { ICurvePool } from "../interfaces/curve/ICurvePool.sol";
import { IWConvexPools } from "../interfaces/IWConvexPools.sol";
import { IWETH } from "../interfaces/IWETH.sol";

/// @title ConvexSpell
/// @author BlueberryProtocol
/// @notice This contract serves as the factory for defining how the Blueberry Protocol
///         interacts with Convex pools. It handles strategies, interactions with external contracts,
///         and facilitates operations related to liquidity provision.
contract ConvexSpell is BasicSpell {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using UniversalERC20 for IERC20;

    struct ClosePositionFarmParam {
        ClosePosParam param;
        uint256[] amounts;
        bytes[] swapDatas;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                   PUBLIC STORAGE
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Address of the Wrapped Convex Pools
    IWConvexPools public wConvexPools;
    /// @dev address of CurveOracle to retrieve pool information
    ICurveOracle public crvOracle;
    /// @dev address of CVX token
    address public cvxToken;

    /// @dev Curve Zap Depositor for USD metapools
    address public constant CURVE_ZAP_DEPOSITOR = 0xA79828DF1850E8a3A3064576f380D90aECDD3359;
    /// @dev THREE_CRV token address
    address public constant THREE_CRV = 0x6c3F90f043a72FA612cbac8115EE7e52BDe6E490;
    /// @dev DAI token address
    address public constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    /// @dev USDC token address
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    /// @dev USDT token address
    address public constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;

    /*//////////////////////////////////////////////////////////////////////////
                                      FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Initializes the ConvexSpell contract with required parameters.
    /// @param bank_ Address of the bank contract.
    /// @param werc20_ Address of the wrapped ERC20 contract.
    /// @param weth_ Address of the wrapped Ethereum contract.
    /// @param wConvexPools_ Address of the wrapped Convex pools contract.
    /// @param crvOracle_ Address of the Curve Oracle contract.
    /// @param augustusSwapper_ Address of the paraswap AugustusSwapper.
    /// @param tokenTransferProxy_ Address of the paraswap TokenTransferProxy.
    function initialize(
        IBank bank_,
        address werc20_,
        address weth_,
        address wConvexPools_,
        address crvOracle_,
        address augustusSwapper_,
        address tokenTransferProxy_
    ) external initializer {
        __BasicSpell_init(bank_, werc20_, weth_, augustusSwapper_, tokenTransferProxy_);
        if (wConvexPools_ == address(0) || crvOracle_ == address(0)) {
            revert Errors.ZERO_ADDRESS();
        }

        wConvexPools = IWConvexPools(wConvexPools_);
        cvxToken = address(wConvexPools.cvxToken());
        crvOracle = ICurveOracle(crvOracle_);
        IWConvexPools(wConvexPools_).setApprovalForAll(address(bank_), true);
    }

    /// @notice Adds a new strategy to the spell.
    /// @param crvLp Address of the Curve LP token for the strategy.
    /// @param minPosSize Minimum position size in USD for the strategy (with 1e18 precision).
    /// @param maxPosSize Maximum position size in USD for the strategy (with 1e18 precision).
    function addStrategy(address crvLp, uint256 minPosSize, uint256 maxPosSize) external onlyOwner {
        _addStrategy(crvLp, minPosSize, maxPosSize);
    }

    /// @notice Adds liquidity to a Curve pool with two underlying tokens and stakes in Curve gauge.
    /// @param param Struct containing all required parameters for opening a position.
    /// @param minLPMint Minimum LP tokens expected to mint for slippage control.
    function openPositionFarm(
        OpenPosParam calldata param,
        uint256 minLPMint
    ) external existingStrategy(param.strategyId) existingCollateral(param.strategyId, param.collToken) {
        uint256 _minLPMint = minLPMint;
        Strategy memory strategy = strategies[param.strategyId];
        (address lpToken, , , , , ) = wConvexPools.getPoolInfoFromPoolId(param.farmingPoolId);
        if (strategy.vault != lpToken) revert Errors.INCORRECT_LP(lpToken);

        /// 1. Deposit isolated collaterals on Blueberry Money Market
        _doLend(param.collToken, param.collAmount);

        /// 2. Borrow specific amounts
        uint256 borrowBalance = _doBorrow(param.borrowToken, param.borrowAmount);

        (address pool, address[] memory tokens, ) = crvOracle.getPoolInfo(lpToken);

        /// 3. Add liquidity on curve, get crvLp
        {
            address borrowToken = param.borrowToken;
            IERC20(borrowToken).universalApprove(pool, borrowBalance);
            uint256 ethValue;
            uint256 tokenBalance = IERC20(borrowToken).balanceOf(address(this));

            if (borrowBalance > tokenBalance) {
                revert Errors.INSUFFICIENT_COLLATERAL();
            }

            bool isBorrowTokenWeth = borrowToken == weth;
            if (isBorrowTokenWeth) {
                bool hasEth;
                uint256 tokenLength = tokens.length;
                for (uint256 i; i < tokenLength; ++i) {
                    if (tokens[i] == ETH) {
                        hasEth = true;
                        break;
                    }
                }

                if (hasEth) {
                    IWETH(borrowToken).withdraw(tokenBalance);
                    ethValue = tokenBalance;
                }
            }

            if (tokens.length == 2) {
                if (tokens[1] == THREE_CRV) {
                    uint256[4] memory suppliedAmts;

                    if (tokens[0] == borrowToken) {
                        suppliedAmts[0] = tokenBalance;
                    } else if (DAI == borrowToken) {
                        suppliedAmts[1] = tokenBalance;
                    } else if (USDC == borrowToken) {
                        suppliedAmts[2] = tokenBalance;
                    } else {
                        suppliedAmts[3] = tokenBalance;
                    }

                    IERC20(borrowToken).universalApprove(pool, 0);
                    IERC20(borrowToken).universalApprove(CURVE_ZAP_DEPOSITOR, borrowBalance);

                    ICurveZapDepositor(CURVE_ZAP_DEPOSITOR).add_liquidity(pool, suppliedAmts, _minLPMint);
                } else {
                    uint256[2] memory suppliedAmts;

                    for (uint256 i; i < 2; ++i) {
                        if ((tokens[i] == borrowToken) || (tokens[i] == ETH && isBorrowTokenWeth)) {
                            suppliedAmts[i] = tokenBalance;
                            break;
                        }
                    }
                    ICurvePool(pool).add_liquidity{ value: ethValue }(suppliedAmts, _minLPMint);
                }
            } else if (tokens.length == 3) {
                uint256[3] memory suppliedAmts;

                for (uint256 i; i < 3; ++i) {
                    if ((tokens[i] == borrowToken) || (tokens[i] == ETH && isBorrowTokenWeth)) {
                        suppliedAmts[i] = tokenBalance;
                        break;
                    }
                }

                ICurvePool(pool).add_liquidity{ value: ethValue }(suppliedAmts, _minLPMint);
            } else if (tokens.length == 4) {
                uint256[4] memory suppliedAmts;

                for (uint256 i; i < 4; ++i) {
                    if ((tokens[i] == borrowToken) || (tokens[i] == ETH && isBorrowTokenWeth)) {
                        suppliedAmts[i] = tokenBalance;
                        break;
                    }
                }

                ICurvePool(pool).add_liquidity{ value: ethValue }(suppliedAmts, _minLPMint);
            }
        }

        /// 4. Validate MAX LTV
        _validateMaxLTV(param.strategyId);

        /// 5. Validate Max Pos Size
        _validatePosSize(param.strategyId);
        /// 6. Take out existing collateral and burn
        IBank.Position memory pos = bank.getCurrentPositionInfo();
        if (pos.collateralSize > 0) {
            (uint256 pid, ) = wConvexPools.decodeId(pos.collId);

            if (param.farmingPoolId != pid) {
                revert Errors.INCORRECT_PID(param.farmingPoolId);
            }

            if (pos.collToken != address(wConvexPools)) {
                revert Errors.INCORRECT_COLTOKEN(pos.collToken);
            }

            bank.takeCollateral(pos.collateralSize);

            (address[] memory rewardTokens, ) = wConvexPools.burn(pos.collId, pos.collateralSize);
            // distribute multiple rewards to users
            uint256 tokensLength = rewardTokens.length;

            for (uint256 i; i < tokensLength; ++i) {
                _doRefundRewards(rewardTokens[i]);
            }
        }

        /// 7. Deposit on Convex Pool, Put wrapped collateral tokens on Blueberry Bank
        uint256 lpAmount = IERC20(lpToken).balanceOf(address(this));
        IERC20(lpToken).universalApprove(address(wConvexPools), lpAmount);

        uint256 id = wConvexPools.mint(param.farmingPoolId, lpAmount);
        bank.putCollateral(address(wConvexPools), id, lpAmount);
    }

    /// @notice Closes an existing liquidity position, unstakes from Curve gauge, and swaps rewards.
    /// @param closePosParam Struct containing all required parameters for closing a position.
    function closePositionFarm(
        ClosePositionFarmParam calldata closePosParam
    )
        external
        existingStrategy(closePosParam.param.strategyId)
        existingCollateral(closePosParam.param.strategyId, closePosParam.param.collToken)
    {
        address crvLp = strategies[closePosParam.param.strategyId].vault;
        IBank.Position memory pos = bank.getCurrentPositionInfo();

        if (pos.collToken != address(wConvexPools)) {
            revert Errors.INCORRECT_COLTOKEN(pos.collToken);
        }

        if (wConvexPools.getUnderlyingToken(pos.collId) != crvLp) {
            revert Errors.INCORRECT_UNDERLYING(crvLp);
        }

        uint256 amountPosRemove = closePosParam.param.amountPosRemove;

        /// 1. Take out collateral - Burn wrapped tokens, receive crv lp tokens and harvest CRV
        bank.takeCollateral(amountPosRemove);
        (address[] memory rewardTokens, ) = wConvexPools.burn(pos.collId, amountPosRemove);

        /// 2. Swap rewards tokens to debt token
        _sellRewards(rewardTokens, closePosParam);

        /// 3. Remove liquidity
        _removeLiquidity(closePosParam.param, pos, crvLp, amountPosRemove);

        /// 4. Withdraw isolated collateral from Bank
        _doWithdraw(closePosParam.param.collToken, closePosParam.param.amountShareWithdraw);

        /// 5. Swap some collateral to repay debt(for negative PnL)
        _swapCollToDebt(closePosParam.param.collToken, closePosParam.param.amountToSwap, closePosParam.param.swapData);

        /// 6. Repay
        {
            /// Compute repay amount if MAX_INT is supplied (max debt)
            uint256 amountRepay = closePosParam.param.amountRepay;
            if (amountRepay == type(uint256).max) {
                amountRepay = bank.currentPositionDebt(bank.POSITION_ID());
            }
            _doRepay(closePosParam.param.borrowToken, amountRepay);
        }

        _validateMaxLTV(closePosParam.param.strategyId);

        /// 7. Refund
        _doRefund(closePosParam.param.borrowToken);
        _doRefund(closePosParam.param.collToken);
        _doRefund(cvxToken);
    }

    /// @dev Removes liquidity from a Curve pool for a given position.
    /// @param param Contains data required to close the position.
    /// @param pos Data structure representing the current bank position.
    /// @param crvLp Address of the Curve LP token.
    /// @param amountPosRemove Amount of LP tokens to be removed from the pool.
    ///        If set to max, will remove all available LP tokens.
    function _removeLiquidity(
        ClosePosParam memory param,
        IBank.Position memory pos,
        address crvLp,
        uint256 amountPosRemove
    ) internal returns (address[] memory tokens) {
        address pool;
        (pool, tokens, ) = crvOracle.getPoolInfo(crvLp);

        if (amountPosRemove == type(uint256).max) {
            amountPosRemove = IERC20(crvLp).balanceOf(address(this));
        }

        int128 tokenIndex;
        uint256 len = tokens.length;
        for (uint256 i; i < len; ++i) {
            if (tokens[i] == pos.debtToken) {
                tokenIndex = int128(uint128(i));
                break;
            }
        }

        if (len == 2 && tokens[1] == THREE_CRV) {
            int128 index;
            if (tokens[0] == param.borrowToken) {
                index = 0;
            } else if (DAI == param.borrowToken) {
                index = 1;
            } else if (USDC == param.borrowToken) {
                index = 2;
            } else {
                index = 3;
            }
            IERC20(pool).universalApprove(CURVE_ZAP_DEPOSITOR, amountPosRemove);
            ICurveZapDepositor(CURVE_ZAP_DEPOSITOR).remove_liquidity_one_coin(
                pool,
                amountPosRemove,
                index,
                param.amountOutMin
            );
            return _getMetaPoolTokens(tokens[0]);
        } else {
            /// Removes liquidity from the Curve pool for the specified token.
            ICurvePool(pool).remove_liquidity_one_coin(amountPosRemove, tokenIndex, param.amountOutMin);
        }

        if (tokens[uint128(tokenIndex)] == ETH) {
            IWETH(weth).deposit{ value: address(this).balance }();
        }
    }

    function _getMetaPoolTokens(address token) internal pure returns (address[] memory tokens) {
        tokens = new address[](4);
        tokens[0] = token;
        tokens[1] = DAI;
        tokens[2] = USDC;
        tokens[3] = USDT;
    }

    /// @dev Internal function Sells the accumulated reward tokens.
    /// @param rewardTokens An array of addresses of the reward tokens to be sold.
    /// @param closePosParam Struct containing all required parameters for closing a position.
    function _sellRewards(address[] memory rewardTokens, ClosePositionFarmParam calldata closePosParam) internal {
        uint256 tokensLength = rewardTokens.length;
        for (uint256 i; i < tokensLength; ++i) {
            address sellToken = rewardTokens[i];

            /// Apply any potential fees on the reward.
            _doCutRewardsFee(sellToken);

            if (sellToken != closePosParam.param.borrowToken) {
                uint256 expectedReward = closePosParam.amounts[i];
                /// If the expected reward is zero, skip to the next token.
                _swapOnParaswap(sellToken, expectedReward, closePosParam.swapDatas[i]);
            }
        }
    }

    function _swapOnParaswap(address token, uint256 amount, bytes calldata swapData) internal {
        if (amount == 0) return;
        if (!PSwapLib.swap(augustusSwapper, tokenTransferProxy, token, amount, swapData))
            revert Errors.SWAP_FAILED(token);

        // Refund rest amount to owner
        _doRefund(token);
    }
}