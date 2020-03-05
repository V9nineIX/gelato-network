export const deployments = {
	// ========== KOVAN ===========
	// === Actions ===
	// BzX
	ActionBzxPtokenBurnToToken: "0x43dFFE6f0C2029e397Fa47DD27587Ef6297660C3",
	ActionBzxPtokenMintWithToken: "0x080d3059b30D3B7EDffa1B0B9AE981f0Ce94168E",
	// erc20
	ActionERC20Transfer: "0x213719cD7c69DCA764E336bEb8D735DA01FD6c83",
	ActionERC20TransferFrom: "0x24b7b219E903d11489227c5Bed0718D90C03eBc2",
	ActionChainedTimedERC20TransferFrom: "0xd41Ba730090e731806E0146e203d92F8b5107d12",
	// ETHLONDON
	ActionRebalancePortfolio: "0x3e709fd3A0Cf9919916C847F5b3cf722e61b76Bf",
	// kyber
	ActionKyberTradeKovan: "0xF829B506c378AaD11dB7Efe8d626cc7d0e015CBA",
	// ==== Gelato Core ===
	GelatoCore: "0x35b9b372cF07B2d6B397077792496c61721B58fa",
	// === Conditions ===
	// balance
	ConditionBalance: "0x60621bf3F7132838b27972084eaa56E87395D44B",
	// greed
	ConditionFearGreedIndex: "0x01697631e006D76FcD22EEe0aAA7b3b4B42b6819",
	// kyber
	ConditionKyberRateKovan: "0xD8eBB69Dc566E86eA6e09A15EBe6Fd9c65c4A698",
	// time
	ConditionTimestampPassed: "0x10A46c633adfe5a6719f3DBd2c162676779fE70B",
	// ==== Scripts ====
	ScriptGnosisSafeEnableGelatoCore:
		"0x99D081a6c07043e9E78A231Ae2c41fa811AD856C",
	ScriptGnosisSafeEnableGelatoCoreAndMint:
		"0x5993ff30b943dE4c3fDA59d88D87d1661412D101"
};
