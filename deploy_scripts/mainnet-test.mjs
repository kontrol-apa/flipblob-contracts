
import { Contract, Account, num } from 'starknet';
import { shortString } from 'starknet';
import { getConfig } from './utils.mjs';

const tokenWETHAddress = '0x034e31357d1c3693bda06d04bf4c51557514ECed5A8e9973bDb772f7fB978B36'
const tokenWETHIdentifier = "WETH";

const tokenETHAddress = '0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7';
const tokenETHIdentifier = 'ETH';
const tokenETHMaxBettable = "5100000000000000"
const tokenETHMinBettable = "900000000000000"

const flipTestAddress = "0x0625be855455bb38982fb1102114df02f4707be61b0f9b0a04b9b3eca386c54d";



const { privateKey, accountAddress, provider } = getConfig("MAINNET");

const account = new Account(
    provider,
    accountAddress,
    privateKey
);

// read abi of Test contract
const { abi: testAbi } = await provider.getClassAt(flipTestAddress);
if (testAbi === undefined) { throw new Error("no abi.") };
const flipTestContract = new Contract(testAbi, flipTestAddress, provider);

// const { abi: testWethAbi } = await provider.getClassAt(tokenWETHAddress);
// if (testAbi === undefined) { throw new Error("no abi.") };
// const wethTestContract = new Contract(testWethAbi, tokenWETHAddress, provider);



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

// wethTestContract.connect(account);
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


// const tokenSupportTx = await flipTestContract.set_token_support(shortString.encodeShortString(tokenETHIdentifier), tokenETHAddress, tokenETHMaxBettable, tokenETHMinBettable);
// const tokenSupportReceipt = await provider.waitForTransaction(tokenSupportTx.transaction_hash);
// console.log('Status:', tokenSupportReceipt.execution_status);


const isSupported = await flipTestContract.is_token_supported(shortString.encodeShortString(tokenETHIdentifier));
console.log(`Is ${tokenETHIdentifier} supported? = ${isSupported}`);

// let res = await flipTestContract.issue_request(cairo.uint256(1), cairo.uint256(940000000000000), "0", shortString.encodeShortString(tokenETHIdentifier));
// let issueReqRes = await provider.waitForTransaction(res.transaction_hash);
// console.log('Status Issue Request with ETH:', issueReqRes.execution_status);

// reqId = await flipTestContract.get_next_request_id();
// console.log("Next Request ID =", reqId.toString()); 

