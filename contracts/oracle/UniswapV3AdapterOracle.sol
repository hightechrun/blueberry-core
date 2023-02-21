// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

import "./BaseAdapter.sol";
import "./UsingBaseOracle.sol";
import "../interfaces/IBaseOracle.sol";
import "../libraries/UniV3/UniV3WrappedLibMockup.sol";

contract UniswapV3AdapterOracle is IBaseOracle, UsingBaseOracle, BaseAdapter {
    event SetPoolStable(address token, address pool);

    mapping(address => address) public stablePools; // Mapping from token address to token/(USDT/USDC/DAI) pool address

    constructor(IBaseOracle _base) UsingBaseOracle(_base) {}

    /// @dev Set price reference for Stable pair
    /// @param tokens list of tokens to set reference
    /// @param pools list of reference pool contract addresses
    function setStablePools(address[] calldata tokens, address[] calldata pools)
        external
        onlyOwner
    {
        if (tokens.length != pools.length) revert Errors.INPUT_ARRAY_MISMATCH();
        for (uint256 idx = 0; idx < tokens.length; idx++) {
            if (tokens[idx] == address(0) || pools[idx] == address(0))
                revert Errors.ZERO_ADDRESS();
            stablePools[tokens[idx]] = pools[idx];
            emit SetPoolStable(tokens[idx], pools[idx]);
        }
    }

    /// @dev Return the USD based price of the given input, multiplied by 10**18.
    /// @param token The ERC-20 token to check the value.
    function getPrice(address token) external view override returns (uint256) {
        // Maximum cap of maxDelayTime is 2 days(172,800), safe to convert
        uint32 secondsAgo = uint32(maxDelayTimes[token]);
        if (secondsAgo == 0) revert Errors.NO_MEAN(token);

        address stablePool = stablePools[token];
        if (stablePool == address(0)) revert Errors.NO_STABLEPOOL(token);

        address poolToken0 = IUniswapV3Pool(stablePool).token0();
        address poolToken1 = IUniswapV3Pool(stablePool).token1();
        address stablePoolToken = poolToken0 == token ? poolToken1 : poolToken0; // get stable token address

        uint256 stableDecimals = uint256(
            IERC20Metadata(stablePoolToken).decimals()
        );
        uint256 tokenDecimals = uint256(IERC20Metadata(token).decimals());

        (int24 arithmeticMeanTick, ) = UniV3WrappedLibMockup.consult(
            stablePool,
            secondsAgo
        );
        uint256 quoteTokenAmountForStable = UniV3WrappedLibMockup
            .getQuoteAtTick(
                arithmeticMeanTick,
                uint128(10**tokenDecimals),
                token,
                stablePoolToken
            );

        return
            (quoteTokenAmountForStable * base.getPrice(stablePoolToken)) /
            10**stableDecimals;
    }
}
