import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import { ethers } from "hardhat";
import { Contract, ContractFactory } from "ethers";
import abi = require("../LinkAbi.json");





describe("Blackjack", function () {
  let Blackjack: ContractFactory, blackjack: Contract;
  let deployer = new ethers.Wallet("FIXME", ethers.provider);
  //Hardcoded Link Token Contract
  const LinkToken = new ethers.Contract("FIXME", abi, deployer);
  this.beforeAll(async function () {

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
  });

  it("Should set the right owner", async function () {
    expect(await blackjack.owner()).to.equal(deployer.address);
  });

  //   it("Should create a game", async function () {
  //    const [player1] = await ethers.getSigners();
  //    await expect(blackjack.createGame(2, (await ethers.provider.getBlock(ethers.provider.blockNumber)).timestamp + 120, {value: ethers.utils.parseUnits("0.001", 18), gasLimit: 6_000_000})).to.changeEtherBalance(blackjack, ethers.utils.parseUnits("0.001", 18));

  //  });

  //  it("Should not create a game with invalid bet", async function () {
  //   await expect(blackjack.createGame(2, (await ethers.provider.getBlock(ethers.provider.blockNumber)).timestamp + 120, {value: 0, gasLimit: 6_000_000})).to.be.reverted;
  // });

});
