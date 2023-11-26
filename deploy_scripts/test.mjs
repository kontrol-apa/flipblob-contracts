
import { Contract, Account, constants, RpcProvider } from 'starknet';
import { shortString } from 'starknet';
import fs from 'fs';
import { cairo } from "starknet";

const tokenWETHAddress = '0x034e31357d1c3693bda06d04bf4c51557514ECed5A8e9973bDb772f7fB978B36'
const flipTestAddress = "0x02b1512db3cc59de4e13f7f9900ac399303c707c9969be4f8458b1b5bde63ee9";
const tokenWETHIdentifier = "WETH";
const finalizer = '0x551e361b1f456856968d00e2ea991daecc04eed605903030ffbc547616da258'


const { privateKey, accountAddress, provider } = getConfig("TESTNET");

const account = new Account(
    provider,
    accountAddress,
    privateKey
);

// read abi of Test contract
const { abi: testAbi } = await provider.getClassAt(flipTestAddress);
if (testAbi === undefined) { throw new Error("no abi.") };
const flipTestContract = new Contract(testAbi, flipTestAddress, provider);

const { abi: testWethAbi } = await provider.getClassAt(tokenWETHAddress);
if (testAbi === undefined) { throw new Error("no abi.") };
const wethTestContract = new Contract(testWethAbi, tokenWETHAddress, provider);

wethTestContract.connect(account);
flipTestContract.connect(account);

// Interaction with the contract with call
var reqId = await flipTestContract.get_next_request_id();
console.log("Initial balance =", reqId.toString()); 
// With Cairo 1 contract, the result value is in bal1, as bigint.


const resApprove = await wethTestContract.approve(flipTestAddress, cairo.uint256(77000000000000000000));
// await provider.waitForTransaction(resApprove.transaction_hash);

const allowance = await wethTestContract.allowance(accountAddress, flipTestAddress);
console.log("Allowance =", allowance.toString()); 

const setFinalizerTx = await flipTestContract.set_finalizer(finalizer);
await provider.waitForTransaction(setFinalizerTx.transaction_hash);

const res = await flipTestContract.issue_request(cairo.uint256(5), cairo.uint256(77000000000000000), 0, shortString.encodeShortString(tokenWETHIdentifier));
const issueReqRes = await provider.waitForTransaction(res.transaction_hash);
console.log('Status:', issueReqRes.execution_status);

reqId = await flipTestContract.get_next_request_id();
console.log("Initial balance =", reqId.toString()); 

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
            provider = new RpcProvider({ nodeUrl: config[network].INFURA_KEY });
        } catch (error) {
            console.error('Error reading config file:', error);
            process.exit(1);
        }
    }
    else {
        if (network === "TESTNET") {
            nodeUrl = constants.NetworkName.SN_GOERLI; // for testnet
        } else {
            nodeUrl = constants.NetworkName.SN_MAIN; // for mainnet
        }
        provider = new RpcProvider({ sequencer: { network: nodeUrl } });
    }
    return { privateKey, accountAddress, provider};
}

