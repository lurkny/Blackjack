import { ethers } from "hardhat";

async function main() {
 
  const Blackjack = await ethers.getContractFactory("BlackJack");
  const blackjack = await Blackjack.deploy();

  await blackjack.deployed();

  console.log(
    `Blackjack.sol deployed to ${blackjack.address}`
  );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
