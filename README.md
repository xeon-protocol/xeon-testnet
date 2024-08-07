# Xeon Protocol Testnet Utils

[![GitHub license](https://img.shields.io/badge/incl_license-GPL_3.0-blue.svg)](https://github.com/xeon-protocol/xeon-testnet/blob/main/LICENSE-GPL.md)

[![xeon token](https://img.shields.io/badge/$XEON-0x8d65a2eaBDE4B31cbD7E43F27E47559d1CCec86c-8429c6.svg?logo=ethereum)](https://app.uniswap.org/explore/tokens/ethereum/0x8d65a2eabde4b31cbd7e43f27e47559d1ccec86c?chain=mainnet)

This repository contains the utility contracts for Xeon Protocol testnet including tests, and scripts. For the frontend, see the [xeon-dapp](https://github.com/xeon-protocol/xeon-dapp) repository.

### Follow Us

[![warpcast](https://img.shields.io/badge/Follow_@xeonprotocol-FFFFFF.svg?logo=farcaster)](https://warpcast.com/xeonprotocol) ![twitter follow](https://img.shields.io/twitter/follow/xeonprotocol) [![telegram](https://img.shields.io/badge/join_telegram-FFFFFF.svg?logo=telegram)](https://t.me/XeonProtocolPortal)

### Repo Status

![GitHub commit activity](https://img.shields.io/github/commit-activity/m/xeon-protocol/xeon-testnet) ![GitHub contributors](https://img.shields.io/github/contributors/xeon-protocol/xeon-testnet)

## Prerequisites

[![git](https://img.shields.io/badge/git-any-darkgreen)](https://git-scm.com/downloads) [![npm](https://img.shields.io/badge/npm->=_6-darkgreen)](https://npmjs.com/) [![Foundry](https://img.shields.io/badge/Foundry-v0.2.0-orange)](https://book.getfoundry.sh/)

## Directory Structure

- `src` - core solidity contracts.
- `test` - tests written in solidity.
- `script` - scripts written in solidity.

## Setup

First, ensure Foundry is installed.

```shell
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

If you don't have a local version of the repository, clone it:

```shell
git clone https://github.com/xeon-protocol/xeon-testnet.git
```

Ensure you have the latest changes locally

```shell
git pull origin main
```

Install the dependency submodules using Forge:

```shell
forge install --no-commit foundry-rs/forge-std openzeppelin/openzeppelin-contracts uniswap/v2-core uniswap v3-core uniswap v3-periphery
```

The `foundry.toml` file is used to configure Foundry settings, manage RPC endpoints, and dependencies.

---

## Foundry

Foundry is a toolkit for writing smart contracts, tests, and scripts in Solidity. It is made up of the following tools:

- `forge` is used to develop, test, and deploy smart contracts.
- `cast` allows you to interact with contracts, send transactions, and get chain data from the CLI.
- `anvil` is a local node.
- `chisel` is an integrated Solidity REPL.

For more information, check out the [Foundry Book](https://book.getfoundry.sh/).

## Forge

Forge is used to build, test, and deploy smart contracts.

### Build

To build and compile all smart contracts, use:

```shell
$ forge build
```

### Test

Tests are handled through test files, written in Solidity and using the naming convention `Contract.t.sol`

```shell
$ forge test
```

### Gas Snapshots

Forge can generate gas snapshots for all test functions to see how much gas contracts will consume, or to compare gas usage before and after optimizations.

```shell
$ forge snapshot
```

### Deploy

Deployments are handled through script files, written in Solidity and using the naming convention `Contract.s.sol`

You can run a script directly from your CLI

```shell
$ forge script script/MyContract.s.sol:MyContractScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

Unless you include the `--broadcast` argument, the script will be run in a simulated environment. If you need to run the script live, use the `--broadcast` arg

⚠️ **CAUTION: Using `--broadcast` will initiate an onchain transaction, only use after thoroughly testing**

```shell
$ forge script script/MyContract.s.sol:MyContractScript --rpc-url <your_rpc_url> --private-key <your_private_key> --chain-id 1 -vv --broadcast
```

Additional arguments can specity the chain and verbosity of the script

```shell
$ forge script script/MyContract.s.sol:MyContractScript --rpc-url <your_rpc_url> --private-key <your_private_key> --chain-id 1 -vv
```

Additionally, you can pass a private key directly into script functions to prevent exposing it in the command line (recommended).

⚠️ **CAUTION: Ensure you are using a `.env.local` and a proper `.gitignore` to prevent leaked keys.**

```js
function run() public {
    vm.startBroadcast(vm.envUint('PRIVATE_KEY'));
    // rest of your code...
}
```

Then run the `forge script` command without the private key arg.

💡 **When deploying a new contract, use the `--verify` arg to verify the contract on deployment.**

## Product Management

[![trello](https://img.shields.io/badge/Trello-855DCD.svg?logo=trello)](<[https://trello.com/b/mW198hKo/xeon-protocol-board](https://trello.com/invite/b/mW198hKo/ATTIc305ea03ad04139d54ef382b7a276d651224A655/xeon-protocol-board)>)

## Contributing

![PRs Open](https://img.shields.io/badge/PRs-open-darkgreen.svg)

If you are an Solidity developer and are interested in auditing our `v1-core` contracts, you can submit an audit by using the form [here](https://github.com/xeon-protocol/xeon-dapp/issues/new?assignees=heyJonBray%2C+wellytg%2C+neonhedge&labels=type%3A+audit%2C+status%3A+discussing&projects=&template=04-audit-submission.md&title=xeon-xeon-v1+audit+%5BMM-DD-YYYY%5D-%5ByourName%5D).

## Security

For any security-related concerns, please refer to the [SECURITY](https://github.com/xeon-protocol/xeon-testnet/blob/main/SECURITY.md) policy. This repository is subject to a bug bounty program per the terms outlined in the aforementioned policy.
