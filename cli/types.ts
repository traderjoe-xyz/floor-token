export interface ContractCreationArgs {
  chainType: string;
  chain: string;
  tokenName: string;
  tokenSymbol: string;
  taxRate?: number;
  floorPrice?: number;
  pairBinStep?: number;
}
