import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";

const INFURA_API_KEY = "31e7fdbff4c2430bac06323d6d13bbb1";

const SEPOLIA_PRIVATE_KEY = "b165ba445525fb6f15999d1dd3465ab4537f01ca3e48cdb18aaa1a9da78624ac";

const config: HardhatUserConfig = {
  solidity: "0.8.18",
  networks: {
    sepolia: {
      url: `https://sepolia.infura.io/v3/${INFURA_API_KEY}`,
      accounts: [SEPOLIA_PRIVATE_KEY]
    }
  },
  etherscan: {
    apiKey: "54CEZRHSMIP7XUV3Z9GI19DHBECASGM39P",
  },
};
export default config;
