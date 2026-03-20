include .env

.PHONY: build deploy-sepolia test

test:; forge test

deploy:
	@forge script script/DeployedCrowndFundingFactory.s.sol:DeployedCrowndFundingFactory --rpc-url $(RPC_URL) --private-key $(PRIVATE_KEY) --broadcast

deploy-sepolia:
	 @forge script script/DeployedCrowndFundingFactory.s.sol:DeployedCrowndFundingFactory --rpc-url $(SEPOLIA_RPC_URL) --private-key $(SEPOLIA_PRIVATE_KEY) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vvvv