import hre, { starknet, ethers, network, waffle } from 'hardhat';

async function main() {
  // Script view balances of 2 goerli accounts
  const [account1, account2] = await ethers.getSigners();
  console.log(
    'Account 1:',
    account1.address,
    ' Goerli balance: ',
    (await account1.getBalance()).toString()
  );
  console.log(
    'Account 2:',
    account2.address,
    ' Goerli balance: ',
    (await account2.getBalance()).toString()
  );
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
