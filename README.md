# Floor Token SDK

Floor Tokens are token contracts designed to be launched on Liquidity Book AMM, which can rebalance liquidity into a "Floor Bin".

This repo contains:

- Contracts that implement tax on transfers. The tax can then be sent to one, two or three recipients.
- A floor token contract that implements the risk-free value (RFV) price bin that backs all the tokens.

## Documentation

[Docs](https://floor.traderjoexyz.com).

## Install as NPM package

```
$ yarn add @traderjoe-xyz/floor-token
```

## Install

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

## Testing

```
$ forge test
```

## How to contribute to this repo

PRs are welcome, please include tests.

## License

MIT
