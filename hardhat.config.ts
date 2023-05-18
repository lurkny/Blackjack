import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";

const INFURA_API_KEY = "FIXME";

const SEPOLIA_PRIVATE_KEY = "FIXME";

const config: HardhatUserConfig = {
  solidity: "0.8.18",
  networks: {
    sepolia: {
      url: `https://sepolia.infura.io/v3/${INFURA_API_KEY}`,
      accounts: [SEPOLIA_PRIVATE_KEY]
    },
    phalcon: {
      url: "https://rpc.phalcon.xyz/FIXME",
      accounts: [`${SEPOLIA_PRIVATE_KEY}`]
    }
  },
  etherscan: {
    apiKey: "54CEZRHSMIP7XUV3Z9GI19DHBECASGM39P",
  },
};
export default config;
