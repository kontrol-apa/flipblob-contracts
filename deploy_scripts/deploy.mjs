
import { Contract, Account, constants, CallData, RpcProvider, shortString, num, json, cairo } from 'starknet';
import { execSync } from 'child_process';
import fs from 'fs';


const tokenETHAddress = '0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7'
const tokenETHIdentifier = "ETH"
const tokenETHMaxBettable = "4500000000000000"
const tokenETHMinBettable = "900000000000000"

const treasuryAddress = "0x31c66f44d8455e5cac18b7016476685af8bd78bf4128cb5375ff2c45bc137c2";
const ownerAddress = "0x31c66f44d8455e5cac18b7016476685af8bd78bf4128cb5375ff2c45bc137c2";
const finalizerAddress = "0x551e361b1f456856968d00e2ea991daecc04eed605903030ffbc547616da258";
const flipFeePercentage = 5;

const absolutePath = "../target/dev/"



scarbBuild();

const { privateKey, accountAddress, provider } = getConfig("TESTNET");

const account = new Account(
    provider,
    accountAddress,
    privateKey
);

const compiledTestSierra = json.parse(fs.readFileSync( absolutePath + "flipblob_Flip.contract_class.json").toString( "ascii"));
const compiledTestCasm = json.parse(fs.readFileSync( absolutePath + "flipblob_Flip.compiled_contract_class.json").toString( "ascii"));

const contractCallData = new CallData(compiledTestSierra.abi);
const contractConstructor = contractCallData.compile("constructor", {
        treasuryAddress: treasuryAddress,
        owner_address: ownerAddress, 
        flipFee: flipFeePercentage,
        finalizer: finalizerAddress
    });


const deployResponse = await account.declareAndDeploy({ contract: compiledTestSierra, casm: compiledTestCasm, constructorCalldata: contractConstructor });
const flipTestContract = new Contract(compiledTestSierra.abi, deployResponse.deploy.contract_address, provider);
console.log("FlipBlob Contract Class Hash =", deployResponse.declare.class_hash);
console.log('✅ FlibBlob Contract connected at =', flipTestContract.address);
flipTestContract.connect(account);



const ETHproxyAddress = tokenETHAddress; // address of ETH proxy
const compiledProxy = await provider.getClassAt(ETHproxyAddress); // abi of proxy
const proxyContract = new Contract(compiledProxy.abi, ETHproxyAddress, provider);
const { address: implementationAddress } = await proxyContract.implementation();
// specific to this proxy : Implementation() returns an address of implementation.
// Other proxies returns generaly a class hash of implementation
console.log("implementation ERC20 Address =", num.toHex(implementationAddress));
const classHashERC20Class = await provider.getClassHashAt(num.toHex(implementationAddress)); // read the class hash related to this contract address.
console.log("classHash of ERC20 =", classHashERC20Class);
const compiledERC20 = await provider.getClassByHash(classHashERC20Class); // final objective : the answer contains the abi of the ERC20.

const ethContract = new Contract(compiledERC20.abi, ETHproxyAddress, provider);
ethContract.connect(account);


const tokenSupportTx = await flipTestContract.set_token_support(shortString.encodeShortString(tokenETHIdentifier), tokenETHAddress, tokenETHMaxBettable, tokenETHMinBettable);
const tokenSupportReceipt = await provider.waitForTransaction(tokenSupportTx.transaction_hash);
console.log('Status:', tokenSupportReceipt.execution_status);


const EthResApprove = await ethContract.approve(flipTestContract.address, cairo.uint256("97000000000000000000000000"));
await provider.waitForTransaction(EthResApprove.transaction_hash);
const ethAllowance = await ethContract.allowance(accountAddress, flipTestContract.address);
console.log("Allowance =", ethAllowance); 


const isSupported = await flipTestContract.is_token_supported(shortString.encodeShortString(tokenETHIdentifier));
console.log(`Is ${tokenETHIdentifier} supported? = ${isSupported}`);

const res = await flipTestContract.issue_request(cairo.uint256(1), cairo.uint256(910000000000000), "0", shortString.encodeShortString(tokenETHIdentifier));
const issueReqRes = await provider.waitForTransaction(res.transaction_hash);
console.log('Status Issue Request with ETH:', issueReqRes.execution_status);

const reqId = await flipTestContract.get_next_request_id();
console.log("Next Request ID =", reqId.toString()); 


console.log(`Token support set for ${tokenETHAddress} with the name ${tokenETHIdentifier}. The max bettable in Wei is : ${tokenETHMaxBettable}`);
console.log("Make sure that: ");
console.log(`1. Treasury is funded -> ${treasuryAddress} `);
console.log(`2. Treasury has approved the FlipBlob contract for spenditure for ${tokenETHIdentifier} -> ${tokenETHAddress}`);
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

function executeCommand(command) {
    try {
        const stdout = execSync(command);
        console.log(`${command} ${stdout}`);
    } catch (error) {
        console.error(`Execution error: ${error}`);
        console.error(`stderr: ${error.stderr}`);
    }
}

function scarbBuild() {
    executeCommand('scarb clean');
    executeCommand('scarb build');
}