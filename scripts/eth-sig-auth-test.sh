#!/bin/bash

kill -9 $(lsof -t -i:5050)
yarn chain:l2 &
yarn wait-on tcp:5050 &&
yarn hardhat test starknet/test/eth-sig-auth.test.ts
if [ $? -eq 0 ]
then
  kill -9 $(lsof -t -i:5050)
  exit 0
else
  kill -9 $(lsof -t -i:5050)
  echo "Tests failed"
  exit 1
fi