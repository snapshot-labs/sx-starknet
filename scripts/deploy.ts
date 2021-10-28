const hre = require('hardhat');

async function main() {
  const Stamp = await hre.ethers.getContractFactory('Stamp');
  const stamp = await Stamp.deploy();
  await stamp.deployed();
  console.log('Stamp deployed to:', stamp.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
