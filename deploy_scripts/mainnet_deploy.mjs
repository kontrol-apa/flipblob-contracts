
import { Contract, Account, constants, CallData, RpcProvider, shortString, num, json, cairo, uint256 } from 'starknet';
import fs from 'fs';
import { scarbBuild, getConfig } from './utils'; 


const tokenETHAddress = '0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7'
const tokenETHIdentifier = "ETH"
const tokenETHMaxBettable = "45000000000000000"
const tokenETHMinBettable = "900000000000000"

const treasuryAddress = "0x0296c11Fed1F140c73df4EAE033020403E3cA3720c110Be44Ba953144d8A9643";
const ownerAddress = "0x61a738199dbe8a2885a9bac6b52b9f575386e1205b15c8862fb4e7bba31d3ab";
const finalizerAddress = "0x1f881e85ffc1fb42e2e344c8d55815863976a5b58d9ea483c2b738a51daebd";
const flipFeePercentage = 5;

const absolutePath = "../target/dev/"



scarbBuild();

const { privateKey, accountAddress, provider } = getConfig("MAINNET");

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

const treasuryBalance = await ethContract.balanceOf(ownerAddress);
console.log("Balance =", uint256.uint256ToBN(treasuryBalance.balance).toString()); 

const tokenSupportTx = await flipTestContract.set_token_support(shortString.encodeShortString(tokenETHIdentifier), tokenETHAddress, tokenETHMaxBettable, tokenETHMinBettable);
const tokenSupportReceipt = await provider.waitForTransaction(tokenSupportTx.transaction_hash);
console.log('Status:', tokenSupportReceipt.execution_status);


// const EthResApprove = await ethContract.approve(flipTestContract.address, cairo.uint256("97000000000000000000000000"));
// await provider.waitForTransaction(EthResApprove.transaction_hash);
// const ethAllowance = await ethContract.allowance(accountAddress, flipTestContract.address);
// console.log("Allowance =", ethAllowance); 


// const isSupported = await flipTestContract.is_token_supported(shortString.encodeShortString(tokenETHIdentifier));
// console.log(`Is ${tokenETHIdentifier} supported? = ${isSupported}`);

// const res = await flipTestContract.issue_request(cairo.uint256(1), cairo.uint256(910000000000000), "0", shortString.encodeShortString(tokenETHIdentifier));
// const issueReqRes = await provider.waitForTransaction(res.transaction_hash);
// console.log('Status Issue Request with ETH:', issueReqRes.execution_status);

// const reqId = await flipTestContract.get_next_request_id();
// console.log("Next Request ID =", reqId.toString()); 


console.log(`Token support set for ${tokenETHAddress} with the name ${tokenETHIdentifier}. The max bettable in Wei is : ${tokenETHMaxBettable}`);
console.log("Make sure that: ");
console.log(`1. Treasury is funded -> ${treasuryAddress} `);
console.log(`2. Treasury has approved the FlipBlob contract for spenditure for ${tokenETHIdentifier} -> ${tokenETHAddress}`);
console.log(`3. Finalizer is funded -> ${finalizerAddress}`);
console.log("4. Finalizer is set in the backend.")



