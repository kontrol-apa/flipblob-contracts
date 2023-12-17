
import { Contract, Account, constants, RpcProvider, num } from 'starknet';
import { shortString } from 'starknet';
import fs from 'fs';
import { cairo } from "starknet";

const tokenWETHAddress = '0x034e31357d1c3693bda06d04bf4c51557514ECed5A8e9973bDb772f7fB978B36'
const tokenWETHIdentifier = "WETH";

const tokenGoerliETHAddress = '0x049D36570D4e46f48e99674bd3fcc84644DdD6b96F7C741B1562B82f9e004dC7';
const tokenGoerliETHIdentifier = 'ETH';
const tokenETHMaxBettable = "5100000000000000"
const tokenETHMinBettable = "900000000000000"

const flipTestAddress = "0x2c375d88eb08bdc9d859ade56773b112f08dc5fef7a3505f97018ef30a61257";
const finalizer = '0x551e361b1f456856968d00e2ea991daecc04eed605903030ffbc547616da258'
const treasuryAddress = "0x31c66f44d8455e5cac18b7016476685af8bd78bf4128cb5375ff2c45bc137c2";


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



const ETHproxyAddress = tokenGoerliETHAddress; // address of ETH proxy
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

wethTestContract.connect(account);
flipTestContract.connect(account);
ethContract.connect(account);

// Interaction with the contract with call
var reqId = await flipTestContract.get_next_request_id();
console.log("Next Request ID =", reqId.toString()); 
// With Cairo 1 contract, the result value is in bal1, as bigint.



// const resApprove = await wethTestContract.approve(flipTestAddress, cairo.uint256(970000000000000000000));
// await provider.waitForTransaction(resApprove.transaction_hash);
// const allowance = await wethTestContract.allowance(accountAddress, flipTestAddress);
// console.log("Allowance =", allowance.toString()); 

// const EthResApprove = await ethContract.approve(flipTestAddress, cairo.uint256(97000000000000000000000000));
// await provider.waitForTransaction(EthResApprove.transaction_hash);
// const ethAllowance = await ethContract.allowance(accountAddress, flipTestAddress);
// console.log("Allowance =", ethAllowance); 


// const tokenSupportTx = await flipTestContract.set_token_support(shortString.encodeShortString(tokenGoerliETHIdentifier), tokenGoerliETHAddress, tokenETHMaxBettable, tokenETHMinBettable);
// const tokenSupportReceipt = await provider.waitForTransaction(tokenSupportTx.transaction_hash);
// console.log('Status:', tokenSupportReceipt.execution_status);


const isSupported = await flipTestContract.is_token_supported(shortString.encodeShortString(tokenGoerliETHIdentifier));
console.log(`Is ${tokenGoerliETHIdentifier} supported? = ${isSupported}`);

const tokenSupportTx = await flipTestContract.set_token_support(shortString.encodeShortString(tokenGoerliETHIdentifier), tokenGoerliETHAddress, tokenETHMaxBettable, tokenETHMinBettable);
const tokenSupportReceipt = await provider.waitForTransaction(tokenSupportTx.transaction_hash);
console.log('Status:', tokenSupportReceipt.execution_status);

// let res = await flipTestContract.issue_request(cairo.uint256(1), cairo.uint256(940000000000000), "0", shortString.encodeShortString(tokenGoerliETHIdentifier));
// let issueReqRes = await provider.waitForTransaction(res.transaction_hash);
// console.log('Status Issue Request with ETH:', issueReqRes.execution_status);

// reqId = await flipTestContract.get_next_request_id();
// console.log("Next Request ID =", reqId.toString()); 

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
            // provider = new RpcProvider({ nodeUrl: config[network].INFURA_KEY });
            provider = new RpcProvider({ sequencer: { network: constants.NetworkName.SN_GOERLI } });
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

