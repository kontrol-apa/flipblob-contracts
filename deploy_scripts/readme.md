

## Prerequisites

Before using this application, make sure you have the following prerequisites installed:

- Node.js: You can download it from [https://nodejs.org/](https://nodejs.org/).

## Configuration
You can provide your configuration either through environment variables or a `config.json` file.

### Using Environment Variables

Set the following environment variables:

- `STARKNET_PRIVATE_KEY`: Your Starknet private key.
- `STARKNET_ACCOUNT_ADDRESS`: Your Starknet account address.

### Using `config.json`

Alternatively, you can create a `config.json` file under this folder with the following format:

```json
{
    "MAINNET": {
        "STARKNET_PRIVATE_KEY": "YOUR_MAINNET_PRIVATE_KEY",
        "STARKNET_ACCOUNT_ADDRESS": "YOUR_MAINNET_ACCOUNT_ADDRESS"
    },
    "TESTNET": {
        "STARKNET_PRIVATE_KEY": "YOUR_TESTNET_PRIVATE_KEY",
        "STARKNET_ACCOUNT_ADDRESS": "YOUR_TESTNET_ACCOUNT_ADDRESS"
    }
}
