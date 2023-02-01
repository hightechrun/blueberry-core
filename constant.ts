export enum CONTRACT_NAMES {
	// Token
	ERC20 = 'ERC20',
	IERC20 = 'IERC20',

	// MOCK
	MockWETH = 'MockWETH',
	MockERC20 = 'MockERC20',
	MockCErc20 = 'MockCErc20',
	MockCErc20_2 = 'MockCErc20_2',
	MockFeedRegistry = 'MockFeedRegistry',
	MockOracle = "MockOracle",

	// Wrapper
	WERC20 = 'WERC20',
	WMasterChef = 'WMasterChef',
	WIchiFarm = 'WIchiFarm',
	WLiquidityGauge = 'WLiquidityGauge',
	WStakingRewards = 'WStakingRewards',

	// Oracles
	BandAdapterOracle = "BandAdapterOracle",
	ChainlinkAdapterOracle = "ChainlinkAdapterOracle",
	CoreOracle = "CoreOracle",
	UniswapV2Oracle = "UniswapV2Oracle",
	BalancerPairOracle = "BalancerPairOracle",
	ERC20KP3ROracle = "ERC20KP3ROracle",
	CurveOracle = "CurveOracle",
	UniswapV3AdapterOracle = "UniswapV3AdapterOracle",
	AggregatorOracle = "AggregatorOracle",
	IchiLpOracle = "IchiLpOracle",

	// Protocol
	BlueBerryBank = 'BlueBerryBank',
	HardVault = 'HardVault',
	SoftVault = 'SoftVault',
	ProtocolConfig = 'ProtocolConfig',

	// Spell
	UniswapV2SpellV1 = "UniswapV2SpellV1",
	SushiswapSpellV1 = "SushiswapSpellV1",
	BalancerSpellV1 = "BalancerSpellV1",
	CurveSpellV1 = "CurveSpellV1",
	IchiVaultSpell = "IchiVaultSpell",

	// Interface
	IWETH = "IWETH",
	IComptroller = "IComptroller",
	ICEtherEx = "ICEtherEx",
	ICErc20 = "ICErc20",
	ICurvePool = "ICurvePool",
	ICurveRegistry = "ICurveRegistry",
	IERC20Metadata = "IERC20Metadata",
	IUniswapV2Pair = "IUniswapV2Pair",
	IUniswapV2Router02 = "IUniswapV2Router02",
	IUniswapV3Pool = "IUniswapV3Pool",
	IICHIVault = 'IICHIVault',
}

export const ADDRESS_GOERLI = {
	// Tokens
	MockUSDC: '0xcBB1082F4cD910E0A6C788Bc8F3eC07Dd1890670',
	MockIchiV1: '0x19930a447039c033664af11BCF861076ea79D42e',
	MockIchiV2: '0xaE6F9D934d75E7ef5930A3c8817f6B61565A40c2',
	ALCX: '0x9eD02f1C12AdB524EC901f37cB4d9b183B2e578d',
	BAL: '0x6c5ADE58aB4417012CBA549e5f8D7F71aE7Ede74',
	BLB: '0x745229756e606C88194be866B789A7a9d90BDEc5',
	CRV: '0xFA4cf6f231F198Ea682A0Dffd9B34679aF9Da754',
	DAI: '0xA2add465F592488267a589a6C21760a65de30aF0',
	WETH: '0x203788323Ab4B29220972972E7dEF2a037523A49',
	WBTC: '0x9Ca01f860BF0803625fF858EE63D3Fca68ECf43e',
	SUSHI: '0x90EAB39BbF837021f7454e310f6dB04e66B002d8',
	USDD: '0x1f194493aC9127e62E7f069A14aDCD51673Ea2D8',

	bALCX: '0x5DC9BC86A2BdC1261a941dd9520E11b06fF2F0b0',
	bBAL: '0xf7137e7AeFb7cC02353e6d4562144735EaDCFc9e',
	bBLB: '0x2D5335Be8753Ad83E93E9a76F7f00933C0152eF8',
	bCRV: '0x2cd7B693f8e42F50f3FEecfC2B4Fb464C6351ADe',
	bDAI: '0x05ccc8fb1D450256210e51f51D066c941485899E',
	bICHI: '0x3Ccf72A56420dF4034627e53D80cA424f8596823',
	bSUSHI: '0xc16080Cb99f65fEe5A82e0A9aFDf6cA78E9DbF3D',
	bUSDD: '0x44AdbE2071a1fE267645AEF7df8e2FCdE0d595F8',
	bUSDC: '0xF0D4beb18031e8EC2E434D2ee8C977303f700918',
	bWBTC: '0xc849451401ca1dB63A39B08546619D84289D51F5',
	bWETH: '0x948E51bb758bbbf142CAe2f36FFDAe48a894a275',

	CHAINLINK_BTC: '0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB',
	CHAINLINK_ETH: '0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE',
	CHAINLINK_USD: '0x0000000000000000000000000000000000000348',

	// LP
	UNI_V3_ICHI_USDC: '0x0167ab6BA8ef6a8964aa9DFD5364090C8162AD8D',
	UNI_V3_USDC_BLB: '0x77EA6b8E393129Ed61a95406c63AA9460f334BaC',
	UNI_V3_ICHI_BLB: '0x5969E18546eDf3e8836Bc6603441104b866FAFe9',

	// Compound
	COMP: '0x91EB071424A1C0cE760a51CBf733B7863fe9E57B',

	// ICHI
	ICHI_VAULT_USDC: '0xe768eb7adF7b555FA3726e17eb0595c9850cCBb9',
	ICHI_VAULT_USDC_BLB: '0xBF03f7CA2B10B22677BB4F48B1ADC22EC1a32620',
	ICHI_FARMING: '0x616b9E0598D92DF2c826DeeE5934c43269F9b62A',
}

export const ADDRESS = {
	// Tokens
	CRV: '0xd533a949740bb3306d119cc777fa900ba034cd52',
	DAI: '0x6b175474e89094c44da98b954eedeac495271d0f',
	DPI: '0x1494ca1f11d487c2bbe4543e90080aeba4ba3c2b',
	ETH: '0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE',
	ICHI: '0x111111517e4929d3dcbdfa7cce55d30d4b6bc4d6',
	ICHI_FARM: '0x903bEF1736CDdf2A537176cf3C64579C3867A881',
	INDEX: '0x0954906da0Bf32d5479e25f46056d22f08464cab',
	PERP: '0xbC396689893D065F41bc2C6EcbeE5e0085233447',
	SNX: '0xc011a73ee8576fb46f5e1c5751ca3b9fe0af2a6f',
	SUSHI: '0x6B3595068778DD592e39A122f4f5a5cF09C90fE2',
	UNI: '0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984',
	USDT: '0xdac17f958d2ee523a2206206994597c13d831ec7',
	USDC: '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48',
	WBTC: '0x2260fac5e5542a773aa44fbcfedf7c193bc2c599',
	WETH: '0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2',
	bUSDC: '0xdfd54ac444eEffc121E3937b4EAfc3C27d39Ae64',
	bICHI: '0xBDf1431c153A2A48Ee05C1F24b9Dc476C93F75aE',
	bDAI: '0xcB5C1909074C7ac1956DdaFfA1C2F1cbcc67b932',
	bCRV: '0x23ED643A4C4542E223e7c7815d420d6d42556006',
	bSUSHI: '0x8644e2126776daFE02C661939075740EC378Db00',
	bWBTC: '0x506c190340F786c65548C0eE17c5EcDbba7807e0',
	bWETH: '0x8E09cC1d00c9bd67f99590E1b2433bF4Db5309C3',
	crETH: '0xD06527D5e56A3495252A528C4987003b712860eE',
	crDAI: '0x92B767185fB3B04F881e3aC8e5B0662a027A1D9f',
	crUSDC: '0x44fbebd2f576670a6c33f6fc0b00aa8c5753b322',
	crUSDT: '0x797AAB1ce7c01eB727ab980762bA88e7133d2157',
	cUSDC: '0x39AA39c021dfbaE8faC545936693aC917d5E7563',
	cyUSDC: '0x76Eb2FE28b36B3ee97F3Adae0C69606eeDB2A37c',
	CHAINLINK_BTC: '0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB',
	CHAINLINK_ETH: '0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE',
	CHAINLINK_USD: '0x0000000000000000000000000000000000000348',

	// LP
	UNI_V2_USDT_USDC: '0x3041cbd36888becc7bbcbc0045e3b1f144466f5f',
	UNI_V2_DPI_WETH: '0x4d5ef58aAc27d99935E5b6B4A6778ff292059991',
	UNI_V2_DAI_WETH: '0xa478c2975ab1ea89e8196811f51a7b7ade33eb11',
	UNI_V2_USDT_WETH: '0x0d4a11d5eeaac28ec3f61d100daf4d40471f1852',
	UNI_V2_USDC_CRV: '0x210a97ba874a8e279c95b350ae8ba143a143c159',
	UNI_V2_USDC_WETH: '0xb4e16d0168e52d35cacd2c6185b44281ec28c9dc',
	UNI_V2_WBTC_WETH: '0xbb2b8038a1640196fbe3e38816f3e67cba72d940',
	SUSHI_WETH_USDT: '0x06da0fd433c1a5d7a4faa01111c044910a184553',
	SUSHI_ICHIV1_WETH: '0x9cD028B1287803250B1e226F0180EB725428d069',
	BAL_WETH_DAI_8020: '0x8b6e6e7b5b3801fed2cafd4b22b8a16c2f2db21a',
	BAL_PERP_USDC_8020: '0xF54025aF2dc86809Be1153c1F20D77ADB7e8ecF4',
	CRV_3Crv: '0x6c3f90f043a72fa612cbac8115ee7e52bde6e490',
	UNI_V3_UNI_WETH: '0x1d42064fc4beb5f8aaf85f4617ae8b3b5b8bd801',
	UNI_V3_UNI_USDC: '0xD0fC8bA7E267f2bc56044A7715A489d851dC6D78',
	UNI_V3_ICHI_USDC: '0x8f0350c8Be74B4cB0458cbf04d16753000fDA9d0',

	// Oracle
	Keep3rV1Oracle: '0x73353801921417F465377c8d898c6f4C0270282C',
	BandStdRef: '0xDA7a001b254CD22e46d3eAB04d937489c93174C3',
	ChainlinkRegistry: '0x47Fb2585D2C56Fe188D0E6ec628a38b74fCeeeDf',

	UNI_V2_ROUTER: '0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D',
	SUSHI_ROUTER: '0xd9e1ce17f2641f24ae83637ab66a2cca9c378b9f',

	// Wrapper
	SUSHI_MASTERCHEF: '0xc2EdaD668740f1aA35E4D8f227fB8E17dcA888Cd',
	CRV_GAUGE: '0x7D86446dDb609eD0F5f8684AcF30380a356b2B4c',
	CRV_3Crv_POOL: '0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7',
	IC_DPI_STAKING_REWARDS: '0xB93b505Ed567982E2b6756177ddD23ab5745f309',
	PERP_BALANCER_LP_REWARDS: '0xb9840a4a8a671f79de3df3b812feeb38047ce552',

	// Lending Market
	CREAM_COMP: '0x3d5BC3c8d13dcB8bF317092d84783c2697AE9258',
	IRON_COMP: '0xab1c342c7bf5ec5f02adea1c2270670bca144cbb',
	BLB_COMPTROLLER: '0x37697298481d1B07B0AfFc9Ef5e9cDeec829EFc8',

	// ICHI
	ICHI_VAULT_USDC: '0x683F081DBC729dbD34AbaC708Fa0B390d49F1c39',
	ICHI_FARMING: '0x275dfe03bc036257cd0a713ee819dbd4529739c8',
}