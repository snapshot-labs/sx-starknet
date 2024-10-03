#!/bin/bash

kill -9 $(lsof -t -i:8545)
kill -9 $(lsof -t -i:5050)
yarn hardhat node &
sleep 5 &&
yarn hardhat test tests/l1-avatar-execution.test.ts --network 'ethereumLocal'
if [ $? -eq 0 ]
then
  kill -9 $(lsof -t -i:8545)
  kill -9 $(lsof -t -i:5050)
  exit 0
else
  kill -9 $(lsof -t -i:8545)
  kill -9 $(lsof -t -i:5050)
  echo "Tests failed"
  exit 1
fi