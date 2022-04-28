#!/bin/bash

yarn wait-on tcp:8000 && 
wait-on tcp:8545 && 
yarn hardhat test test/crosschain/zodiac.ts --network 'ethereumLocal' --starknet-network 'starknetLocal' && 
sleep 10 && 
yarn hardhat test test/crosschain/ethereum_transaction_authentication.ts --network 'ethereumLocal' --starknet-network 'starknetLocal'
if [ $? -eq 0 ]
then
  kill -9 $(lsof -t -i:8545)
  kill -9 $(lsof -t -i:8000)
  echo here
  exit 0
else
  kill -9 $(lsof -t -i:8545)
  kill -9 $(lsof -t -i:8000)
  exit 1
fi