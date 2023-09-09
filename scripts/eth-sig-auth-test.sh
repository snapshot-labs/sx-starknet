#!/bin/bash

kill -9 $(lsof -t -i:5050)
yarn chain:l2 &
sleep 10 &&
yarn hardhat test tests/eth-sig-auth.test.ts
if [ $? -eq 0 ]
then
  kill -9 $(lsof -t -i:5050)
  exit 0
else
  kill -9 $(lsof -t -i:5050)
  echo "Tests failed"
  exit 1
fi