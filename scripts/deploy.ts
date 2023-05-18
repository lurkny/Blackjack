
import { ethers } from "hardhat";
import { Contract, ContractFactory } from "ethers";
import abi = require("../LinkAbi.json");

async function main() {

  let Blackjack: ContractFactory, blackjack: Contract;
  let deployer = new ethers.Wallet("FIXME", ethers.provider);
  //Hardcoded Link Token Contract
  const LinkToken = new ethers.Contract("0x514910771AF9Ca656af840dff83E8264EcF986CA", abi, deployer);


  Blackjack = await ethers.getContractFactory("BlackJack");
  blackjack = await Blackjack.deploy({ gasLimit: 6_000_000 });

  await blackjack.deployed();

  console.log(
    `Blackjack.sol deployed to ${blackjack.address}`
  );
  //Send .1 eth and 10 link to contract
  await deployer.sendTransaction({ to: blackjack.address, value: ethers.utils.parseEther("0.05"), gasLimit: 6_000_000 });
  await LinkToken.transfer(blackjack.address, ethers.utils.parseUnits("2.0", 18), { gasLimit: 6_000_000 });

  console.log(
    `Sent .1 eth and 10 link to ${blackjack.address}`
  );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
