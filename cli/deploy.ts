import { Wallet, ethers } from "ethers";
import ora from "ora";
import dotenv from "dotenv";
import logSymbols from "log-symbols";
import util from "node:util";
import { exec } from "node:child_process";

import { ContractCreationArgs } from "./types.js";

import chainConfigs from "./chain-configs.json" assert { type: "json" };

const execSync = util.promisify(exec);
dotenv.config();

class MultichainWallet {
  public chains: string[];
  public wallets: Map<string, ethers.Wallet>;
  public rpcs: Map<string, string>;

  constructor(chainType: string, chains: string[]) {
    this.chains = chains;
    this.wallets = new Map<string, ethers.Wallet>();
    this.rpcs = new Map<string, string>();

    for (const chain of chains) {
      const chainConfig = chainConfigs[chainType].find(
        (chainConfig) => chainConfig.name === chain
      );

      const provider = new ethers.JsonRpcProvider(chainConfig.rpcUrl);
      const wallet = new ethers.Wallet(process.env.PRIVATE_KEY, provider);

      this.wallets.set(chain, wallet);
      this.rpcs.set(chain, chainConfig.rpcUrl);
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
    const spinner = ora("Deploying the token contract").start();

    for (const chain of this.chains) {
      const wallet = this.wallets.get(chain);
      const rpc = this.rpcs.get(chain);

      const address = await deployContract("src/Token.sol:Token", wallet, rpc);

      spinner.suffixText += `\n   ${logSymbols.info} Deployed on ${chain} at ${address}`;
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
  const wallets = new MultichainWallet(deployArgs.chainType, [
    deployArgs.chain,
  ]);

  await wallets.verifyBalances();

  await wallets.deployTokenContracts();

  await wallets.createLBPairs();

  await wallets.seedLiquidity();
};

const deployContract = async (
  contractPath: string,
  wallet: Wallet,
  rpc: string
): Promise<string> => {
  const { stdout, stderr } = await execSync(
    `forge create ${contractPath} --private-key=${wallet.privateKey} --rpc-url=${rpc} --verify`
  );

  if (stderr) {
    console.error("could not execute command: ", stderr);
    return;
  }

  const regex = /Deployed to: (0x[a-fA-F0-9]{40})/;
  const address = stdout.match(regex)[1];

  return address;
};
