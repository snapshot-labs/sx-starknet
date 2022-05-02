#!/bin/bash

yarn wait-on tcp:8000 && 
yarn test:l2
if [ $? -eq 0 ]
then
  kill -9 $(lsof -t -i:8000)
  exit 0
else
  kill -9 $(lsof -t -i:8000)
  echo "Tests failed"
  exit 1
fi