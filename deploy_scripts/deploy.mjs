
import { Contract, Account, constants, CallData, RpcProvider, shortString, num, json, cairo } from 'starknet';
import { execSync } from 'child_process';
import fs from 'fs';


const tokenETHAddress = '0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7'
const tokenETHIdentifier = "ETH"
const tokenETHMaxBettable = "4500000000000000"
const tokenETHMinBettable = "900000000000000"

const treasuryAddress = "0x31c66f44d8455e5cac18b7016476685af8bd78bf4128cb5375ff2c45bc137c2";
const ownerAddress = "0x31c66f44d8455e5cac18b7016476685af8bd78bf4128cb5375ff2c45bc137c2";
const finalizerAddress = "0x003CF8aa30dA7aDB1D5a28687BF6802d80Bb8A02FBC9A4142020EC8309D7aaD0";
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
//const { address: implementationAddress } = await proxyContract.implementation();
//const implementationAddress = "0x00d0e183745e9dae3e4e78a8ffedcce0903fc4900beace4e0abf192d4c202da3";
//console.log("implementation ERC20 Address =", num.toHex(implementationAddress));
//const classHashERC20Class = await provider.getClassHashAt(num.toHex(implementationAddress)); // read the class hash related to this contract address.
//console.log("classHash of ERC20 =", classHashERC20Class);
//const compiledERC20 = await provider.getClassByHash(classHashERC20Class); // final objective : the answer contains the abi of the ERC20.
const WETH_ABI = [
    {
      "members": [
        {
          "name": "low",
          "offset": 0,
          "type": "felt"
        },
        {
          "name": "high",
          "offset": 1,
          "type": "felt"
        }
      ],
      "name": "Uint256",
      "size": 2,
      "type": "struct"
    },
    {
      "data": [
        {
          "name": "from_",
          "type": "felt"
        },
        {
          "name": "to",
          "type": "felt"
        },
        {
          "name": "value",
          "type": "Uint256"
        }
      ],
      "keys": [],
      "name": "Transfer",
      "type": "event"
    },
    {
      "data": [
        {
          "name": "owner",
          "type": "felt"
        },
        {
          "name": "spender",
          "type": "felt"
        },
        {
          "name": "value",
          "type": "Uint256"
        }
      ],
      "keys": [],
      "name": "Approval",
      "type": "event"
    },
    {
      "inputs": [],
      "name": "name",
      "outputs": [
        {
          "name": "name",
          "type": "felt"
        }
      ],
      "stateMutability": "view",
      "type": "function"
    },
    {
      "inputs": [],
      "name": "symbol",
      "outputs": [
        {
          "name": "symbol",
          "type": "felt"
        }
      ],
      "stateMutability": "view",
      "type": "function"
    },
    {
      "inputs": [],
      "name": "totalSupply",
      "outputs": [
        {
          "name": "totalSupply",
          "type": "Uint256"
        }
      ],
      "stateMutability": "view",
      "type": "function"
    },
    {
      "inputs": [],
      "name": "decimals",
      "outputs": [
        {
          "name": "decimals",
          "type": "felt"
        }
      ],
      "stateMutability": "view",
      "type": "function"
    },
    {
      "inputs": [
        {
          "name": "account",
          "type": "felt"
        }
      ],
      "name": "balanceOf",
      "outputs": [
        {
          "name": "balance",
          "type": "Uint256"
        }
      ],
      "stateMutability": "view",
      "type": "function"
    },
    {
      "inputs": [
        {
          "name": "owner",
          "type": "felt"
        },
        {
          "name": "spender",
          "type": "felt"
        }
      ],
      "name": "allowance",
      "outputs": [
        {
          "name": "remaining",
          "type": "Uint256"
        }
      ],
      "stateMutability": "view",
      "type": "function"
    },
    {
      "inputs": [],
      "name": "permittedMinter",
      "outputs": [
        {
          "name": "minter",
          "type": "felt"
        }
      ],
      "stateMutability": "view",
      "type": "function"
    },
    {
      "inputs": [],
      "name": "initialized",
      "outputs": [
        {
          "name": "res",
          "type": "felt"
        }
      ],
      "stateMutability": "view",
      "type": "function"
    },
    {
      "inputs": [],
      "name": "get_version",
      "outputs": [
        {
          "name": "version",
          "type": "felt"
        }
      ],
      "stateMutability": "view",
      "type": "function"
    },
    {
      "inputs": [],
      "name": "get_identity",
      "outputs": [
        {
          "name": "identity",
          "type": "felt"
        }
      ],
      "stateMutability": "view",
      "type": "function"
    },
    {
      "inputs": [
        {
          "name": "init_vector_len",
          "type": "felt"
        },
        {
          "name": "init_vector",
          "type": "felt*"
        }
      ],
      "name": "initialize",
      "outputs": [],
      "type": "function"
    },
    {
      "inputs": [
        {
          "name": "recipient",
          "type": "felt"
        },
        {
          "name": "amount",
          "type": "Uint256"
        }
      ],
      "name": "transfer",
      "outputs": [
        {
          "name": "success",
          "type": "felt"
        }
      ],
      "type": "function"
    },
    {
      "inputs": [
        {
          "name": "sender",
          "type": "felt"
        },
        {
          "name": "recipient",
          "type": "felt"
        },
        {
          "name": "amount",
          "type": "Uint256"
        }
      ],
      "name": "transferFrom",
      "outputs": [
        {
          "name": "success",
          "type": "felt"
        }
      ],
      "type": "function"
    },
    {
      "inputs": [
        {
          "name": "spender",
          "type": "felt"
        },
        {
          "name": "amount",
          "type": "Uint256"
        }
      ],
      "name": "approve",
      "outputs": [
        {
          "name": "success",
          "type": "felt"
        }
      ],
      "type": "function"
    },
    {
      "inputs": [
        {
          "name": "spender",
          "type": "felt"
        },
        {
          "name": "added_value",
          "type": "Uint256"
        }
      ],
      "name": "increaseAllowance",
      "outputs": [
        {
          "name": "success",
          "type": "felt"
        }
      ],
      "type": "function"
    },
    {
      "inputs": [
        {
          "name": "spender",
          "type": "felt"
        },
        {
          "name": "subtracted_value",
          "type": "Uint256"
        }
      ],
      "name": "decreaseAllowance",
      "outputs": [
        {
          "name": "success",
          "type": "felt"
        }
      ],
      "type": "function"
    },
    {
      "inputs": [
        {
          "name": "recipient",
          "type": "felt"
        },
        {
          "name": "amount",
          "type": "Uint256"
        }
      ],
      "name": "permissionedMint",
      "outputs": [],
      "type": "function"
    },
    {
      "inputs": [
        {
          "name": "account",
          "type": "felt"
        },
        {
          "name": "amount",
          "type": "Uint256"
        }
      ],
      "name": "permissionedBurn",
      "outputs": [],
      "type": "function"
    }
  ]
const ethContract = new Contract(WETH_ABI, ETHproxyAddress, provider);
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

function scarbBuild() {
    try {
        const stdout = execSync('scarb build');
        console.log(`stdout: ${stdout}`);
    } catch (error) {
        console.error(`Execution error: ${error}`);
        console.error(`stderr: ${error.stderr}`);
    }
}