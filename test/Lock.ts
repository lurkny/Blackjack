import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import { ethers } from "hardhat";
import { Contract, ContractFactory } from "ethers";
import abi = require(  "../LinkAbi.json");





describe("Lock", function () {
  let Blackjack : ContractFactory, blackjack: Contract;
  let deployer = new ethers.Wallet("WALLET_PRIVATE_KEY", ethers.provider);
  //Hardcoded Link Token Contract
  const LinkToken = new ethers.Contract("0x779877A7B0D9E8603169DdbD7836e478b4624789", abi, deployer);
  this.beforeAll(async function () {
    this.enableTimeouts(false);
     
     Blackjack = await ethers.getContractFactory("Blackjack");
     blackjack = await Blackjack.deploy();
    
    await blackjack.deployed();
  
    console.log(
      `Blackjack.sol deployed to ${blackjack.address}`
    );
    //Send .1 eth and 10 link to contract
    await deployer.sendTransaction({to: blackjack.address, value: ethers.utils.parseUnits("0.1", 18)});
    await LinkToken.transfer(blackjack.address, ethers.utils.parseUnits("10.0", 18));

    console.log(
      `Sent .1 eth and 10 link to ${blackjack.address}`
    );
  });

    it("Should set the right owner", async function () {
      expect(await blackjack.owner()).to.equal(deployer.address);
    });

    it("Should create a game", async function () {
      const [player1] = await ethers.getSigners();

      expect(await blackjack.createGame({
        value: ethers.utils.parseUnits("0.001", 18),
        data: ethers.utils.solidityPack(["uint8", "uint256"], [2, Math.floor(Date.now() / 1000) + 120])

    })).to.equal(true);

    });

});
