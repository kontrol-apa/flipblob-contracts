
import { Contract, Account, constants, CallData, RpcProvider } from 'starknet';
import { json } from 'starknet';
import { execSync } from 'child_process';
import * as fs from 'fs';

const provider = new RpcProvider({ sequencer: { network: constants.NetworkName.SN_GOERLI } }) // for testnet
//const provider = new RpcProvider({ sequencer: { network: constants.NetworkName.SN_MAIN } }) // for testnet

// devnet private key from Account #0 if generated with --seed 0
const privateKey = process.env.STARKNET_PRIVATE_KEY
const accountAddress = process.env.STARKNET_ACCOUNT_ADDRESS;

const tokenWETHAddress = '0x034e31357d1c3693bda06d04bf4c51557514ECed5A8e9973bDb772f7fB978B36'
const tokenWETHIdentifier = "WETH"
const tokenWETHMaxBettable = "15000000000000000"

const treasuryAddress = "0x003CF8aa30dA7aDB1D5a28687BF6802d80Bb8A02FBC9A4142020EC8309D7aaD0";
const ownerAddress = "0x003CF8aa30dA7aDB1D5a28687BF6802d80Bb8A02FBC9A4142020EC8309D7aaD0";
const finalizerAddress = "0x003CF8aa30dA7aDB1D5a28687BF6802d80Bb8A02FBC9A4142020EC8309D7aaD0";
const flipFeePercentage = 5;

const absolutePath = "../target/dev/"



try {
    const stdout = execSync('scarb build');
    console.log(`stdout: ${stdout}`);
} catch (error) {
    console.error(`Execution error: ${error}`);
    console.error(`stderr: ${error.stderr}`);
}



const account = new Account(
    provider,
    accountAddress,
    privateKey
);

// Declare & deploy Test contract in devnet
const compiledTestSierra = json.parse(fs.readFileSync( absolutePath + "flipblob_Flip.sierra.json").toString( "ascii"));
const compiledTestCasm = json.parse(fs.readFileSync( absolutePath + "./flipblob_Flip.casm.json").toString( "ascii"));

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

const tokenSupportTx = await myTestContract.set_token_support(tokenWETHIdentifier,tokenWETHAddress,tokenWETHMaxBettable);
await provider.waitForTransaction(tokenSupportTx.transaction_hash);
console.log(`Token support set for ${tokenWETHAddress} with the name ${tokenWETHIdentifier}. The max bettable in Wei is : ${tokenWETHMaxBettable}`);
console.log("Make sure that: ");
console.log(`1. Treasury is funded -> ${treasuryAddress} `);
console.log(`2. Treasury has approved the FlipBlob contract for spenditure for ${tokenWETHIdentifier} -> ${tokenWETHAddress}`);
console.log(`3. Finalizer is funded -> ${finalizerAddress}`);
console.log("4. Finalizer is set in the backend.")
