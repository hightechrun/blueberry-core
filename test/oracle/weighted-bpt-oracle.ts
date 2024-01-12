import chai, { assert } from 'chai';
import { ethers, upgrades } from 'hardhat';
import { ADDRESS, CONTRACT_NAMES } from '../../constant';
import { ChainlinkAdapterOracle, CoreOracle, StableBPTOracle, WeightedBPTOracle } from '../../typechain-types';
import { roughlyNear } from '../assertions/roughlyNear';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { fork } from '../helpers';

chai.use(roughlyNear);

const OneDay = 86400;

describe('Balancer Weighted Pool BPT Oracle', () => {
  let admin: SignerWithAddress;
  let weightedOracle: WeightedBPTOracle;
  let stableOracle: StableBPTOracle;
  let coreOracle: CoreOracle;
  let chainlinkAdapterOracle: ChainlinkAdapterOracle;

  before(async () => {
    await fork();
    [admin] = await ethers.getSigners();

    const ChainlinkAdapterOracle = await ethers.getContractFactory(CONTRACT_NAMES.ChainlinkAdapterOracle);
    chainlinkAdapterOracle = <ChainlinkAdapterOracle>await ChainlinkAdapterOracle.deploy(ADDRESS.ChainlinkRegistry);
    await chainlinkAdapterOracle.deployed();

    await chainlinkAdapterOracle.setTimeGap(
      [ADDRESS.USDC, ADDRESS.USDT, ADDRESS.DAI, ADDRESS.CHAINLINK_ETH, ADDRESS.BAL],
      [OneDay, OneDay, OneDay, OneDay, OneDay]
    );

    await chainlinkAdapterOracle.setTokenRemappings([ADDRESS.WETH], [ADDRESS.CHAINLINK_ETH]);

    const CoreOracle = await ethers.getContractFactory(CONTRACT_NAMES.CoreOracle);
    coreOracle = <CoreOracle>await upgrades.deployProxy(CoreOracle);

    const WeightedBPTOracleFactory = await ethers.getContractFactory(CONTRACT_NAMES.WeightedBPTOracle);
    weightedOracle = <WeightedBPTOracle>(
      await WeightedBPTOracleFactory.deploy(ADDRESS.BALANCER_VAULT, coreOracle.address, admin.address)
    );
    await weightedOracle.deployed();

    const StableBPTOracleFactory = await ethers.getContractFactory(CONTRACT_NAMES.StableBPTOracle);

    stableOracle = <StableBPTOracle>(
      await StableBPTOracleFactory.deploy(ADDRESS.BALANCER_VAULT, coreOracle.address, admin.address)
    );

    await stableOracle.deployed();

    await weightedOracle.connect(admin).setStablePoolOracle(stableOracle.address);

    await coreOracle.setRoutes(
      [ADDRESS.USDC, ADDRESS.USDT, ADDRESS.DAI, ADDRESS.BAL, ADDRESS.WETH],
      [
        chainlinkAdapterOracle.address,
        chainlinkAdapterOracle.address,
        chainlinkAdapterOracle.address,
        chainlinkAdapterOracle.address,
        chainlinkAdapterOracle.address,
      ]
    );
  });

  // Nested Weighted Pool with a Stable Pool inside
  it('Verify Price of a Nested Weighted Pool: 50WETH-50-3pool', async () => {
    const thirty = ethers.utils.parseEther('30');
    const fifty = ethers.utils.parseEther('50');

    const price = await weightedOracle.callStatic.getPrice(ADDRESS.BAL_WETH_3POOL);

    assert(price.gte(thirty), 'Price is greater than 30');
    assert(price.lte(fifty), 'Price is less than 50');
  });

  it('Verify Price of a Weighted Pool: B-80BAL-20WETH', async () => {
    const ten = ethers.utils.parseEther('10');
    const twenty = ethers.utils.parseEther('20');

    const price = await weightedOracle.callStatic.getPrice(ADDRESS.BAL_WETH);

    assert(price.gte(ten), 'Price is greater than 10');
    assert(price.lte(twenty), 'Price is less than 20');
  });
});