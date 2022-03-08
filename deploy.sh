#!/bin/bash

# Constants

VOTING_DELAY=0
VOTING_PERIOD=20
# Threshold should be two numbers because Uint256 has two members. We're just using the lowest number here.
THRESHOLD=1
FILE="deployed_contracts.json"


# Compile everything
echo "Compiling..."
yarn compile:l2
echo "✅ Compiilation done"

echo "Deploying auth contract..."
AUTH=$(hardhat starknet-deploy --starknet-network alpha starknet-artifacts/contracts/starknet/authenticator/authenticator.cairo/authenticator.json | grep 'Contract address' | tail -c 67)
echo "✅ Auth: ${AUTH}"
echo "Deploying strategy contract"
STRATEGY=$(hardhat starknet-deploy --starknet-network alpha starknet-artifacts/contracts/starknet/strategies/vanilla_voting_strategy.cairo/vanilla_voting_strategy.json | grep 'Contract address' | tail -c 67)
echo "✅ Strategy: ${STRATEGY}"
echo "Deploying space contract"
SPACE=$(hardhat starknet-deploy --starknet-network alpha --inputs "${VOTING_DELAY} ${VOTING_PERIOD} ${THRESHOLD} 0 ${STRATEGY} ${AUTH}" starknet-artifacts/contracts/starknet/space/space.cairo/space.json | grep 'Contract address' | tail -c 67)
echo "✅ Space: ${SPACE}"

JSON="{\n
\t\"authenticator\": \"${AUTH}\",\n
\t\"voting_strategy\": \"${STRATEGY}\",\n
\t\"space\": \"${SPACE}\"\n}"

echo $JSON > deployed_contracts.json

echo "✅ Wrote the latest contracts in ${FILE}"