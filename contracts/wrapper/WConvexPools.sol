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

import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "../utils/BlueBerryErrors.sol" as Errors;
import "../libraries/UniversalERC20.sol";
import "../interfaces/IWConvexPools.sol";
import "../interfaces/IERC20Wrapper.sol";
import "../interfaces/convex/IRewarder.sol";
import "../interfaces/convex/ICvxExtraRewarder.sol";
import "../interfaces/convex/IConvex.sol";

/// @title WConvexPools
/// @author BlueberryProtocol
/// @notice Wrapped Convex Pools is the wrapper of LP positions.
/// @dev Leveraged LP Tokens will be wrapped here and be held in BlueberryBank
///      and do not generate yields. LP Tokens are identified by tokenIds
///      encoded from lp token address.
contract WConvexPools is
    ERC1155Upgradeable,
    ReentrancyGuardUpgradeable,
    OwnableUpgradeable,
    IERC20Wrapper,
    IWConvexPools
{
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using UniversalERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////////////////
                                   PUBLIC STORAGE
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Address to Convex Pools contract
    ICvxPools public cvxPools;
    /// @dev Address to CVX token
    IConvex public CVX;
    /// @dev Mapping from token id to accExtPerShare
    mapping(uint256 => mapping(address => uint256)) public accExtPerShare;
    /// @dev Extra rewards addresses (pid => address[])
    mapping(uint256 => address[]) public extraRewards;
    /// @dev The index of extra rewards (pid => extraRewardsIdx)
    mapping(uint256 => mapping(address => uint256)) public extraRewardsIdx;
    /// @dev CVX reward per share by pid
    mapping(uint256 => uint256) public cvxPerShareByPid;
    /// token id => cvxPerShareDebt;
    mapping(uint256 => uint256) public cvxPerShareDebt;
    /// @dev pid => last crv reward per token
    mapping(uint256 => uint256) public lastCrvPerTokenByPid;

    /// @dev Initialize the smart contract references.
    /// @param cvx_ Address of the CVX token.
    /// @param cvxPools_ Address of the Convex Pools.
    function initialize(address cvx_, address cvxPools_) external initializer {
        __ReentrancyGuard_init();
        __ERC1155_init("WConvexPools");
        CVX = IConvex(cvx_);
        cvxPools = ICvxPools(cvxPools_);
    }

    /// @notice Encode pid and cvxPerShare into an ERC1155 token id.
    /// @param pid Pool id which is the first 16 bits.
    /// @param cvxPerShare CVX amount per share, which should be multiplied by 1e18 and is the last 240 bits.
    /// @return id The encoded token id.
    function encodeId(
        uint256 pid,
        uint256 cvxPerShare
    ) public pure returns (uint256 id) {
        if (pid >= (1 << 16)) revert Errors.BAD_PID(pid);
        if (cvxPerShare >= (1 << 240)) {
            revert Errors.BAD_REWARD_PER_SHARE(cvxPerShare);
        }
        return (pid << 240) | cvxPerShare;
    }

    /// @notice Decode an ERC1155 token id into its pid and cvxPerShare components.
    /// @param id Token id.
    /// @return pid The decoded pool id.
    /// @return cvxPerShare The decoded CVX amount per share.
    function decodeId(
        uint256 id
    ) public pure returns (uint256 pid, uint256 cvxPerShare) {
        pid = id >> 240; // Extract the first 16 bits
        cvxPerShare = id & ((1 << 240) - 1); // Extract the last 240 bits
    }

    /// @notice Fetch the underlying ERC20 token of the given ERC1155 token id.
    /// @param id Token id.
    /// @return uToken Address of the underlying ERC20 token.
    function getUnderlyingToken(
        uint256 id
    ) external view override returns (address uToken) {
        (uint256 pid, ) = decodeId(id);
        (uToken, , , , , ) = getPoolInfoFromPoolId(pid);
    }

    /// @notice Fetch pool information from the Convex Booster.
    /// @param pid Convex pool id.
    /// @return lptoken Address of the liquidity provider token.
    /// @return token Address of the reward token.
    /// @return gauge Address of the gauge contract.
    /// @return crvRewards Address of the Curve rewards contract.
    /// @return stash Address of the stash contract.
    /// @return shutdown Indicates if the pool is shutdown.
    function getPoolInfoFromPoolId(
        uint256 pid
    )
        public
        view
        returns (
            address lptoken,
            address token,
            address gauge,
            address crvRewards,
            address stash,
            bool shutdown
        )
    {
        return cvxPools.poolInfo(pid);
    }

    /// @notice Get pending reward amount
    /// @param stRewardPerShare reward per share
    /// @param rewarder Address of rewarder contract
    /// @param amount lp amount
    /// @param lpDecimals lp decimals
    function _getPendingReward(
        uint256 stRewardPerShare,
        address rewarder,
        uint256 amount,
        uint256 lpDecimals
    ) internal view returns (uint256 rewards) {
        uint256 enRewardPerShare = IRewarder(rewarder).rewardPerToken();
        uint256 share = enRewardPerShare > stRewardPerShare
            ? enRewardPerShare - stRewardPerShare
            : 0;
        rewards = (share * amount) / (10 ** lpDecimals);
    }

    /// Calculates the CVX pending reward based on CRV reward
    /// @param crvAmount Amount of CRV reward
    /// @return mintAmount The pending CVX reward
    function _getCvxPendingReward(
        uint256 crvAmount
    ) internal view returns (uint256 mintAmount) {
        if (crvAmount == 0) return 0;
        /// CVX token mint logic
        uint256 totalCliffs = CVX.totalCliffs();
        uint256 totalSupply = CVX.totalSupply();
        uint256 maxSupply = CVX.maxSupply();
        uint256 reductionPerCliff = CVX.reductionPerCliff();
        uint256 cliff = totalSupply / reductionPerCliff;

        if (totalSupply == 0) {
            mintAmount = crvAmount;
        }

        if (cliff < totalCliffs) {
            uint256 reduction = totalCliffs - cliff;
            mintAmount = (crvAmount * reduction) / totalCliffs;
            uint256 amtTillMax = maxSupply - totalSupply;

            if (mintAmount > amtTillMax) {
                mintAmount = amtTillMax;
            }
        }
    }

    function _getAllocatedCVX(
        uint256 pid,
        uint256 stCrvPerShare,
        uint256 amount
    ) internal view returns (uint256 mintAmount) {
        (address lpToken, , , address crvRewarder, , ) = getPoolInfoFromPoolId(
            pid
        );
        uint256 currentDeposits = IRewarder(crvRewarder).balanceOf(
            address(this)
        );

        if (currentDeposits == 0) {
            return 0;
        }

        uint256 cvxPerShare = cvxPerShareByPid[pid] -
            cvxPerShareDebt[encodeId(pid, stCrvPerShare)];

        uint256 lastCrvPerToken = lastCrvPerTokenByPid[pid];

        uint256 lpDecimals = IERC20MetadataUpgradeable(lpToken).decimals();
        uint256 earned = _getPendingReward(
            lastCrvPerToken,
            crvRewarder,
            currentDeposits,
            lpDecimals
        );

        if (earned != 0) {
            uint256 cvxReward = _getCvxPendingReward(earned);

            cvxPerShare += (cvxReward * 1e18) / currentDeposits;
        }

        return (cvxPerShare * amount) / 1e18;
    }

    /// Returns pending rewards from the farming pool
    /// @param tokenId Token Id
    /// @param amount Amount of share
    /// @return tokens An array of token addresses for rewards
    /// @return rewards An array of pending rewards corresponding to the tokens
    function pendingRewards(
        uint256 tokenId,
        uint256 amount
    )
        public
        view
        override
        returns (address[] memory tokens, uint256[] memory rewards)
    {
        (uint256 pid, uint256 stCrvPerShare) = decodeId(tokenId);
        (address lpToken, , , address cvxRewarder, , ) = getPoolInfoFromPoolId(
            pid
        );
        uint256 lpDecimals = IERC20MetadataUpgradeable(lpToken).decimals();
        uint256 extraRewardsCount = extraRewards[pid].length;
        tokens = new address[](extraRewardsCount + 2);
        rewards = new uint256[](extraRewardsCount + 2);

        /// CRV reward
        tokens[0] = IRewarder(cvxRewarder).rewardToken();
        rewards[0] = _getPendingReward(
            stCrvPerShare,
            cvxRewarder,
            amount,
            lpDecimals
        );

        /// CVX reward
        tokens[1] = address(CVX);
        rewards[1] = _getAllocatedCVX(pid, stCrvPerShare, amount);

        for (uint256 i; i < extraRewardsCount; ++i) {
            address rewarder = extraRewards[pid][i];
            uint256 stRewardPerShare = accExtPerShare[tokenId][rewarder];
            tokens[i + 2] = IRewarder(rewarder).rewardToken();
            if (stRewardPerShare == 0) {
                rewards[i + 2] = 0;
            } else {
                rewards[i + 2] = _getPendingReward(
                    stRewardPerShare == type(uint256).max
                        ? 0
                        : stRewardPerShare,
                    rewarder,
                    amount,
                    lpDecimals
                );
            }
        }
    }

    /// Mints ERC1155 token for the given LP token
    /// @param pid Convex Pool id
    /// @param amount Token amount to wrap
    /// @return id The minted token ID
    function mint(
        uint256 pid,
        uint256 amount
    ) external nonReentrant returns (uint256 id) {
        _updateCvxReward(pid);

        (address lpToken, , , address cvxRewarder, , ) = getPoolInfoFromPoolId(
            pid
        );
        IERC20Upgradeable(lpToken).safeTransferFrom(
            msg.sender,
            address(this),
            amount
        );

        IERC20(lpToken).universalApprove(address(cvxPools), amount);
        cvxPools.deposit(pid, amount, true);

        uint256 crvRewardPerToken = IRewarder(cvxRewarder).rewardPerToken();
        id = encodeId(pid, crvRewardPerToken);
        _mint(msg.sender, id, amount, "");
        /// Store extra rewards info
        uint256 extraRewardsCount = IRewarder(cvxRewarder).extraRewardsLength();
        for (uint256 i; i < extraRewardsCount; ++i) {
            address extraRewarder = IRewarder(cvxRewarder).extraRewards(i);
            uint256 rewardPerToken = IRewarder(extraRewarder).rewardPerToken();
            accExtPerShare[id][extraRewarder] = rewardPerToken == 0
                ? type(uint256).max
                : rewardPerToken;

            _syncExtraReward(pid, extraRewarder);
        }

        cvxPerShareDebt[id] = cvxPerShareByPid[pid];
    }

    /// Burns ERC1155 token to redeem ERC20 token back and harvest rewards
    /// @param id Token id to burn
    /// @param amount Token amount to burn
    /// @return rewardTokens The array of reward token addresses
    /// @return rewards The array of harvested reward amounts
    function burn(
        uint256 id,
        uint256 amount
    )
        external
        nonReentrant
        returns (address[] memory rewardTokens, uint256[] memory rewards)
    {
        if (amount == type(uint256).max) {
            amount = balanceOf(msg.sender, id);
        }
        (rewardTokens, rewards) = pendingRewards(id, amount);
        (uint256 pid, ) = decodeId(id);

        _updateCvxReward(pid);

        _burn(msg.sender, id, amount);

        (address lpToken, , , address cvxRewarder, , ) = getPoolInfoFromPoolId(
            pid
        );
        /// Claim Rewards
        IRewarder(cvxRewarder).withdraw(amount, true);
        /// Withdraw LP
        cvxPools.withdraw(pid, amount);

        /// Transfer LP Tokens
        IERC20Upgradeable(lpToken).safeTransfer(msg.sender, amount);

        uint256 extraRewardsCount = IRewarder(cvxRewarder).extraRewardsLength();

        for (uint256 i; i < extraRewardsCount; ++i) {
            _syncExtraReward(pid, IRewarder(cvxRewarder).extraRewards(i));

        }
        uint256 storedExtraRewardLength = extraRewards[pid].length;
        bool hasDiffExtraRewards = extraRewardsCount != storedExtraRewardLength;

        /// Transfer Reward Tokens

        /// Withdraw manually
        if (hasDiffExtraRewards) {
            for (uint256 i; i < storedExtraRewardLength; ++i) {
                ICvxExtraRewarder(extraRewards[pid][i]).getReward();
            }
        }

        uint256 rewardLen = rewardTokens.length;
        for (uint256 i; i < rewardLen; ++i) {
            IERC20Upgradeable(rewardTokens[i]).safeTransfer(
                msg.sender,
                rewards[i]
            );
        }
    }

    /// Gets the length of the extra rewards array
    /// @return Length of the extra rewards array
    function extraRewardsLength(uint256 pid) external view returns (uint256) {
        return extraRewards[pid].length;
    }

    /// Internal function to synchronize extra rewards
    function _syncExtraReward(uint pid, address extraReward) private {
        if (extraRewardsIdx[pid][extraReward] == 0) {
            extraRewards[pid].push(extraReward);
            extraRewardsIdx[pid][extraReward] = extraRewards[pid].length;
        }
    }

    function _updateCvxReward(uint256 pid) private {
        (, , , address crvRewarder, , ) = getPoolInfoFromPoolId(pid);
        uint256 currentDeposits = IRewarder(crvRewarder).balanceOf(
            address(this)
        );

        lastCrvPerTokenByPid[pid] = IRewarder(crvRewarder).rewardPerToken();

        if (currentDeposits == 0) {
            return;
        }

        uint cvxBalBefore = CVX.balanceOf(address(this));

        // Claim extra rewards at withdrawal
        IRewarder(crvRewarder).getReward(address(this), false);

        uint256 cvxReward = CVX.balanceOf(address(this)) - cvxBalBefore;

        cvxPerShareByPid[pid] += (cvxReward * 1e18) / currentDeposits;
    }
}
