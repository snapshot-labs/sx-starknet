#!/bin/bash

# Constants
VOTING_DELAY=0
VOTING_DURATION=100000000
# Threshold should be two numbers because Uint256 has two members. We're just using the lowest number here.
THRESHOLD=1

if [ $1 == "local" ]; then
    NETWORK_OPTION="--gateway-url http://localhost:8000"
    FILE="local.json"
else
    # Defaults to alpha
    NETWORK_OPTION="--starknet-network alpha"
    FILE="goerli.json"
fi
echo "Option: $NETWORK_OPTION"

FILE="deployed_contracts/${FILE}"

# Compile everything
echo "Compiling..."
yarn compile:l2
echo "✅ Compiilation done"

echo "Deploying auth contract..."
AUTH=$(hardhat starknet-deploy ${NETWORK_OPTION} starknet-artifacts/contracts/starknet/authenticator/authenticator.cairo/authenticator.json | grep 'Contract address' | tail -c 67)
echo "✅ Auth: ${AUTH}"
echo "Deploying strategy contract"
STRATEGY=$(hardhat starknet-deploy ${NETWORK_OPTION} starknet-artifacts/contracts/starknet/strategies/vanilla_voting_strategy.cairo/vanilla_voting_strategy.json | grep 'Contract address' | tail -c 67)
echo "✅ Strategy: ${STRATEGY}"
echo "Deploying space contract"
SPACE=$(hardhat starknet-deploy ${NETWORK_OPTION} --inputs "${VOTING_DELAY} ${VOTING_DURATION} ${THRESHOLD} 0 ${STRATEGY} ${AUTH}" starknet-artifacts/contracts/starknet/space/space.cairo/space.json | grep 'Contract address' | tail -c 67)
echo "✅ Space: ${SPACE}"

JSON="{\n
\t\"authenticators\": {\n\t\t\"vanilla\": \"${AUTH}\"\n\t},\n
\t\"voting_strategies\": {\n\t\t\"vanilla\": \"${STRATEGY}\"\n\t},\n
\t\"space\": \"${SPACE}\"\n}"

echo $JSON > $FILE

echo "✅ Wrote the latest contracts in ${FILE}"
