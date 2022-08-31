import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import chai, { expect } from 'chai';
import { BigNumber, constants, utils } from 'ethers';
import { ethers } from 'hardhat';
import {
	BlueBerryBank,
	CoreOracle,
	ERC20,
	ICErc20,
	IchiVaultSpellV1,
	IUniswapV2Pair,
	IUniswapV2Router02,
	IWETH,
	ProxyOracle,
	SafeBox,
	SimpleOracle,
	IchiLpOracle,
	WERC20
} from '../../typechain-types';
import { ADDRESS, CONTRACT_NAMES } from '../../constants';
import ERC20ABI from '../../abi/ERC20.json'
import UniswapPairABI from '../../abi/IUniswapV2Pair.json'
import ICrc20ABI from '../../abi/ICErc20.json'
import SpellABI from '../../abi/IchiVaultSpellV1.json';

import { solidity } from 'ethereum-waffle'
import { near } from '../assertions/near'
import { roughlyNear } from '../assertions/roughlyNear'
import { setupBasic } from '../helpers/setup-basic';

chai.use(solidity)
chai.use(near)
chai.use(roughlyNear)

const COMPTROLLER = ADDRESS.COMP;	// Cream Finance / Comptroller
const CUSDC = ADDRESS.cyUSDC;			// Cream Finance / crDAI
const WETH = ADDRESS.WETH;
const USDC = ADDRESS.USDC;
const UNISWAP_LP = ADDRESS.UNI_V2_USDC_WETH;
const ICHI_VAULT = ADDRESS.ICHI_VAULT_USDC;

describe('ICHI Angel Vaults Spell', () => {
	let admin: SignerWithAddress;
	let alice: SignerWithAddress;

	let usdc: ERC20;
	let weth: IWETH;
	let uniLP: ERC20;
	let uniPool: IUniswapV2Pair;
	let cUSDC: ICErc20;
	let werc20: WERC20;
	let simpleOracle: SimpleOracle;
	let ichiOracle: IchiLpOracle;
	let coreOracle: CoreOracle;
	let oracle: ProxyOracle;
	let spell: IchiVaultSpellV1;
	let bank: BlueBerryBank;
	let safeBox: SafeBox;

	before(async () => {
		[admin, alice] = await ethers.getSigners();
		usdc = <ERC20>await ethers.getContractAt(ERC20ABI, USDC, admin);
		weth = <IWETH>await ethers.getContractAt(CONTRACT_NAMES.IWETH, WETH);
		uniLP = <ERC20>await ethers.getContractAt(ERC20ABI, UNISWAP_LP);
		uniPool = <IUniswapV2Pair>await ethers.getContractAt(UniswapPairABI, UNISWAP_LP)
		cUSDC = <ICErc20>await ethers.getContractAt(ICrc20ABI, CUSDC);

		const WERC20 = await ethers.getContractFactory(CONTRACT_NAMES.WERC20);
		werc20 = <WERC20>await WERC20.deploy();
		await werc20.deployed();

		const SimpleOracle = await ethers.getContractFactory(CONTRACT_NAMES.SimpleOracle);
		simpleOracle = <SimpleOracle>await SimpleOracle.deploy();
		await simpleOracle.deployed();
		await simpleOracle.setETHPx(
			[WETH, USDC],
			[
				BigNumber.from(2).pow(112),
				BigNumber.from(2).pow(112).mul(BigNumber.from(10).pow(12)).div(600),
			],
		)

		const IchiLpOracle = await ethers.getContractFactory(CONTRACT_NAMES.IchiLpOracle);
		ichiOracle = <IchiLpOracle>await IchiLpOracle.deploy(simpleOracle.address);
		await ichiOracle.deployed();

		const CoreOracle = await ethers.getContractFactory(CONTRACT_NAMES.CoreOracle);
		coreOracle = <CoreOracle>await CoreOracle.deploy();
		await coreOracle.deployed();

		const ProxyOracle = await ethers.getContractFactory(CONTRACT_NAMES.ProxyOracle);
		oracle = <ProxyOracle>await ProxyOracle.deploy(coreOracle.address);
		await oracle.deployed();

		await oracle.setWhitelistERC1155([werc20.address], true);
		await coreOracle.setRoute(
			[WETH, USDC, ICHI_VAULT],
			[simpleOracle.address, simpleOracle.address, ichiOracle.address]
		)
		await oracle.setTokenFactors(
			[WETH, USDC, ICHI_VAULT],
			[{
				borrowFactor: 10000,
				collateralFactor: 10000,
				liqIncentive: 10000
			}, {
				borrowFactor: 10000,
				collateralFactor: 10000,
				liqIncentive: 10000
			}, {
				borrowFactor: 10000,
				collateralFactor: 10000,
				liqIncentive: 10000
			}]
		)

		// Deploy Bank
		const BlueBerryBank = await ethers.getContractFactory(CONTRACT_NAMES.BlueBerryBank);
		bank = <BlueBerryBank>await BlueBerryBank.deploy();
		await bank.deployed();
		await bank.initialize(oracle.address, 2000);

		// Deploy ICHI spell
		const ICHISpell = await ethers.getContractFactory(CONTRACT_NAMES.IchiVaultSpellV1);
		spell = <IchiVaultSpellV1>await ICHISpell.deploy(
			bank.address,
			werc20.address,
			weth.address,
		)
		await spell.deployed();
		await spell.addVault(USDC, ICHI_VAULT);

		// Setup Bank
		await bank.setWhitelistSpells(
			[spell.address],
			[true]
		)
		await bank.setWhitelistTokens([USDC], [true]);

		// deposit 50 eth -> 50 WETH
		await weth.deposit({ value: utils.parseUnits('50') });
		await weth.approve(ADDRESS.UNI_V2_ROUTER, ethers.constants.MaxUint256);

		// swap 50 weth -> usdc
		const uniV2Router = <IUniswapV2Router02>await ethers.getContractAt(
			CONTRACT_NAMES.IUniswapV2Router02,
			ADDRESS.UNI_V2_ROUTER
		);
		await uniV2Router.swapExactTokensForTokens(
			utils.parseUnits('50'),
			0,
			[WETH, USDC],
			admin.address,
			ethers.constants.MaxUint256
		)

		// Deposit 10k USDC to compound
		const SafeBox = await ethers.getContractFactory(CONTRACT_NAMES.SafeBox);
		safeBox = <SafeBox>await SafeBox.deploy(
			CUSDC,
			"Interest Bearing USDC",
			"ibUSDC"
		)
		await safeBox.deployed();
		await safeBox.setBank(bank.address);
		await bank.addBank(USDC, CUSDC, safeBox.address);

		await usdc.approve(safeBox.address, ethers.constants.MaxUint256);
		await safeBox.deposit(utils.parseUnits("10000", 6));
		console.log(await safeBox.balanceOf(admin.address));
		console.log(await cUSDC.balanceOf(safeBox.address));
	})

	beforeEach(async () => {
	})

	it("test", async () => {
		// await 	
		const iface = new ethers.utils.Interface(SpellABI);

		await usdc.approve(bank.address, ethers.constants.MaxUint256);
		console.log(await usdc.balanceOf(admin.address));
		await bank.execute(
			0,
			spell.address,
			iface.encodeFunctionData("deposit", [
				USDC,
				utils.parseUnits('100', 6),
				utils.parseUnits('10', 6)
			])
		)
	})
})