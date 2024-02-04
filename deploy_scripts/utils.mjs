import fs from 'fs';
import { RpcProvider, constants } from 'starknet';

export function scarbBuild() {
    executeCommand('scarb clean');
    executeCommand('scarb build');
}

export function getConfig(network) {
    let privateKey = process.env.STARKNET_PRIVATE_KEY;
    let accountAddress = process.env.STARKNET_ACCOUNT_ADDRESS;
    let apiKey = process.env.STARKNET_API_KEY;
    let provider;
    // Check if environment variables are set
    if (!privateKey || !accountAddress || !apiKey) {
        try {
            // Read configuration from file
            const configFile = fs.readFileSync('config.json', 'utf8');
            const config = JSON.parse(configFile);

            // Assign values based on the specified network
            privateKey = config[network].STARKNET_PRIVATE_KEY;
            accountAddress = config[network].STARKNET_ACCOUNT_ADDRESS;
            apiKey = config[network].PROVIDER_API_KEY;
        } catch (error) {
            console.error('Error reading config file:', error);
            process.exit(1);
        }
    }
    provider = new RpcProvider({ nodeUrl:  apiKey });

    return { privateKey, accountAddress, provider};
}
