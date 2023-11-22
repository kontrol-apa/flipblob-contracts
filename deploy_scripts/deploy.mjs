
import { Contract, Account, constants, CallData, RpcProvider, shortString } from 'starknet';
import { json } from 'starknet';
import { execSync } from 'child_process';
import fs from 'fs';


const tokenWETHAddress = '0x034e31357d1c3693bda06d04bf4c51557514ECed5A8e9973bDb772f7fB978B36'
const tokenWETHIdentifier = "WETH"
const tokenWETHMaxBettable = "150000000000000000"
const tokenWETHMinBettable = "9900000000000000"

const treasuryAddress = "0x31c66f44d8455e5cac18b7016476685af8bd78bf4128cb5375ff2c45bc137c2";
const ownerAddress = "0x31c66f44d8455e5cac18b7016476685af8bd78bf4128cb5375ff2c45bc137c2";
const finalizerAddress = "0x003CF8aa30dA7aDB1D5a28687BF6802d80Bb8A02FBC9A4142020EC8309D7aaD0";
const argentWalletAddress = "0x016C5242381A0FF101B239bf872462a0e63B70d9c94ca493EAa606ed0eA1baE1";
const flipFeePercentage = 5;

const absolutePath = "../target/dev/"



scarbBuild();

const { privateKey, accountAddress, provider } = getConfig("TESTNET");

const account = new Account(
    provider,
    accountAddress,
    privateKey
);

const compiledTestSierra = json.parse(fs.readFileSync( absolutePath + "flipblob_Flip.sierra.json").toString( "ascii"));
const compiledTestCasm = json.parse(fs.readFileSync( absolutePath + "flipblob_Flip.casm.json").toString( "ascii"));

const contractCallData = new CallData(compiledTestSierra.abi);
const contractConstructor = contractCallData.compile("constructor", {
        treasuryAddress: treasuryAddress,
        owner_address: ownerAddress, 
        flipFee: flipFeePercentage,
        finalizer: finalizerAddress
    });


const deployResponse = await account.declareAndDeploy({ contract: compiledTestSierra, casm: compiledTestCasm, constructorCalldata: contractConstructor });
// Connect the new contract instance:
const myTestContract = new Contract(compiledTestSierra.abi, deployResponse.deploy.contract_address, provider);
console.log("FlipBlob Contract Class Hash =", deployResponse.declare.class_hash);
console.log('✅ FlibBlob Contract connected at =', myTestContract.address);
myTestContract.connect(account);

const tokenSupportTx = await myTestContract.set_token_support(shortString.encodeShortString(tokenWETHIdentifier), tokenWETHAddress, tokenWETHMaxBettable, tokenWETHMinBettable);
const tokenSupportReceipt = await provider.waitForTransaction(tokenSupportTx.transaction_hash);
console.log('Status:', tokenSupportReceipt.execution_status);

// const transferOwnershipTx = await myTestContract.transfer_ownership(argentWalletAddress);
// const transferOwnershipReceipt = await provider.waitForTransaction(transferOwnershipTx.transaction_hash);
// console.log('Status:', transferOwnershipReceipt.execution_status);

console.log(`Token support set for ${tokenWETHAddress} with the name ${tokenWETHIdentifier}. The max bettable in Wei is : ${tokenWETHMaxBettable}`);
console.log("Make sure that: ");
console.log(`1. Treasury is funded -> ${treasuryAddress} `);
console.log(`2. Treasury has approved the FlipBlob contract for spenditure for ${tokenWETHIdentifier} -> ${tokenWETHAddress}`);
console.log(`3. Finalizer is funded -> ${finalizerAddress}`);
console.log("4. Finalizer is set in the backend.")



function getConfig(network) {
    let privateKey = process.env.STARKNET_PRIVATE_KEY;
    let accountAddress = process.env.STARKNET_ACCOUNT_ADDRESS;
    let provider;
    // Check if environment variables are set
    if (!privateKey || !accountAddress) {
        try {
            // Read configuration from file
            const configFile = fs.readFileSync('config.json', 'utf8');
            const config = JSON.parse(configFile);

            // Assign values based on the specified network
            privateKey = config[network].STARKNET_PRIVATE_KEY;
            accountAddress = config[network].STARKNET_ACCOUNT_ADDRESS;
        } catch (error) {
            console.error('Error reading config file:', error);
            process.exit(1);
        }
    }
    if (network == "TESTNET") {
         provider = new RpcProvider({ sequencer: { network: constants.NetworkName.SN_GOERLI } }) // for testnet
    }
    else {
         provider = new RpcProvider({ sequencer: { network: constants.NetworkName.SN_MAIN } }) // for testnet
    }
    return { privateKey, accountAddress, provider};
}

function scarbBuild() {
    try {
        const stdout = execSync('scarb build');
        console.log(`stdout: ${stdout}`);
    } catch (error) {
        console.error(`Execution error: ${error}`);
        console.error(`stderr: ${error.stderr}`);
    }
}