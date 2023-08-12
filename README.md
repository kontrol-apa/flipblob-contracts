# flipblob-contracts

### CAVEATS
* I couldnt get to import anything thats not on the lib.cairo file to the tests so mock erc20 implementation is also there. the flip.cairo file is just a place holder, ignore it. 


### USEFUL COMMANDS
```
# test 
snforge

# build
scarb build

# declare and deploy
sncast --account ffbbcc --network testnet --url https://starknet-goerli.infura.io/v3/5bfa78a2165d4d169dc9c519ab5a42a6 declare --contract-name Flip --max-fee 969082993868615
sncast --account ffbbcc --network testnet --url https://starknet-goerli.infura.io/v3/5bfa78a2165d4d169dc9c519ab5a42a6 deploy --class-hash 0x23b5c3797f2f03ec96d9897392a962fe66892e8c8c44f99f46242e4ddb515c9 --max-fee 969082993868615
```
### ADDRESSES

MOCK ERC : https://goerli.voyager.online/contract/0x034e31357d1c3693bda06d04bf4c51557514ECed5A8e9973bDb772f7fB978B36#writeContract

FLIP : https://goerli.voyager.online/contract/0x04efeabc07d1ea8223a5a39c8cbbe0965b5fecb4542aed363a0dc235894f98bb#events

### TODO:

1. Struct packing
2. Full Ownable interface (transfer etc)
3. Customizable treasury address
4. Limits on wagers
5. Hard limits on payouts against an exploit
6. Array interface for onchain random number hashes
7. Counters for simple indexing replacement for the backend. 