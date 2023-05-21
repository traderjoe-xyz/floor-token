# Floor Token SDK

Floor Tokens are token contracts designed to be launched on Liquidity Book AMM, which can rebalance liquidity into a "Floor Bin".

This repo contains:
- `POTUS` token contract, a floor token with transfer tax. 
- Token contract examples
- CLI to launch tokens on Trader Joe DEX. 


## [WIP] POTUS

`POTUS` is a fixed supply, tax on transfer token inspired by `LOTUS`. 

- X% taxed on transfer, sent to burn
- fixed supply, all tokens minted at genesis
- token liquidity on LB from price X to Y
- X% of ETH liquidity rebalanced to Floor bin


## Floor Bin

[Liquidity Book (LB)](https://support.traderjoexyz.com/en/articles/6893873-liquidity-book-primer) is a highly capital efficient AMM developed by Trader Joe XYZ. 
- Token liquidity is provided into fixed price "bins". 
- Users can swap tokens within bins without slippage.
- The current price is represented by the Active Bin, which contains both X and Y tokens for a given pool. 
- Token price increase when tokens are bought, filling the current bin, and moving the active bin to the next bin. 

`Floor Tokens` have automatic liquidity rebalancing mechanism. As users buy `Floor Token`, the `ETH` tokens stay in the liquidity bins and would be rebalanced by the token contract. 

The `Floor Bin` is the bin that represents the `floor price`, i.e. the lowest price for which all outstanding tokens may be sold at. For example, liquidity could be automatically rebalanced such that 90% of `ETH` liquidity is concentrated into the `Floor Bin`. 

*This concept was introduced by [White Lotus](https://docs.thewhitelotus.xyz/).*


## [WIP] How to use CLI
TODO


## [WIP] How to use SDK
TODO

## How to contribute to this repo

PRs are welcome, please include tests. 

### Install

```
# (optional) for macosx
$ brew install libusb

# install foundry
$ curl -L https://foundry.paradigm.xyz | bash
$ foundryup

# install package
$ git clone git@github.com:traderjoe-xyz/floor-token.git
$ forge install
$ forge build
```

### Testing

```
$ forge test
```

## License

MIT 2023 Trader Joe XYZ
