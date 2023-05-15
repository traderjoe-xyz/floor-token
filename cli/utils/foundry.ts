import { Wallet } from "ethers";
import util from "node:util";
import { exec } from "node:child_process";

const execSync = util.promisify(exec);

export const deployContract = async (
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
