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
  public contractAddresses: Map<string, string>;

  constructor(chainType: string, chains: string[]) {
    this.chains = chains;
    this.wallets = new Map<string, ethers.Wallet>();
    this.rpcs = new Map<string, string>();
    this.contractAddresses = new Map<string, string>();

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

  public async deployTokenContracts(name: string, symbol: string) {
    const spinner = ora("Deploying the token contract").start();

    for (const chain of this.chains) {
      const wallet = this.wallets.get(chain);
      const rpc = this.rpcs.get(chain);

      const address = await deployContract(
        "src/TransferTaxToken.sol:TransferTaxToken",
        wallet,
        rpc,
        [name, symbol, wallet.address]
      );

      this.contractAddresses.set(chain, address);

      spinner.suffixText += `\n   ${logSymbols.info} Deployed on ${chain} at ${address}`;
    }

    spinner.succeed("Token contracts deployed");
  }

  public async setTaxRate(taxRate: number) {
    const spinner = ora("Setting the tax rate").start();
    const taxRateBigint = ethers.parseUnits(taxRate.toString(), 16);

    for (const chain of this.chains) {
      const wallet = this.wallets.get(chain);
      const tokenAddress = this.contractAddresses.get(chain);

      const tokenContract = new ethers.Contract(
        tokenAddress,
        [
          "function setTaxRate(uint256 taxRate) external",
          "function setTaxRecipient(address newTaxRecipient) external",
        ],
        wallet
      );

      const taxRecipientTx = await tokenContract.setTaxRecipient(
        wallet.address
      );

      await taxRecipientTx.wait();

      const taxRateTx = await tokenContract.setTaxRate(taxRateBigint);

      await taxRateTx.wait();

      spinner.suffixText += `\n   ${logSymbols.info} Done on ${chain}`;
    }

    spinner.succeed("Tax rate set");
  }
}

export const deploy = async (deployArgs: ContractCreationArgs) => {
  const wallets = new MultichainWallet(deployArgs.chainType, [
    deployArgs.chain,
  ]);

  await wallets.verifyBalances();

  await wallets.deployTokenContracts(
    deployArgs.tokenName,
    deployArgs.tokenSymbol
  );

  if (deployArgs.taxRate > 0) {
    await wallets.setTaxRate(deployArgs.taxRate);
  }
};

const deployContract = async (
  contractPath: string,
  wallet: Wallet,
  rpc: string,
  constructorArgs?: string[]
): Promise<string> => {
  const constructorArgsString =
    constructorArgs?.length > 0
      ? `--constructor-args ${constructorArgs.join(" ")}`
      : "";

  const { stdout } = await execSync(
    `forge create ${contractPath} --private-key=${wallet.privateKey} --rpc-url=${rpc} --verify ${constructorArgsString}`
  );

  const regex = /Deployed to: (0x[a-fA-F0-9]{40})/;
  const address = stdout.match(regex)[1];

  return address;
};
