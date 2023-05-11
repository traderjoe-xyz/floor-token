import chainConfigs from "./chain-configs.json" assert { type: "json" };
import { ethers } from "ethers";
import { ContractCreationArgs } from "./types.js";
import ora from "ora";
import dotenv from "dotenv";
import logSymbols from "log-symbols";
dotenv.config();

class MultichainWallet {
  public chains: string[];
  public wallets: Map<string, ethers.Wallet>;

  constructor(chainType: string, chains: string[]) {
    this.chains = chains;
    this.wallets = new Map<string, ethers.Wallet>();

    for (const chain of chains) {
      const chainConfig = chainConfigs[chainType].find(
        (chainConfig) => chainConfig.name === chain
      );

      const provider = new ethers.JsonRpcProvider(chainConfig.rpcUrl);
      const wallet = new ethers.Wallet(process.env.PRIVATE_KEY, provider);

      this.wallets.set(chain, wallet);
    }
  }

  public async verifyBalances() {
    for (const chain of this.chains) {
      const wallet = this.wallets.get(chain);
      const balance = await wallet.provider.getBalance(wallet.address);

      if (balance < ethers.parseEther("0.001")) {
        throw new Error(
          `Insufficient balance on ${chain} wallet. Please add funds and try again.`
        );
      }
    }
  }

  public async deployTokenContracts() {
    const spinner = ora("Deploying the token contracts").start();

    for (const chain of this.chains) {
      // TODO: Deploy the token contracts
      await new Promise((r) => setTimeout(r, 1000));

      spinner.suffixText += `\n   ${logSymbols.info} Deployed on ${chain} at 0x3Fc40920d3c2E4eE27b93F2CE2c44110D94F6Bfa`;
    }

    spinner.succeed("Token contracts deployed");
  }

  public async createLBPairs() {
    const spinner = ora("Creating the LB pairs").start();

    for (const chain of this.chains) {
      // TODO: Create the LB pairs
      await new Promise((r) => setTimeout(r, 1000));

      spinner.suffixText += `\n   ${logSymbols.info} Deployed on ${chain} at 0xE28050B0ef91BEd960F939A30EF5d37f786129E7`;
    }

    spinner.succeed("LB pairs created");
  }

  public async seedLiquidity() {
    const spinner = ora("Seeding initial liquidity").start();

    for (const chain of this.chains) {
      // TODO: Seed the liquidity
      await new Promise((r) => setTimeout(r, 1000));

      spinner.suffixText += `\n   ${logSymbols.info} Done on ${chain}`;
    }

    spinner.succeed("Liquidity seeded");
  }
}

export const deploy = async (deployArgs: ContractCreationArgs) => {
  const wallets = new MultichainWallet(deployArgs.chainType, deployArgs.chains);

  await wallets.verifyBalances();

  await wallets.deployTokenContracts();

  await wallets.createLBPairs();

  await wallets.seedLiquidity();
};
